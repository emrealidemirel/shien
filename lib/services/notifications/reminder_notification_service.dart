import 'package:shien/l10n/app_localization.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:shien/services/reminder_actions.dart';
import 'package:shien/services/notifications/reminder_schedule.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:shien/models/reminder.dart';

abstract class ReminderNotifications {
  bool get supported;
  Future<bool> requestPermission();
  Future<bool> isEnabled();
  Future<void> sync(List<Reminder> reminders);
}

int reminderNotificationId(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

// Reserve room under iOS's pending-notification limit, counting each weekly
// day separately and an extra request for a snoozed recurring reminder.
int reminderNotificationSlots(List<Reminder> reminders) =>
    reminderMinimumSlots(reminders, DateTime.now());

class ReminderNotificationService implements ReminderNotifications {
  ReminderNotificationService({this.inspectLaunch = true});
  final bool inspectLaunch;
  String accountScope = 'guest';
  final _plugin = FlutterLocalNotificationsPlugin();
  void Function(String id)? onTapped;
  String? launchId;
  Future<void> Function()? onAction;
  bool hasLaunchAction = false;
  bool _initialized = false;
  String? _language;
  Future<void> _syncs = Future<void>.value();

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (!supported || (_initialized && _language == appLocale)) return;
    final wasInitialized = _initialized;
    await refreshTimeZone();
    await _plugin.initialize(
      InitializationSettings(
        android: const AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              'reminder_actions',
              actions: [
                DarwinNotificationAction.plain('done', t('completed')),
                DarwinNotificationAction.plain('snooze10', t('in_ten_minutes')),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (response) async {
        final data = decodeReminderPayload(response.payload);
        if (data == null ||
            reminderPayloadScope(response.payload) != accountScope) {
          return;
        }
        if (response.actionId == 'done' || response.actionId == 'snooze10') {
          await performBackgroundReminderAction(response);
          await onAction?.call();
        } else {
          onTapped?.call(data.$1.id);
        }
      },
      onDidReceiveBackgroundNotificationResponse:
          reminderNotificationActionBackground,
    );
    _initialized = true;
    _language = appLocale;
    if (!inspectLaunch || wasInitialized) return;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) &&
        response != null &&
        response.payload != null &&
        reminderPayloadScope(response.payload) == accountScope) {
      if (response.actionId == 'done' || response.actionId == 'snooze10') {
        await performBackgroundReminderAction(response);
        hasLaunchAction = true;
      } else {
        launchId = decodeReminderPayload(response.payload)?.$1.id;
      }
    }
  }

  Future<void> refreshTimeZone() async {
    if (!supported) return;
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
  }

  @override
  Future<bool> requestPermission() async {
    if (!supported) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  @override
  Future<bool> isEnabled() async {
    if (!supported) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ??
          false;
    }
    final permissions = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.checkPermissions();
    return permissions?.isEnabled ?? false;
  }

  Future<bool> requestExactTiming() async {
    if (!supported || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestExactAlarmsPermission() ??
        false;
  }

  Future<bool> hasExactTiming() async {
    if (!supported) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        false;
  }

  @override
  Future<void> sync(List<Reminder> reminders) {
    final next = _syncs.then((_) => _sync(reminders));
    _syncs = next.catchError((Object _) {});
    return next;
  }

  Future<void> _sync(
    List<Reminder> reminders, {
    bool reconcile = true,
    int limit = 60,
  }) async {
    if (!supported) return;
    await initialize();
    await refreshTimeZone();
    final plans = buildReminderPlans(reminders, DateTime.now(), limit: limit);
    final exact = await hasExactTiming();
    final desired = <int>{};
    for (final plan in plans) {
      final reminder = plan.reminder;
      final id = reminderNotificationId('${reminder.id}/${plan.key}');
      if (!desired.add(id)) throw StateError(t('error_notification_id'));
      final sound = reminder.sound;
      await _plugin.zonedSchedule(
        id,
        reminder.title,
        plan.early
            ? t(
                'notification_early',
                args: {'count': (reminder.leadMinutes).toString()},
              )
            : reminder.note.isEmpty
            ? t('notification_body')
            : reminder.note,
        tz.TZDateTime.from(plan.at, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'reminders_${sound.name}_v1',
            t(
              'notification_channel_sound',
              args: {'value': (sound.label).toString()},
            ),
            channelDescription: t('notification_channel'),
            importance: Importance.high,
            priority: Priority.high,
            sound: sound.resource == null
                ? null
                : RawResourceAndroidNotificationSound(sound.resource!),
            playSound: sound != ReminderSound.silent,
            enableVibration: sound != ReminderSound.silent,
            category: AndroidNotificationCategory.reminder,
            actions: plan.early
                ? null
                : [
                    AndroidNotificationAction(
                      'done',
                      t('completed'),
                      cancelNotification: true,
                    ),
                    AndroidNotificationAction(
                      'snooze10',
                      t('in_ten_minutes'),
                      cancelNotification: true,
                    ),
                  ],
          ),
          iOS: DarwinNotificationDetails(
            sound: sound.resource == null ? null : '${sound.resource}.wav',
            presentAlert: true,
            presentBadge: false,
            presentSound: sound != ReminderSound.silent,
            categoryIdentifier: plan.early ? null : 'reminder_actions',
          ),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: plan.match,
        payload: jsonEncode({
          'language': appLocale,
          'scope': accountScope,
          'reminder': reminder.toMap(),
          'at': plan.at.toIso8601String(),
        }),
      );
    }
    // Reconcile only after replacements are scheduled. Also retires legacy alarms.
    if (!reconcile) return;
    for (final pending in await _plugin.pendingNotificationRequests()) {
      if (!desired.contains(pending.id)) await _plugin.cancel(pending.id);
    }
  }
}

String reminderPayloadScope(String? payload) {
  if (payload == null) return 'guest';
  try {
    return (jsonDecode(payload) as Map)['scope'] as String? ?? 'guest';
  } catch (_) {
    return 'guest';
  }
}

(Reminder, DateTime)? decodeReminderPayload(String? payload) {
  if (payload == null) return null;
  try {
    final map = jsonDecode(payload) as Map;
    return (
      Reminder.fromMap(map['reminder'] as Map),
      DateTime.parse(map['at'] as String),
    );
  } catch (_) {
    return null;
  }
}

@pragma('vm:entry-point')
void reminderNotificationActionBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await performBackgroundReminderAction(response);
}

Future<void> performBackgroundReminderAction(
  NotificationResponse response,
) async {
  final data = decodeReminderPayload(response.payload);
  if (data == null ||
      (response.actionId != 'done' && response.actionId != 'snooze10')) {
    return;
  }
  useBackgroundLocale(
    (jsonDecode(response.payload!) as Map)['language'] as String?,
  );
  final now = DateTime.now();
  final expectedAt = hasPersistentSchedule(data.$1)
      ? (data.$1.effectiveAt.isAfter(now) ? data.$1.effectiveAt : now)
      : data.$2;
  final scope = reminderPayloadScope(response.payload);
  if (scope != await ReminderActionQueue.activeScope()) return;
  final action = ReminderAction.create(
    data.$1,
    response.actionId!,
    expectedAt,
    scope: scope,
  );
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );
  final requests = await plugin.pendingNotificationRequests();
  final matching = requests
      .where(
        (p) =>
            decodeReminderPayload(p.payload)?.$1.id == data.$1.id &&
            reminderPayloadScope(p.payload) == scope,
      )
      .toList();
  // Reject actions on old notifications after the schedule was edited.
  final changed = matching.any((p) {
    final r = decodeReminderPayload(p.payload)?.$1;
    return r != null &&
        reminderActionSignature(r) != reminderActionSignature(data.$1);
  });
  if (changed) return;
  await ReminderActionQueue.add(action);
  for (final pending in matching) {
    await plugin.cancel(pending.id);
  }
  final updated = applyReminderAction(data.$1, action)?.$1;
  if (updated != null && updated.isActive) {
    final service = ReminderNotificationService(inspectLaunch: false)
      ..accountScope = scope;
    // Never reconcile unrelated reminders from the background isolate.
    final minimum = reminderNotificationSlots([updated]);
    await service._sync(
      [updated],
      reconcile: false,
      limit: matching.length > minimum ? matching.length : minimum,
    );
  }
}

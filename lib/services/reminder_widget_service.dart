import 'package:medicine_app/l10n/app_localization.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:medicine_app/models/reminder.dart';
import 'package:medicine_app/services/notifications/reminder_notification_service.dart';

class ReminderWidgetService {
  String accountScope = 'guest';
  static const group = 'group.com.example.medicineApp.reminders';
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Future<void> initialize() async {
    if (!supported) return;
    await HomeWidget.setAppGroupId(group);
    await HomeWidget.registerInteractivityCallback(reminderWidgetBackground);
  }

  Future<void> sync(List<Reminder> reminders) async {
    if (!supported) return;
    await HomeWidget.setAppGroupId(group);
    final active = reminders.where((r) => r.isActive).toList()
      ..sort((a, b) => a.effectiveAt.compareTo(b.effectiveAt));
    await HomeWidget.saveWidgetData('widget_locale', appLocale);
    await HomeWidget.saveWidgetData('account_scope', accountScope);
    await HomeWidget.saveWidgetData(
      'widget_copy',
      jsonEncode({
        for (final key in [
          'widget_title',
          'widget_empty',
          'new_reminder',
          'complete',
          'widget_description',
          'app_name',
        ])
          key: t(key),
      }),
    );
    await HomeWidget.saveWidgetData(
      'reminders',
      jsonEncode(active.map((r) => r.toMap()).toList()),
    );
    await HomeWidget.updateWidget(
      androidName: 'ReminderWidgetProvider',
      iOSName: 'ReminderWidget',
    );
  }
}

@pragma('vm:entry-point')
Future<void> reminderWidgetBackground(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  if (uri == null || uri.host != 'done') return;
  final service = ReminderWidgetService();
  await HomeWidget.setAppGroupId(ReminderWidgetService.group);
  useBackgroundLocale(await HomeWidget.getWidgetData<String>('widget_locale'));
  service.accountScope =
      await HomeWidget.getWidgetData<String>('account_scope') ?? 'guest';
  if ((uri.queryParameters['scope'] ?? 'guest') != service.accountScope) return;
  final raw = await HomeWidget.getWidgetData<String>('reminders');
  if (raw == null) return;
  final reminders = (jsonDecode(raw) as List)
      .map((m) => Reminder.fromMap(m as Map))
      .toList();
  final id = uri.queryParameters['id'];
  final r = reminders.where((r) => r.id == id).firstOrNull;
  if (r == null) return;
  await performBackgroundReminderAction(
    NotificationResponse(
      notificationResponseType:
          NotificationResponseType.selectedNotificationAction,
      actionId: 'done',
      payload: jsonEncode({
        'language': appLocale,
        'scope': service.accountScope,
        'reminder': r.toMap(),
        'at': r.effectiveAt.toIso8601String(),
      }),
    ),
  );
  final next = r.nextAfterCompletion(DateTime.now());
  await service.sync(
    reminders
        .map(
          (item) => item.id == id
              ? item.copyWith(
                  dueAt: next,
                  isCompleted: next == null,
                  clearSnooze: true,
                )
              : item,
        )
        .toList(),
  );
}

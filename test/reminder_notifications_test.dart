import 'dart:convert';
import 'package:medicine_app/l10n/app_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_app/models/reminder.dart';
import 'package:medicine_app/services/notifications/reminder_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const timezone = MethodChannel('flutter_timezone');
  late List<MethodCall> calls;
  var exact = false;
  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    exact = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezone, (call) async => 'Europe/Istanbul');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'canScheduleExactNotifications':
              return exact;
            case 'getNotificationAppLaunchDetails':
              return <String, dynamic>{'notificationLaunchedApp': false};
            case 'pendingNotificationRequests':
              return [
                <String, dynamic>{
                  'id': 42,
                  'title': 'Old',
                  'body': '',
                  'payload': 'old',
                },
              ];
            default:
              return true;
          }
        });
  });
  tearDown(() {
    useBackgroundLocale('tr');
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezone, null);
  });

  Reminder sample({
    ReminderRepeat repeat = ReminderRepeat.once,
    ReminderSound sound = ReminderSound.chime,
  }) {
    final at = DateTime.now().add(const Duration(hours: 2));
    return Reminder(
      id: 'sample',
      title: 'Hatırlatma',
      anchorAt: at,
      dueAt: at,
      createdAt: DateTime.now(),
      repeat: repeat,
      sound: sound,
      weekdays: [1, 3, 5],
    );
  }

  test(
    'permission-denied exact timing falls back and uses selected sound',
    () async {
      final service = ReminderNotificationService();
      await service.initialize();
      await service.sync([sample()]);
      final scheduled =
          calls.singleWhere((c) => c.method == 'zonedSchedule').arguments
              as Map;
      expect(
        (scheduled['platformSpecifics'] as Map)['scheduleMode'],
        'inexactAllowWhileIdle',
      );
      final details = scheduled['platformSpecifics'] as Map;
      expect(details['channelId'], 'reminders_chime_v1');
      expect(details['sound'], 'reminder_chime');
      expect((scheduled['payload'] as String), contains('"id":"sample"'));
      expect(
        decodeReminderPayload(scheduled['payload'] as String)?.$1.id,
        'sample',
      );
      expect(calls.last.method, 'cancel');
    },
  );
  test(
    'locale changes update notification copy without translating user content',
    () async {
      final service = ReminderNotificationService();
      final reminder = sample();
      useBackgroundLocale('en');
      await service.sync([reminder]);
      final english =
          calls.lastWhere((c) => c.method == 'zonedSchedule').arguments as Map;
      expect(english['title'], reminder.title);
      expect(english['body'], 'Time for your reminder.');
      expect(
        (english['platformSpecifics'] as Map)['channelName'],
        'Shien · Chime',
      );
      expect(
        (jsonDecode(english['payload'] as String) as Map)['language'],
        'en',
      );
      useBackgroundLocale('tr');
      await service.sync([reminder]);
      final turkish =
          calls.lastWhere((c) => c.method == 'zonedSchedule').arguments as Map;
      expect(turkish['body'], 'Hatırlatma zamanı.');
      expect(turkish['title'], reminder.title);
      expect(turkish['id'], english['id']);
    },
  );

  test('exact timing is used when allowed', () async {
    exact = true;
    await ReminderNotificationService().sync([
      sample(sound: ReminderSound.silent),
    ]);
    final scheduled =
        calls.singleWhere((c) => c.method == 'zonedSchedule').arguments as Map;
    expect(
      (scheduled['platformSpecifics'] as Map)['scheduleMode'],
      'exactAllowWhileIdle',
    );
    expect((scheduled['platformSpecifics'] as Map)['playSound'], false);
  });
  test('each selected weekday gets its own persistent notification', () async {
    await ReminderNotificationService().sync([
      sample(repeat: ReminderRepeat.weekly),
    ]);
    final schedules = calls.where((c) => c.method == 'zonedSchedule').toList();
    expect(schedules, hasLength(3));
    expect(
      schedules.map((c) => (c.arguments as Map)['id']).toSet(),
      hasLength(3),
    );
    expect(
      schedules.every(
        (c) => (c.arguments as Map)['matchDateTimeComponents'] == 1,
      ),
      isTrue,
    );
  });
  test('exceeding capacity never cancels existing reminders', () async {
    final reminders = List.generate(61, (i) {
      final r = sample();
      return Reminder(
        id: 'r$i',
        title: r.title,
        anchorAt: r.anchorAt,
        dueAt: r.dueAt,
        createdAt: r.createdAt,
      );
    });
    await expectLater(
      ReminderNotificationService().sync(reminders),
      throwsStateError,
    );
    expect(calls.where((c) => c.method == 'cancel'), isEmpty);
    expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
  });
}

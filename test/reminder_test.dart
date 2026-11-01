import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medicine_app/blocs/reminder/reminder_cubit.dart';
import 'package:medicine_app/models/medicine.dart';
import 'package:medicine_app/models/medicine_log.dart';
import 'package:medicine_app/models/reminder.dart';
import 'package:medicine_app/services/notifications/reminder_notification_service.dart';
import 'package:medicine_app/services/reminder_actions.dart';
import 'package:medicine_app/services/reminder_quick_input.dart';
import 'package:medicine_app/services/reminder_storage.dart';

class FakeNotifications implements ReminderNotifications {
  bool fail = false;
  List<Reminder> scheduled = [];
  @override
  bool get supported => true;
  @override
  Future<bool> isEnabled() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> sync(List<Reminder> reminders) async {
    if (fail) throw StateError('Unavailable');
    scheduled = reminders.where((r) => r.isActive).toList();
  }
}

Reminder reminder({
  ReminderRepeat repeat = ReminderRepeat.once,
  DateTime? anchor,
  List<int> days = const [],
  String id = 'r1',
}) => Reminder(
  id: id,
  title: 'Dizi saati',
  note: 'Yeni bölüm',
  anchorAt: anchor ?? DateTime(2026, 10, 26, 20),
  dueAt: anchor ?? DateTime(2026, 10, 26, 20),
  createdAt: DateTime(2026, 10, 26),
  repeat: repeat,
  weekdays: days,
);

void main() {
  group('calendar recurrence', () {
    test('annual leap-day reminder finds four-year and century gaps', () {
      final r = reminder(
        repeat: ReminderRepeat.yearly,
        anchor: DateTime(2024, 2, 29, 9),
      );
      expect(
        r.nextOccurrence(DateTime(2024, 2, 29, 9)),
        DateTime(2028, 2, 29, 9),
      );
      expect(
        r.nextOccurrence(DateTime(2096, 2, 29, 9)),
        DateTime(2104, 2, 29, 9),
      );
    });

    test('daily completion keeps original time after snoozing', () {
      final r = reminder(
        repeat: ReminderRepeat.daily,
      ).copyWith(snoozedUntil: DateTime(2026, 10, 26, 22));
      expect(
        r.nextOccurrence(DateTime(2026, 10, 26, 22)),
        DateTime(2026, 10, 27, 20),
      );
    });
    test('weekly skips unselected days including across year boundary', () {
      final r = reminder(
        repeat: ReminderRepeat.weekly,
        anchor: DateTime(2026, 12, 30, 10),
        days: [1, 5],
      );
      expect(
        r.nextOccurrence(DateTime(2026, 12, 30, 11)),
        DateTime(2027, 1, 1, 10),
      );
    });
    test('monthly 31st skips February and April', () {
      final r = reminder(
        repeat: ReminderRepeat.monthly,
        anchor: DateTime(2026, 1, 31, 9),
      );
      expect(
        r.nextOccurrence(DateTime(2026, 1, 31, 9)),
        DateTime(2026, 3, 31, 9),
      );
      expect(
        r.nextOccurrence(DateTime(2026, 3, 31, 9)),
        DateTime(2026, 5, 31, 9),
      );
    });
    test('leap day and non-leap year remain calendar-valid', () {
      final r = reminder(
        repeat: ReminderRepeat.monthly,
        anchor: DateTime(2024, 1, 29, 8),
      );
      expect(r.nextOccurrence(DateTime(2024, 2, 1)), DateTime(2024, 2, 29, 8));
      expect(r.nextOccurrence(DateTime(2025, 2, 1)), DateTime(2025, 3, 29, 8));
    });
    test('12-year leap-day recurrence finds its next occurrence', () {
      final anchor = DateTime(2024, 2, 29, 9);
      final r = Reminder(
        id: 'leap-interval',
        title: 'Takip et',
        anchorAt: anchor,
        dueAt: anchor,
        createdAt: anchor,
        repeat: ReminderRepeat.yearly,
        interval: 12,
      );
      expect(r.nextOccurrence(anchor), DateTime(2036, 2, 29, 9));
    });
    test('never schedules before the anchor date', () {
      final r = reminder(
        repeat: ReminderRepeat.weekly,
        anchor: DateTime(2027, 8, 2, 10),
        days: [1],
      );
      expect(
        r.nextOccurrence(DateTime(2026, 10, 26)),
        DateTime(2027, 8, 2, 10),
      );
    });
    test('one-time reminder has no next occurrence', () {
      expect(reminder().nextOccurrence(DateTime(2026, 10, 26)), isNull);
    });
    test('storage round trip retains schedule and snooze', () {
      final r = reminder(repeat: ReminderRepeat.weekly, days: [1, 4]).copyWith(
        snoozedUntil: DateTime(2026, 10, 27, 8),
        isPaused: true,
        isPriority: true,
        tags: ['iş', 'önemli'],
      );
      final restored = Reminder.fromMap(r.toMap());
      expect(restored.toMap(), r.toMap());
    });
    test('older reminder records default to no tags or priority', () {
      final map = reminder().toMap()
        ..remove('isPriority')
        ..remove('tags');
      final restored = Reminder.fromMap(map);
      expect(restored.isPriority, isFalse);
      expect(restored.tags, isEmpty);
    });
    test('notification identifiers are deterministic and positive', () {
      expect(
        reminderNotificationId('abc/repeat'),
        reminderNotificationId('abc/repeat'),
      );
      expect(
        reminderNotificationId('abc/repeat'),
        isNot(reminderNotificationId('abc/snooze')),
      );
      expect(
        reminderNotificationId('abc/repeat'),
        inInclusiveRange(0, 0x7fffffff),
      );
    });
  });

  group('quick reminder input', () {
    final now = DateTime(2026, 10, 26, 16);

    test('recognizes a Turkish tomorrow time without changing the title', () {
      final result = ReminderQuickInput.parse('Yarın 20.00 yeni bölüm', now);
      expect(result?.title, 'yeni bölüm');
      expect(result?.at, DateTime(2026, 10, 27, 20));
    });

    test('recognizes Turkish today after normalizing dotless i', () {
      final result = ReminderQuickInput.parse('Bugün 18:30 yürüyüş', now);
      expect(result?.title, 'yürüyüş');
      expect(result?.at, DateTime(2026, 10, 26, 18, 30));
    });

    test('recognizes a relative minute interval', () {
      final result = ReminderQuickInput.parse('Ödev teslim 35 dk sonra', now);
      expect(result?.title, 'Ödev teslim');
      expect(result?.at, DateTime(2026, 10, 26, 16, 35));
    });
  });

  test('background complete action uses the completion time for repeats', () {
    final anchor = DateTime(2026, 10, 26, 20);
    final reminder = Reminder(
      id: 'after-completion',
      title: 'Biraz su iç',
      anchorAt: anchor,
      dueAt: DateTime(2026, 10, 27, 20),
      createdAt: anchor,
      repeat: ReminderRepeat.afterCompletion,
    );
    final result = applyReminderAction(
      reminder,
      ReminderAction(
        id: 'action-1',
        reminderId: reminder.id,
        kind: 'done',
        expectedAt: reminder.dueAt,
        at: DateTime(2026, 10, 26, 9),
      ),
    );
    expect(result?.$1.dueAt, DateTime(2026, 10, 27, 20));
  });

  late Directory directory;
  late Box<dynamic> box;
  late ReminderStorage storage;
  late FakeNotifications notifications;
  late ReminderCubit cubit;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('reminder_test_');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('reminders');
    storage = ReminderStorage(box);
    notifications = FakeNotifications();
    cubit = ReminderCubit(storage: storage, notifications: notifications);
  });
  tearDown(() async {
    await cubit.close();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'complete once persists history and removes future notification',
    () async {
      await cubit.save(reminder());
      await cubit.complete('r1', at: DateTime(2026, 10, 26, 20, 1));
      expect(cubit.state.reminders.single.isCompleted, isTrue);
      expect(storage.completions.single.title, 'Dizi saati');
      expect(notifications.scheduled, isEmpty);
      await cubit.complete('r1');
      expect(storage.completions, hasLength(1));
    },
  );
  test('recurring completion after snooze restores original time', () async {
    await cubit.save(reminder(repeat: ReminderRepeat.daily));
    await cubit.snooze('r1', const Duration(minutes: 30));
    await cubit.complete('r1', at: DateTime(2026, 10, 26, 22));
    final next = storage.reminders.single;
    expect(next.isCompleted, isFalse);
    expect(next.snoozedUntil, isNull);
    expect(next.dueAt, DateTime(2026, 10, 27, 20));
  });
  test('after-completion repeat counts from an early completion', () async {
    await cubit.save(reminder(repeat: ReminderRepeat.afterCompletion));
    await cubit.complete('r1', at: DateTime(2026, 10, 26, 9));
    expect(cubit.state.reminders.single.dueAt, DateTime(2026, 10, 27, 20));
  });
  test('notification failure keeps saved data and reports an error', () async {
    notifications.fail = true;
    await cubit.save(reminder());
    expect(storage.reminders.single.title, 'Dizi saati');
    expect(cubit.state.error, isNotNull);
    notifications.fail = false;
    await cubit.refresh();
    expect(cubit.state.error, isNull);
  });
  test('deleting a reminder keeps completion history', () async {
    await cubit.save(reminder());
    await cubit.complete('r1');
    await cubit.delete('r1');
    expect(storage.reminders, isEmpty);
    expect(storage.completions, hasLength(1));
  });
  test('settings persist after restarting the cubit', () async {
    await cubit.setTheme(ThemeMode.dark);
    await cubit.setDefaultSound(ReminderSound.chime);
    final restarted = ReminderCubit(
      storage: storage,
      notifications: notifications,
    );
    expect(restarted.state.themeMode, ThemeMode.dark);
    expect(restarted.state.defaultSound, ReminderSound.chime);
    await restarted.close();
  });
  test(
    'legacy import preserves originals, month days, multiple times and history',
    () async {
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(MedicineAdapter());
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(RepeatCycleAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(MedicineLogAdapter());
      }
      final medicines = await Hive.openBox<Medicine>('medicines');
      final logs = await Hive.openBox<MedicineLog>('logs');
      await medicines.put(
        'm1',
        Medicine(
          id: 'm1',
          name: 'Eski kayıt',
          intakeDays: [15, 31],
          intakeTimes: ['08:00', '20:00'],
          repeatCycle: RepeatCycle.monthly,
          createdAt: DateTime(2025),
          isUnlimited: true,
        ),
      );
      await logs.put(
        'l1',
        MedicineLog(
          id: 'l1',
          medicineId: 'm1',
          isTaken: true,
          scheduledTime: DateTime(2026, 1, 15, 8),
          createdAt: DateTime(2026, 1, 15, 8, 5),
        ),
      );
      await storage.migrateLegacy(medicines, logs, now: DateTime(2026, 2, 1));
      expect(storage.reminders, hasLength(4));
      expect(storage.reminders.map((r) => r.anchorAt.day).toSet(), {15, 31});
      expect(
        storage.reminders
            .where((r) => r.anchorAt.day == 31)
            .every((r) => r.dueAt.month == 3),
        isTrue,
      );
      expect(storage.completions.single.title, 'Eski kayıt');
      expect(medicines.length, 1);
      expect(logs.length, 1);
      await storage.migrateLegacy(medicines, logs);
      expect(storage.reminders, hasLength(4));
      expect(storage.completions, hasLength(1));
    },
  );

  test('resuming a future recurring target never moves it earlier', () async {
    final now = DateTime.now();
    final r = reminder(
      repeat: ReminderRepeat.daily,
      anchor: now.subtract(const Duration(days: 5)),
    ).copyWith(dueAt: now.add(const Duration(days: 4)), isPaused: true);
    await cubit.save(r);
    await cubit.togglePause(r.id);
    expect(storage.reminders.single.dueAt, r.dueAt);
    expect(storage.reminders.single.isActive, isTrue);
  });

  test(
    'invalid snooze and backup data leave persisted records intact',
    () async {
      await cubit.save(reminder());
      await expectLater(cubit.snooze('r1', Duration.zero), throwsArgumentError);
      await expectLater(
        cubit.snooze('r1', const Duration(minutes: -10)),
        throwsArgumentError,
      );
      final invalid = reminder(id: 'invalid').copyWith(tags: ['']);
      await expectLater(cubit.mergeBackup([invalid], []), throwsArgumentError);
      expect(storage.reminders.single.id, 'r1');
      expect(storage.reminders.single.snoozedUntil, isNull);
    },
  );

  test(
    'stale editor cannot overwrite a completed or deleted reminder',
    () async {
      final original = reminder();
      await cubit.save(original);
      await cubit.complete(original.id);
      await expectLater(
        cubit.save(original, expected: original),
        throwsStateError,
      );
      expect(storage.reminders.single.isCompleted, isTrue);
      await cubit.delete(original.id);
      await expectLater(
        cubit.save(original, expected: original),
        throwsStateError,
      );
      expect(storage.reminders, isEmpty);
    },
  );

  test(
    'confirmation for an old occurrence cannot complete the next repeat',
    () async {
      final original = reminder(repeat: ReminderRepeat.daily);
      await cubit.save(original);
      await cubit.complete(original.id, at: original.dueAt, expected: original);
      await expectLater(
        cubit.complete(original.id, expected: original),
        throwsStateError,
      );
      expect(storage.completions, hasLength(1));
      expect(
        storage.reminders.single.dueAt,
        original.nextOccurrence(original.dueAt),
      );
    },
  );

  test('concurrent edits are serialized without losing reminders', () async {
    await Future.wait([
      cubit.save(reminder(id: 'first')),
      cubit.save(reminder(id: 'second')),
    ]);
    expect(storage.reminders.map((r) => r.id).toSet(), {'first', 'second'});
  });
  test(
    'notification capacity rejection preserves previously saved data',
    () async {
      final future = DateTime.now().add(const Duration(days: 1));
      for (var index = 0; index < 60; index++) {
        await cubit.save(reminder(id: 'r$index', anchor: future));
      }
      await expectLater(
        cubit.save(reminder(id: 'too-many', anchor: future)),
        throwsStateError,
      );
      expect(storage.reminders, hasLength(60));
      expect(storage.reminders.any((r) => r.id == 'too-many'), isFalse);
    },
  );
}

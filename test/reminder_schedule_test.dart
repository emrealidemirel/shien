import 'package:flutter_test/flutter_test.dart';
import 'package:shien/models/reminder.dart';
import 'package:shien/services/notifications/reminder_schedule.dart';

void main() {
  final now = DateTime(2026, 10, 27, 8);
  for (final repeat in [
    ReminderRepeat.daily,
    ReminderRepeat.weekly,
    ReminderRepeat.monthly,
    ReminderRepeat.yearly,
  ]) {
    test(
      'early completion does not recreate the finished $repeat occurrence',
      () {
        final original = Reminder(
          id: 'early',
          title: 'Reminder',
          createdAt: now,
          anchorAt: DateTime(2026, 10, 27, 9),
          dueAt: DateTime(2026, 10, 27, 9),
          repeat: repeat,
          weekdays: [2],
          leadMinutes: 15,
        );
        final next = original.nextAfterCompletion(now)!;
        final completed = original.copyWith(dueAt: next);
        final plans = buildReminderPlans([completed], now);
        expect(plans.where((p) => !p.early).first.at, next);
        expect(
          plans.every(
            (p) => !p.at.isBefore(next.subtract(const Duration(minutes: 15))),
          ),
          isTrue,
        );
      },
    );
  }

  test('custom interval respects the next unfinished occurrence', () {
    final original = Reminder(
      id: 'interval',
      title: 'Reminder',
      createdAt: now,
      anchorAt: DateTime(2026, 10, 27, 9),
      dueAt: DateTime(2026, 10, 27, 9),
      repeat: ReminderRepeat.daily,
      interval: 3,
    );
    final next = original.nextAfterCompletion(now)!;
    final plans = buildReminderPlans([original.copyWith(dueAt: next)], now);
    expect(plans.first.at, DateTime(2026, 10, 30, 9));
    expect(plans.every((p) => !p.at.isBefore(next)), isTrue);
  });

  test('multiple daily times keep the next time after an early completion', () {
    final original = Reminder(
      id: 'times',
      title: 'Reminder',
      createdAt: now,
      anchorAt: DateTime(2026, 10, 27, 9),
      dueAt: DateTime(2026, 10, 27, 9),
      repeat: ReminderRepeat.daily,
      additionalTimes: [18 * 60],
    );
    final plans = buildReminderPlans([
      original.copyWith(dueAt: original.nextAfterCompletion(now)),
    ], now);
    final dates = plans.map((p) => p.at).toList()..sort();
    expect(dates, [DateTime(2026, 10, 27, 18), DateTime(2026, 10, 28, 9)]);
  });
}

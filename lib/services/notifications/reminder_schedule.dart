import 'package:shien/l10n/app_localization.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shien/models/reminder.dart';

class ReminderNotificationPlan {
  const ReminderNotificationPlan(
    this.reminder,
    this.key,
    this.at, {
    this.match,
    this.early = false,
  });
  final Reminder reminder;
  final String key;
  final DateTime at;
  final DateTimeComponents? match;
  final bool early;
}

bool hasPersistentSchedule(Reminder r) =>
    r.interval == 1 &&
    !r.lastDayOfMonth &&
    r.repeat != ReminderRepeat.afterCompletion &&
    r.repeat != ReminderRepeat.once &&
    !(r.leadMinutes > 0 &&
        (r.repeat == ReminderRepeat.monthly ||
            r.repeat == ReminderRepeat.yearly));

List<ReminderNotificationPlan> _firstPlans(Reminder r, DateTime now) {
  final plans = <ReminderNotificationPlan>[];
  if (r.snoozedUntil?.isAfter(now) ?? false) {
    plans.add(ReminderNotificationPlan(r, 'snooze', r.snoozedUntil!));
  }
  if (r.repeat == ReminderRepeat.once ||
      r.repeat == ReminderRepeat.afterCompletion) {
    if (r.snoozedUntil == null && r.dueAt.isAfter(now)) {
      plans.add(ReminderNotificationPlan(r, 'once', r.dueAt));
      final early = r.dueAt.subtract(Duration(minutes: r.leadMinutes));
      if (r.leadMinutes > 0 && early.isAfter(now)) {
        plans.add(ReminderNotificationPlan(r, 'early', early, early: true));
      }
    }
    return plans;
  }
  // dueAt is the first unfinished occurrence. Completing a future occurrence
  // must not recreate its notification when we rebuild the original cadence.
  var after = r.dueAt.isAfter(now)
      ? r.dueAt.subtract(const Duration(microseconds: 1))
      : now;
  if (r.snoozedUntil?.isAfter(after) ?? false) after = r.snoozedUntil!;
  if (!hasPersistentSchedule(r)) {
    final next = r.nextOccurrence(after);
    if (next != null) _addRolling(plans, r, next, now);
    return plans;
  }
  for (final time in r.times) {
    final anchor = r.anchorAt;
    final timed = Reminder(
      id: r.id,
      title: r.title,
      anchorAt: DateTime(
        anchor.year,
        anchor.month,
        anchor.day,
        time ~/ 60,
        time % 60,
      ),
      dueAt: r.dueAt,
      createdAt: r.createdAt,
      repeat: r.repeat,
      weekdays: r.weekdays,
    );
    if (r.repeat == ReminderRepeat.weekly) {
      for (final day in r.weekdays.toSet()) {
        final weekly = Reminder(
          id: r.id,
          title: r.title,
          anchorAt: timed.anchorAt,
          dueAt: r.dueAt,
          createdAt: r.createdAt,
          repeat: r.repeat,
          weekdays: [day],
        );
        final next = weekly.nextOccurrence(after);
        if (next != null) {
          _addPersistent(
            plans,
            r,
            'day-$day-$time',
            next,
            DateTimeComponents.dayOfWeekAndTime,
            now,
          );
        }
      }
    } else {
      final next = timed.nextOccurrence(after);
      if (next != null) {
        _addPersistent(plans, r, 'repeat-$time', next, switch (r.repeat) {
          ReminderRepeat.daily => DateTimeComponents.time,
          ReminderRepeat.yearly => DateTimeComponents.dateAndTime,
          _ => DateTimeComponents.dayOfMonthAndTime,
        }, now);
      }
    }
  }
  return plans;
}

void _addPersistent(
  List<ReminderNotificationPlan> plans,
  Reminder r,
  String key,
  DateTime at,
  DateTimeComponents match,
  DateTime now,
) {
  plans.add(ReminderNotificationPlan(r, key, at, match: match));
  if (r.leadMinutes > 0) {
    var early = at.subtract(Duration(minutes: r.leadMinutes));
    // A daily early warning equal to or longer than a day would overlap the
    // next occurrence; the form prevents this configuration via validation.
    if (!early.isAfter(now)) {
      final next = r.nextOccurrence(now.add(Duration(minutes: r.leadMinutes)));
      if (next == null) return;
      early = next.subtract(Duration(minutes: r.leadMinutes));
      // When multiple times/days exist the next warning must belong to this
      // schedule; advance this specific fixed daily/weekly schedule instead.
      if (match == DateTimeComponents.time) {
        early = at.subtract(Duration(minutes: r.leadMinutes));
        while (!early.isAfter(now)) {
          early = DateTime(
            early.year,
            early.month,
            early.day + 1,
            early.hour,
            early.minute,
          );
        }
      } else if (match == DateTimeComponents.dayOfWeekAndTime) {
        early = at.subtract(Duration(minutes: r.leadMinutes));
        while (!early.isAfter(now)) {
          early = DateTime(
            early.year,
            early.month,
            early.day + 7,
            early.hour,
            early.minute,
          );
        }
      }
    }
    plans.add(
      ReminderNotificationPlan(
        r,
        '$key-early',
        early,
        match: match,
        early: true,
      ),
    );
  }
}

void _addRolling(
  List<ReminderNotificationPlan> plans,
  Reminder r,
  DateTime at,
  DateTime now,
) {
  plans.add(ReminderNotificationPlan(r, 'at-${at.toIso8601String()}', at));
  final early = at.subtract(Duration(minutes: r.leadMinutes));
  if (r.leadMinutes > 0 && early.isAfter(now)) {
    plans.add(
      ReminderNotificationPlan(
        r,
        'early-${at.toIso8601String()}',
        early,
        early: true,
      ),
    );
  }
}

int reminderMinimumSlots(List<Reminder> reminders, DateTime now) => reminders
    .where((r) => r.isActive)
    .fold(0, (n, r) => n + _firstPlans(r, now).length);

/// Calendar repeats supported by the OS persist indefinitely. Custom intervals
/// get a fair share of the remaining 60 pending slots. The UI exposes their
/// coverage date; reopening the app refreshes that horizon.
List<ReminderNotificationPlan> buildReminderPlans(
  List<Reminder> reminders,
  DateTime now, {
  int limit = 60,
}) {
  final active = reminders.where((r) => r.isActive).toList();
  final plans = [for (final r in active) ..._firstPlans(r, now)];
  if (plans.length > limit) {
    throw StateError(t('error_schedule_capacity'));
  }
  final rolling = active
      .where(
        (r) =>
            !hasPersistentSchedule(r) &&
            r.repeat != ReminderRepeat.once &&
            r.repeat != ReminderRepeat.afterCompletion,
      )
      .toList();
  final last = <String, DateTime>{};
  for (final r in rolling) {
    final dates = plans
        .where((p) => p.reminder.id == r.id && !p.early && p.key != 'snooze')
        .map((p) => p.at)
        .toList();
    if (dates.isNotEmpty) last[r.id] = dates.last;
  }
  for (var round = 0; round < limit && plans.length < limit; round++) {
    var added = false;
    for (final r in rolling) {
      final prior = last[r.id];
      if (prior == null) continue;
      final next = r.nextOccurrence(prior);
      if (next == null) continue;
      final batch = <ReminderNotificationPlan>[];
      _addRolling(batch, r, next, now);
      if (plans.length + batch.length > limit) continue;
      plans.addAll(batch);
      last[r.id] = next;
      added = true;
    }
    if (!added) break;
  }
  return plans;
}

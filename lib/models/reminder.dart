import 'package:medicine_app/l10n/app_localization.dart';

enum ReminderRepeat {
  once('repeat_once'),
  daily('repeat_daily'),
  weekly('repeat_weekly'),
  monthly('repeat_monthly'),
  yearly('repeat_yearly'),
  afterCompletion('repeat_after_completion');

  const ReminderRepeat(this._labelKey);
  final String _labelKey;
  String get label => t(_labelKey);
}

enum ReminderCategory {
  personal('category_personal'),
  work('category_work'),
  health('category_health'),
  entertainment('category_leisure'),
  payments('category_payments');

  const ReminderCategory(this._labelKey);
  final String _labelKey;
  String get label => t(_labelKey);
}

enum ReminderSound {
  soft('sound_soft', 'sound_soft_description', 'reminder_soft'),
  chime('sound_chime', 'sound_chime_description', 'reminder_chime'),
  bright('sound_bright', 'sound_bright_description', 'reminder_bright'),
  silent('sound_silent', 'sound_silent_description', null);

  const ReminderSound(this._labelKey, this._descriptionKey, this.resource);
  final String _labelKey;
  String get label => t(_labelKey);
  final String _descriptionKey;
  String get description => t(_descriptionKey);
  final String? resource;
}

/// A calendar schedule is kept separately from snoozing so the original time
/// and monthly day are never shifted by an individual occurrence.
class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    required this.anchorAt,
    required this.dueAt,
    required this.createdAt,
    this.note = '',
    this.category = ReminderCategory.personal,
    this.repeat = ReminderRepeat.once,
    this.weekdays = const [],
    this.sound = ReminderSound.soft,
    this.isPaused = false,
    this.isCompleted = false,
    this.snoozedUntil,
    this.interval = 1,
    this.lastDayOfMonth = false,
    this.additionalTimes = const [],
    this.leadMinutes = 0,
    this.isPriority = false,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String note;
  final DateTime anchorAt;
  final DateTime dueAt;
  final DateTime createdAt;
  final ReminderCategory category;
  final ReminderRepeat repeat;
  final List<int> weekdays;
  final ReminderSound sound;
  final bool isPaused;
  final bool isCompleted;
  final DateTime? snoozedUntil;

  final int interval;
  final bool lastDayOfMonth;

  /// Minutes after midnight, in addition to anchorAt's time.
  final List<int> additionalTimes;
  final int leadMinutes;
  final bool isPriority;
  final List<String> tags;

  /// Shared by direct saves and imports so both paths accept the same data.
  String? get validationError {
    if (id.trim().isEmpty || id.length > 200) {
      return t('error_invalid_id');
    }
    if (title.trim().isEmpty || title.length > 100) {
      return t('error_title_length');
    }
    if (note.length > 500) return t('error_note_length');
    if (repeat == ReminderRepeat.weekly && weekdays.isEmpty) {
      return t('error_choose_day');
    }
    if (weekdays.any((day) => day < 1 || day > 7) ||
        interval < 1 ||
        interval > 12 ||
        additionalTimes.length > 3 ||
        additionalTimes.any((time) => time < 0 || time >= 1440) ||
        leadMinutes < 0 ||
        leadMinutes > 1440 ||
        tags.length > 5 ||
        tags.any((tag) => tag.trim().isEmpty || tag.length > 24)) {
      return t('error_invalid_options');
    }
    if (repeat == ReminderRepeat.daily &&
        interval == 1 &&
        leadMinutes >= 1440) {
      return t('error_daily_lead');
    }
    return null;
  }

  List<int> get times =>
      ({anchorAt.hour * 60 + anchorAt.minute, ...additionalTimes}.toList()
        ..sort());
  String get scheduleLabel {
    final timeCount = times.length > 1
        ? t('times_per_day', args: {'count': (times.length).toString()})
        : '';
    final label = switch (repeat) {
      ReminderRepeat.once => t('repeat_once'),
      ReminderRepeat.daily =>
        interval == 1
            ? t('repeat_daily')
            : t('every_n_days', args: {'count': (interval).toString()}),
      ReminderRepeat.weekly =>
        interval == 1
            ? t('repeat_selected_days')
            : t('every_n_weeks', args: {'count': (interval).toString()}),
      ReminderRepeat.monthly =>
        lastDayOfMonth
            ? t(
                'monthly_last_day',
                args: {
                  'value':
                      (interval == 1
                              ? t('repeat_monthly')
                              : t(
                                  'every_n_months',
                                  args: {'count': (interval).toString()},
                                ))
                          .toString(),
                },
              )
            : interval == 1
            ? t('repeat_monthly')
            : t('every_n_months', args: {'count': (interval).toString()}),
      ReminderRepeat.yearly =>
        interval == 1
            ? t('repeat_yearly')
            : t('every_n_years', args: {'count': (interval).toString()}),
      ReminderRepeat.afterCompletion => t(
        interval == 1 ? 'after_one_day' : 'after_n_days',
        args: {'count': (interval).toString()},
      ),
    };
    return '$label$timeCount';
  }

  DateTime get effectiveAt => snoozedUntil ?? dueAt;
  bool get isActive => !isPaused && !isCompleted;

  /// Strictly after [after], at the original local wall-clock time.
  /// A monthly reminder on the 31st skips months without a 31st.
  DateTime? nextOccurrence(DateTime after) {
    if (repeat == ReminderRepeat.once ||
        repeat == ReminderRepeat.afterCompletion) {
      return null;
    }
    final start = after.isBefore(anchorAt) ? anchorAt : after;
    final step = interval < 1 ? 1 : interval;
    // Calendar math uses UTC dates for day differences so DST never shifts a day.
    final anchorDay = DateTime.utc(anchorAt.year, anchorAt.month, anchorAt.day);
    final startDay = DateTime.utc(start.year, start.month, start.day);
    // February 29 can skip a century (2100) and interval years can also land
    // on non-leap years. Eight interval cycles cover the Gregorian gap.
    final cycles =
        repeat == ReminderRepeat.yearly &&
            anchorAt.month == 2 &&
            anchorAt.day == 29
        ? 8
        : 1;
    for (var offset = 0; offset < 366 * (step * cycles + 1); offset++) {
      final day = startDay.add(Duration(days: offset));
      final elapsed = day.difference(anchorDay).inDays;
      if (elapsed < 0) continue;
      final months =
          (day.year - anchorAt.year) * 12 + day.month - anchorAt.month;
      final monthLast = DateTime(day.year, day.month + 1, 0).day;
      final weekAnchor = anchorDay.subtract(
        Duration(days: anchorAt.weekday - 1),
      );
      final weeks = day.difference(weekAnchor).inDays ~/ 7;
      final matches = switch (repeat) {
        ReminderRepeat.daily => elapsed % step == 0,
        ReminderRepeat.weekly =>
          weeks % step == 0 && weekdays.contains(day.weekday),
        ReminderRepeat.monthly =>
          months % step == 0 &&
              day.day == (lastDayOfMonth ? monthLast : anchorAt.day),
        ReminderRepeat.yearly =>
          (day.year - anchorAt.year) % step == 0 &&
              day.month == anchorAt.month &&
              day.day == anchorAt.day,
        _ => false,
      };
      if (!matches) continue;
      for (final time in times) {
        final candidate = DateTime(
          day.year,
          day.month,
          day.day,
          time ~/ 60,
          time % 60,
        );
        if (candidate.isAfter(after) && !candidate.isBefore(anchorAt)) {
          return candidate;
        }
      }
    }
    return null;
  }

  DateTime? nextAfterCompletion(DateTime completedAt) {
    if (repeat != ReminderRepeat.afterCompletion) {
      final after = dueAt.isAfter(completedAt) ? dueAt : completedAt;
      return nextOccurrence(after);
    }
    return DateTime(
      completedAt.year,
      completedAt.month,
      completedAt.day + interval,
      anchorAt.hour,
      anchorAt.minute,
    );
  }

  Reminder copyWith({
    DateTime? dueAt,
    bool? isPaused,
    bool? isCompleted,
    DateTime? snoozedUntil,
    bool clearSnooze = false,
    bool? isPriority,
    List<String>? tags,
  }) => Reminder(
    id: id,
    title: title,
    note: note,
    anchorAt: anchorAt,
    dueAt: dueAt ?? this.dueAt,
    createdAt: createdAt,
    category: category,
    repeat: repeat,
    weekdays: weekdays,
    sound: sound,
    interval: interval,
    lastDayOfMonth: lastDayOfMonth,
    additionalTimes: additionalTimes,
    leadMinutes: leadMinutes,
    isPriority: isPriority ?? this.isPriority,
    tags: tags ?? this.tags,
    isPaused: isPaused ?? this.isPaused,
    isCompleted: isCompleted ?? this.isCompleted,
    snoozedUntil: clearSnooze ? null : snoozedUntil ?? this.snoozedUntil,
  );

  Map<String, dynamic> toMap() => {
    'schemaVersion': 3,
    'id': id,
    'title': title,
    'note': note,
    'anchorAt': anchorAt.toIso8601String(),
    'dueAt': dueAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'category': category.name,
    'repeat': repeat.name,
    'weekdays': weekdays,
    'interval': interval,
    'lastDayOfMonth': lastDayOfMonth,
    'additionalTimes': additionalTimes,
    'leadMinutes': leadMinutes,
    'isPriority': isPriority,
    'tags': tags,
    'sound': sound.name,
    'isPaused': isPaused,
    'isCompleted': isCompleted,
    'snoozedUntil': snoozedUntil?.toIso8601String(),
  };

  factory Reminder.fromMap(Map<dynamic, dynamic> map) => Reminder(
    id: map['id'] as String,
    title: map['title'] as String,
    note: map['note'] as String? ?? '',
    anchorAt: DateTime.parse(map['anchorAt'] as String),
    dueAt: DateTime.parse(map['dueAt'] as String),
    createdAt: DateTime.parse(map['createdAt'] as String),
    category: ReminderCategory.values.byName(map['category'] as String),
    repeat: ReminderRepeat.values.byName(map['repeat'] as String),
    weekdays: List<int>.from(map['weekdays'] as List? ?? []),
    interval: map['interval'] as int? ?? 1,
    lastDayOfMonth: map['lastDayOfMonth'] as bool? ?? false,
    additionalTimes: List<int>.from(map['additionalTimes'] as List? ?? []),
    leadMinutes: map['leadMinutes'] as int? ?? 0,
    isPriority: map['isPriority'] as bool? ?? false,
    tags: List<String>.from(map['tags'] as List? ?? const []),
    sound: ReminderSound.values.byName(map['sound'] as String),
    isPaused: map['isPaused'] as bool? ?? false,
    isCompleted: map['isCompleted'] as bool? ?? false,
    snoozedUntil: map['snoozedUntil'] == null
        ? null
        : DateTime.parse(map['snoozedUntil'] as String),
  );
}

class ReminderCompletion {
  const ReminderCompletion({
    required this.id,
    required this.reminderId,
    required this.title,
    required this.category,
    required this.scheduledAt,
    required this.completedAt,
  });
  final String id;
  final String reminderId;
  final String title;
  final ReminderCategory category;
  final DateTime scheduledAt;
  final DateTime completedAt;

  Map<String, dynamic> toMap() => {
    'id': id,
    'reminderId': reminderId,
    'title': title,
    'category': category.name,
    'scheduledAt': scheduledAt.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
  };

  factory ReminderCompletion.fromMap(Map<dynamic, dynamic> map) =>
      ReminderCompletion(
        id: map['id'] as String,
        reminderId: map['reminderId'] as String,
        title: map['title'] as String,
        category: ReminderCategory.values.byName(map['category'] as String),
        scheduledAt: DateTime.parse(map['scheduledAt'] as String),
        completedAt: DateTime.parse(map['completedAt'] as String),
      );
}

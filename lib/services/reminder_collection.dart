import 'package:shien/l10n/app_localization.dart';
import 'package:shien/models/reminder.dart';

enum ReminderSort {
  scheduled('sort_time'),
  priority('sort_priority'),
  newest('sort_newest'),
  title('sort_title');

  const ReminderSort(this._labelKey);
  final String _labelKey;
  String get label => t(_labelKey);
}

enum ReminderStatus {
  active('status_pending'),
  paused('status_paused'),
  completed('history_title');

  const ReminderStatus(this._labelKey);
  final String _labelKey;
  String get label => t(_labelKey);

  bool matches(Reminder reminder) => switch (this) {
    active => reminder.isActive,
    paused => reminder.isPaused && !reminder.isCompleted,
    completed => reminder.isCompleted,
  };
}

/// Turkish casing is explicit: Dart's default lowercasing does not map İ to i.
/// Folding accents also supports searches entered with an English keyboard.
String reminderSearchText(String value) => value
    .replaceAll('İ', 'i')
    .replaceAll('I', 'ı')
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c');

List<Reminder> collectReminders(
  Iterable<Reminder> reminders, {
  String query = '',
  ReminderCategory? category,
  String? tag,
  bool priorityOnly = false,
  ReminderStatus status = ReminderStatus.active,
  ReminderSort sort = ReminderSort.scheduled,
}) {
  final words = reminderSearchText(query).trim().split(RegExp(r'\s+'));
  final items = reminders.where((r) {
    if (!status.matches(r) ||
        (category != null && r.category != category) ||
        (tag != null && !r.tags.contains(tag)) ||
        (priorityOnly && !r.isPriority)) {
      return false;
    }
    final text = reminderSearchText('${r.title} ${r.note} ${r.tags.join(' ')}');
    return words.every(text.contains);
  }).toList();
  items.sort((a, b) {
    final order = switch (sort) {
      ReminderSort.scheduled => a.effectiveAt.compareTo(b.effectiveAt),
      ReminderSort.priority => (b.isPriority ? 1 : 0).compareTo(
        a.isPriority ? 1 : 0,
      ),
      ReminderSort.newest => b.createdAt.compareTo(a.createdAt),
      ReminderSort.title => _compareTitles(a.title, b.title),
    };
    if (order != 0) return order;
    final scheduled = a.effectiveAt.compareTo(b.effectiveAt);
    return scheduled != 0 ? scheduled : a.id.compareTo(b.id);
  });
  return items;
}

int _compareTitles(String a, String b) {
  const alphabet = 'abcçdefgğhıijklmnoöprsştuüvyz';
  String lower(String s) =>
      s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  final left = lower(a).runes.toList();
  final right = lower(b).runes.toList();
  for (var i = 0; i < left.length && i < right.length; i++) {
    if (left[i] == right[i]) continue;
    int rank(int rune) {
      final index = alphabet.indexOf(String.fromCharCode(rune));
      return index < 0 ? alphabet.length + rune : index;
    }

    return rank(left[i]).compareTo(rank(right[i]));
  }
  return left.length.compareTo(right.length);
}

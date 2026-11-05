import 'package:shien/l10n/app_localization.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shien/models/reminder.dart';

class ReminderBackup {
  const ReminderBackup(this.reminders, this.completions);
  final List<Reminder> reminders;
  final List<ReminderCompletion> completions;
  Uint8List encode() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'format': 'personal-reminders',
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'reminders': reminders.map((r) => r.toMap()).toList(),
        'completions': completions.map((c) => c.toMap()).toList(),
      }),
    ),
  );
  static ReminderBackup decode(List<int> bytes) {
    if (bytes.length > 5 * 1024 * 1024) {
      throw FormatException(t('error_backup_size'));
    }
    try {
      final map = jsonDecode(utf8.decode(bytes));
      if (map is! Map ||
          map['format'] != 'personal-reminders' ||
          map['version'] != 1) {
        throw const FormatException();
      }
      final reminders = (map['reminders'] as List)
          .map((r) => Reminder.fromMap(r as Map))
          .toList();
      final history = (map['completions'] as List)
          .map((c) => ReminderCompletion.fromMap(c as Map))
          .toList();
      if (reminders.length > 3000 ||
          history.length > 20000 ||
          reminders.map((r) => r.id).toSet().length != reminders.length ||
          history.map((c) => c.id).toSet().length != history.length) {
        throw const FormatException();
      }
      for (final r in reminders) {
        if (r.validationError != null) {
          throw const FormatException();
        }
      }
      return ReminderBackup(reminders, history);
    } catch (e) {
      throw FormatException(t('error_invalid_backup'));
    }
  }
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_app/models/reminder.dart';
import 'package:medicine_app/services/backup/reminder_backup.dart';

void main() {
  final at = DateTime(2026, 10, 26, 20);
  final reminder = Reminder(
    id: 'backup-reminder',
    title: 'Dizi saati',
    note: 'Yeni bölüm',
    anchorAt: at,
    dueAt: at,
    createdAt: at,
    category: ReminderCategory.entertainment,
    repeat: ReminderRepeat.weekly,
    weekdays: [1, 5],
    sound: ReminderSound.chime,
    isPriority: true,
    tags: ['keyif', 'dizi-saati'],
  );
  final completion = ReminderCompletion(
    id: 'completion-1',
    reminderId: reminder.id,
    title: reminder.title,
    category: reminder.category,
    scheduledAt: at,
    completedAt: at.add(const Duration(minutes: 1)),
  );

  test('backup keeps reminder settings, tags and completion history', () {
    final backup = ReminderBackup([reminder], [completion]);
    final restored = ReminderBackup.decode(backup.encode());

    expect(restored.reminders.single.toMap(), reminder.toMap());
    expect(restored.completions.single.toMap(), completion.toMap());
  });

  test('backup rejects unsupported formats and oversized files', () {
    final unsupported = utf8.encode(
      jsonEncode({
        'format': 'personal-reminders',
        'version': 2,
        'reminders': [],
        'completions': [],
      }),
    );
    expect(
      () => ReminderBackup.decode(unsupported),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ReminderBackup.decode(List<int>.filled(5 * 1024 * 1024 + 1, 0)),
      throwsA(isA<FormatException>()),
    );
  });

  test('backup rejects invalid reminder tags', () {
    final invalid = Reminder(
      id: 'invalid-tags',
      title: 'Başlık',
      anchorAt: at,
      dueAt: at,
      createdAt: at,
      tags: List.generate(6, (index) => 'etiket-$index'),
    );
    final bytes = utf8.encode(
      jsonEncode({
        'format': 'personal-reminders',
        'version': 1,
        'reminders': [invalid.toMap()],
        'completions': [],
      }),
    );
    expect(() => ReminderBackup.decode(bytes), throwsA(isA<FormatException>()));
  });
}

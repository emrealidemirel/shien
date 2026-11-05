import 'package:flutter_test/flutter_test.dart';
import 'package:shien/models/reminder.dart';
import 'package:shien/services/reminder_collection.dart';

Reminder item(
  String id,
  String title, {
  bool priority = false,
  bool paused = false,
  bool completed = false,
  List<String> tags = const [],
  String note = '',
  int day = 27,
  int createdDay = 26,
}) => Reminder(
  id: id,
  title: title,
  note: note,
  anchorAt: DateTime(2026, 10, day, 9),
  dueAt: DateTime(2026, 10, day, 9),
  createdAt: DateTime(2026, 10, createdDay),
  isPriority: priority,
  isPaused: paused,
  isCompleted: completed,
  tags: tags,
);

void main() {
  test('Turkish and keyboard-friendly search matches words across fields', () {
    final reminders = [
      item('work', 'İŞ GÖRÜŞMESİ', note: 'Özge ile', tags: ['çarşamba']),
      item('other', 'Alışveriş'),
    ];
    expect(
      collectReminders(reminders, query: '  carsamba   is  ozge ').single.id,
      'work',
    );
    expect(
      collectReminders(reminders, query: 'görüşmesi İŞ').single.id,
      'work',
    );
    expect(collectReminders(reminders, query: 'is olmayan'), isEmpty);
  });

  test('priority sorting keeps chronological order within each priority', () {
    final reminders = [
      item('normal', 'Normal', day: 27),
      item('late', 'Sonra', priority: true, day: 29),
      item('first', 'Önce', priority: true, day: 28),
    ];
    expect(
      collectReminders(reminders, sort: ReminderSort.priority).map((r) => r.id),
      ['first', 'late', 'normal'],
    );
  });

  test('title sorting uses Turkish alphabet, including dotless I', () {
    final reminders = [
      item('i', 'İş'),
      item('s', 'Şehir'),
      item('c', 'Çanta'),
      item('dotless', 'Işık'),
      item('plain', 'Cevap'),
    ];
    expect(
      collectReminders(reminders, sort: ReminderSort.title).map((r) => r.id),
      ['plain', 'c', 'dotless', 'i', 's'],
    );
  });

  test(
    'status filters remain exclusive and combine with tags and priority',
    () {
      final reminders = [
        item('active', 'Aktif', priority: true, tags: ['iş']),
        item('paused', 'Duraklatılan', paused: true),
        item('done', 'Biten', completed: true, paused: true),
      ];
      expect(
        collectReminders(reminders, tag: 'iş', priorityOnly: true).single.id,
        'active',
      );
      expect(
        collectReminders(reminders, status: ReminderStatus.paused).single.id,
        'paused',
      );
      expect(
        collectReminders(reminders, status: ReminderStatus.completed).single.id,
        'done',
      );
    },
  );

  test('newest sorting uses creation date rather than due date', () {
    final reminders = [
      item('old', 'Eski', day: 29),
      item('new', 'Yeni', day: 27, createdDay: 27),
    ];
    expect(
      collectReminders(reminders, sort: ReminderSort.newest).first.id,
      'new',
    );
    expect(reminders.first.id, 'old');
  });
}

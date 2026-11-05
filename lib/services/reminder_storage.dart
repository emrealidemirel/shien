import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:shien/l10n/app_localization.dart';
import 'package:hive/hive.dart';
import 'package:shien/models/medicine.dart';
import 'package:shien/models/medicine_log.dart';
import 'package:shien/models/reminder.dart';

class ReminderStorage {
  ReminderStorage(this.box, {this.accountId});
  String? accountId;
  String get scope => accountId ?? 'guest';
  String get dataKey => accountId == null ? 'data' : 'account:$accountId';
  final Box<dynamic> box;

  Map get _data => box.get(dataKey, defaultValue: <String, dynamic>{}) as Map;
  List<Reminder> get reminders => (_data['reminders'] as List? ?? [])
      .map((e) => Reminder.fromMap(e as Map))
      .toList();
  List<ReminderCompletion> get completions =>
      (_data['completions'] as List? ?? [])
          .map((e) => ReminderCompletion.fromMap(e as Map))
          .toList();

  Map<String, Map<String, dynamic>> get pending => {
    for (final entry in ((_data['pending'] as Map?) ?? {}).entries)
      entry.key as String: Map<String, dynamic>.from(entry.value as Map),
  };

  List<Reminder> get guestReminders =>
      ((box.get('data', defaultValue: {}) as Map)['reminders'] as List? ?? [])
          .map((e) => Reminder.fromMap(e as Map))
          .toList();
  List<ReminderCompletion> get guestCompletions =>
      ((box.get('data', defaultValue: {}) as Map)['completions'] as List? ?? [])
          .map((e) => ReminderCompletion.fromMap(e as Map))
          .toList();

  // Data and its durable upload queue are committed together. Guest writes
  // never enter the queue. Every account has its own isolated device cache.
  Future<void> save(
    List<Reminder> reminders,
    List<ReminderCompletion> completions,
  ) async {
    final next = {
      'reminders': reminders.map((e) => e.toMap()).toList(),
      'completions': completions.map((e) => e.toMap()).toList(),
    };
    final queue = pending;
    if (accountId != null) {
      for (final collection in next.keys) {
        final previous = {
          for (final value in _data[collection] as List? ?? [])
            (value as Map)['id'] as String: value,
        };
        final incoming = {
          for (final value in next[collection]!) value['id'] as String: value,
        };
        for (final id in {...previous.keys, ...incoming.keys}) {
          if (jsonEncode(previous[id]) == jsonEncode(incoming[id])) continue;
          queue['$collection/${Uri.encodeComponent(id)}'] = {
            'mutationId': const Uuid().v4(),
            'data': incoming[id],
          };
        }
      }
    }
    await box.put(dataKey, {...next, 'pending': queue});
  }

  // Called under the Cubit's write queue, just like local edits. Cache-only
  // snapshots may be incomplete and must never erase durable local records.
  Future<void> applyRemote(
    String collection,
    Map<String, Map<String, dynamic>> documents, {
    required bool fromCache,
  }) async {
    final queue = pending;
    final values = <String, Map>{
      if (fromCache)
        for (final value in _data[collection] as List? ?? [])
          (value as Map)['id'] as String: value,
    };
    for (final entry in documents.entries) {
      final path = '$collection/${entry.key}';
      final id = Uri.decodeComponent(entry.key);
      final data = entry.value['data'];
      if (data is Map) {
        if (data['id'] != id) {
          throw const FormatException('Mismatched record ID');
        }
        if (collection == 'reminders') {
          final record = Reminder.fromMap(data);
          if (record.validationError != null) {
            throw const FormatException('Invalid reminder');
          }
        } else {
          ReminderCompletion.fromMap(data);
        }
      }
      if (!fromCache &&
          queue[path]?['mutationId'] == entry.value['mutationId']) {
        queue.remove(path);
      }
      if (data is Map) {
        values[id] = data;
      } else {
        values.remove(id);
      }
    }
    for (final entry in queue.entries.where(
      (e) => e.key.startsWith('$collection/'),
    )) {
      final id = Uri.decodeComponent(
        entry.key.substring(collection.length + 1),
      );
      final data = entry.value['data'];
      if (data is Map) {
        values[id] = data;
      } else {
        values.remove(id);
      }
    }
    await box.put(dataKey, {
      ..._data,
      collection: values.values.toList(),
      'pending': queue,
    });
  }

  Future<void> migrateLegacy(
    Box<Medicine> medicines,
    Box<MedicineLog> logs, {
    DateTime? now,
  }) async {
    if (box.get('legacyMigrated', defaultValue: false) as bool) return;
    final reference = now ?? DateTime.now();
    final migrated = [...reminders];
    for (final medicine in medicines.values) {
      final times = medicine.intakeTimes.isEmpty
          ? ['09:00']
          : medicine.intakeTimes;
      for (var index = 0; index < times.length; index++) {
        final id = 'legacy-${medicine.id}-$index';
        if (migrated.any((r) => r.id == id)) continue;
        final parts = times[index].split(':');
        final parsedHour = parts.length == 2 ? int.tryParse(parts[0]) : null;
        final parsedMinute = parts.length == 2 ? int.tryParse(parts[1]) : null;
        final validTime =
            parsedHour != null &&
            parsedHour >= 0 &&
            parsedHour <= 23 &&
            parsedMinute != null &&
            parsedMinute >= 0 &&
            parsedMinute <= 59;
        final hour = validTime ? parsedHour : 9;
        final minute = validTime ? parsedMinute : 0;
        final monthlyDays = medicine.repeatCycle == RepeatCycle.monthly
            ? medicine.intakeDays
                  .where((day) => day >= 1 && day <= 31)
                  .toSet()
                  .toList()
            : <int>[reference.day];
        final validMonthlyDays = monthlyDays.isNotEmpty;
        if (!validMonthlyDays) monthlyDays.add(reference.day);
        for (final day in monthlyDays) {
          final anchor = DateTime(
            reference.year,
            reference.month,
            1,
            hour,
            minute,
          );
          // Use a month containing the requested day to preserve the 29th–31st.
          final validAnchor = medicine.repeatCycle == RepeatCycle.monthly
              ? DateTime(2024, 1, day, hour, minute)
              : DateTime(
                  reference.year,
                  reference.month,
                  reference.day,
                  hour,
                  minute,
                );
          final reminder = Reminder(
            id: medicine.repeatCycle == RepeatCycle.monthly ? '$id-$day' : id,
            title: medicine.name,
            note: medicine.note ?? '',
            anchorAt: validAnchor,
            dueAt: anchor,
            createdAt: medicine.createdAt,
            category: ReminderCategory.health,
            repeat: switch (medicine.repeatCycle) {
              RepeatCycle.daily => ReminderRepeat.daily,
              RepeatCycle.weekly => ReminderRepeat.weekly,
              RepeatCycle.monthly => ReminderRepeat.monthly,
            },
            weekdays: medicine.intakeDays
                .where((d) => d >= 1 && d <= 7)
                .toSet()
                .toList(),
            isPaused:
                medicine.isActive == false ||
                !validTime ||
                medicine.intakeTimes.isEmpty ||
                !validMonthlyDays,
            isCompleted:
                !(medicine.isUnlimited ?? false) &&
                medicine.remainingCount == 0,
          );
          final next = reminder.nextOccurrence(reference);
          if (!migrated.any((r) => r.id == reminder.id)) {
            migrated.add(
              reminder.copyWith(
                dueAt: next ?? reference,
                isPaused: next == null ? true : reminder.isPaused,
              ),
            );
          }
        }
      }
    }
    final history = [...completions];
    for (final log in logs.values.where((l) => l.isTaken)) {
      if (history.any((entry) => entry.id == 'legacy-${log.id}')) continue;
      history.add(
        ReminderCompletion(
          id: 'legacy-${log.id}',
          reminderId: 'legacy-${log.medicineId}-0',
          title: medicines.get(log.medicineId)?.name ?? t('legacy_reminder'),
          category: ReminderCategory.health,
          scheduledAt: log.scheduledTime,
          completedAt: log.actualTakenTime ?? log.createdAt,
        ),
      );
    }
    await save(migrated, history);
    await box.put('legacyMigrated', true);
    // Legacy boxes remain intact for rollback and for the original missed logs.
  }
}

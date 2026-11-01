import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:medicine_app/models/reminder.dart';
import 'package:uuid/uuid.dart';

class ReminderAction {
  const ReminderAction({
    required this.id,
    required this.reminderId,
    required this.kind,
    required this.expectedAt,
    required this.at,
    this.signature = '',
    this.scope = 'guest',
  });
  final String id, reminderId, kind;
  final String signature, scope;
  final DateTime expectedAt, at;
  Map<String, dynamic> toMap() => {
    'id': id,
    'reminderId': reminderId,
    'kind': kind,
    'signature': signature,
    'scope': scope,
    'expectedAt': expectedAt.toIso8601String(),
    'at': at.toIso8601String(),
  };
  factory ReminderAction.fromMap(Map m) => ReminderAction(
    id: m['id'] as String,
    reminderId: m['reminderId'] as String,
    kind: m['kind'] as String,
    signature: m['signature'] as String? ?? '',
    scope: m['scope'] as String? ?? 'guest',
    expectedAt: DateTime.parse(m['expectedAt'] as String),
    at: DateTime.parse(m['at'] as String),
  );
  factory ReminderAction.create(
    Reminder r,
    String kind,
    DateTime expectedAt, {
    String scope = 'guest',
  }) => ReminderAction(
    id: kind == 'done' ? reminderCompletionId(r) : const Uuid().v4(),
    scope: scope,
    signature: reminderActionSignature(r),
    reminderId: r.id,
    kind: kind,
    expectedAt: expectedAt,
    at: DateTime.now(),
  );
}

/// A background notification/widget isolate writes commands rather than opening
/// Hive concurrently. Each file is committed by rename and replayed idempotently
/// by the main isolate, including after process death.
class ReminderActionQueue {
  static Future<Directory> _folder() async {
    final support = await getApplicationSupportDirectory();
    return Directory(
      '${support.path}/reminder-actions-v1',
    ).create(recursive: true);
  }

  static Future<void> setActiveScope(String scope) async {
    final folder = await _folder();
    final temp = File('${folder.path}/active-scope.tmp');
    await temp.writeAsString(scope, flush: true);
    await temp.rename('${folder.path}/active-scope');
  }

  static Future<String> activeScope() async {
    final file = File('${(await _folder()).path}/active-scope');
    return await file.exists() ? file.readAsString() : 'guest';
  }

  static Future<void> add(ReminderAction action) async {
    final folder = await _folder();
    final temp = File(
      '${folder.path}/${Uri.encodeComponent(action.scope)}-${action.id}.tmp',
    );
    await temp.writeAsString(jsonEncode(action.toMap()), flush: true);
    await temp.rename(
      '${folder.path}/${Uri.encodeComponent(action.scope)}-${action.id}.json',
    );
  }

  static Future<List<(File, ReminderAction)>> pending() async {
    final folder = await _folder();
    final result = <(File, ReminderAction)>[];
    await for (final entry in folder.list()) {
      if (entry is File && entry.path.endsWith('.json')) {
        try {
          result.add((
            entry,
            ReminderAction.fromMap(
              jsonDecode(await entry.readAsString()) as Map,
            ),
          ));
        } catch (_) {
          await entry.rename('${entry.path}.invalid');
        }
      }
    }
    result.sort((a, b) => a.$2.at.compareTo(b.$2.at));
    return result;
  }
}

(Reminder, ReminderCompletion?)? applyReminderAction(
  Reminder r,
  ReminderAction action,
) {
  if ((action.signature.isNotEmpty &&
          action.signature != reminderActionSignature(r)) ||
      r.id != action.reminderId ||
      !r.isActive ||
      r.effectiveAt.isAfter(action.expectedAt)) {
    return null;
  }
  if (action.kind == 'snooze10') {
    return (
      r.copyWith(snoozedUntil: action.at.add(const Duration(minutes: 10))),
      null,
    );
  }
  if (action.kind != 'done') return null;
  final next = r.nextAfterCompletion(action.at);
  return (
    r.copyWith(dueAt: next, isCompleted: next == null, clearSnooze: true),
    ReminderCompletion(
      id: action.id,
      reminderId: r.id,
      title: r.title,
      category: r.category,
      scheduledAt: r.dueAt,
      completedAt: action.at,
    ),
  );
}

String reminderActionSignature(Reminder r) {
  final map = r.toMap()
    ..remove('dueAt')
    ..remove('snoozedUntil')
    ..remove('isCompleted')
    ..remove('isPaused');
  return jsonEncode(map);
}

String reminderCompletionId(Reminder reminder) => const Uuid().v5(
  Namespace.url.value,
  'shien/${reminder.id}/${reminder.dueAt.toIso8601String()}',
);

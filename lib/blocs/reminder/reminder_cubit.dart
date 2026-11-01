import 'package:medicine_app/l10n/app_localization.dart';
import 'package:medicine_app/services/reminder_widget_service.dart';
import 'package:medicine_app/services/reminder_actions.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medicine_app/models/reminder.dart';
import 'package:medicine_app/services/reminder_storage.dart';
import 'package:medicine_app/services/notifications/reminder_notification_service.dart';

part 'reminder_state.dart';

class ReminderCubit extends Cubit<ReminderState> {
  ReminderCubit({
    required this.storage,
    required this.notifications,
    this.widgets,
  }) : super(
         ReminderState(
           scope: storage.scope,
           reminders: storage.reminders,
           completions: storage.completions,
           themeMode: ThemeMode.values.byName(
             storage.box.get('themeMode', defaultValue: 'system') as String,
           ),
           defaultSound: ReminderSound.values.byName(
             storage.box.get('defaultSound', defaultValue: 'soft') as String,
           ),
         ),
       );

  final ReminderWidgetService? widgets;
  final ReminderStorage storage;
  final ReminderNotifications notifications;
  final Map<String, (Reminder, Reminder)> _undo = {};
  bool writesBlocked = false;
  int _generation = 0;
  Future<void> _changes = Future<void>.value();
  Future<void> _refreshes = Future<void>.value();

  // Lifecycle refreshes and edits can arrive together. Schedule each refresh
  // in order so an older snapshot cannot replace the latest notifications.
  Future<void> refresh() {
    final next = _refreshes.then((_) => _refresh());
    _refreshes = next.catchError((Object _) {});
    return next;
  }

  Future<void> _refresh() async {
    if (isClosed) return;
    if (notifications is ReminderNotificationService) {
      await ReminderActionQueue.setActiveScope(storage.scope);
      (notifications as ReminderNotificationService).accountScope =
          storage.scope;
    }
    widgets?.accountScope = storage.scope;
    try {
      await widgets?.sync(state.reminders);
    } catch (e) {
      debugPrint('Widget refresh failed: ${e.runtimeType}');
    }
    try {
      final enabled = await notifications.isEnabled();
      await notifications.sync(state.reminders);
      if (!isClosed) {
        emit(state.copyWith(notificationsEnabled: enabled, clearError: true));
      }
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(error: t('error_notification_schedule')));
      }
    }
  }

  Future<void> consumePendingActions() => _change(() async {
    final pending = (await ReminderActionQueue.pending())
        .where((entry) => entry.$2.scope == storage.scope)
        .toList();
    if (pending.isEmpty) return;
    final reminders = [...state.reminders];
    final history = [...state.completions];
    for (final entry in pending) {
      final action = entry.$2;
      if (history.any((c) => c.id == action.id)) continue;
      final index = reminders.indexWhere((r) => r.id == action.reminderId);
      if (index == -1) continue;
      final result = applyReminderAction(reminders[index], action);
      if (result == null) continue;
      reminders[index] = result.$1;
      if (result.$2 != null) history.add(result.$2!);
    }
    await _persist(reminders, history);
    for (final entry in pending) {
      if (await entry.$1.exists()) await entry.$1.delete();
    }
  });

  Future<void> enableNotifications() async {
    try {
      final enabled = await notifications.requestPermission();
      emit(state.copyWith(notificationsEnabled: enabled));
      await refresh();
    } catch (_) {
      emit(state.copyWith(error: t('error_notification_permission')));
    }
  }

  Future<void> _change(Future<void> Function() action) {
    final generation = _generation;
    final next = _changes.then((_) {
      if (writesBlocked || generation != _generation) {
        throw StateError(t('sync_account_changed'));
      }
      return action();
    });
    _changes = next.catchError((Object _) {});
    return next;
  }

  Future<void> switchAccount(String? uid) {
    _generation++;
    final next = _changes.then((_) async {
      if (storage.accountId == uid) return;
      storage.accountId = uid;
      if (notifications is ReminderNotificationService) {
        (notifications as ReminderNotificationService).launchId = null;
      }
      _undo.clear();
      emit(
        state.copyWith(
          scope: storage.scope,
          reminders: storage.reminders,
          completions: storage.completions,
          clearError: true,
        ),
      );
      await refresh();
    });
    _changes = next.catchError((Object _) {});
    return next;
  }

  Future<void> applyCloudSnapshot(
    String uid,
    String collection,
    Map<String, Map<String, dynamic>> documents, {
    required bool fromCache,
  }) {
    final next = _changes.then((_) async {
      if (storage.accountId != uid || isClosed) return;
      await storage.applyRemote(collection, documents, fromCache: fromCache);
      final reminders = storage.reminders;
      final history = storage.completions;
      if (jsonEncode(reminders.map((e) => e.toMap()).toList()) ==
              jsonEncode(state.reminders.map((e) => e.toMap()).toList()) &&
          jsonEncode(history.map((e) => e.toMap()).toList()) ==
              jsonEncode(state.completions.map((e) => e.toMap()).toList())) {
        return;
      }
      emit(state.copyWith(reminders: reminders, completions: history));
      await refresh();
    });
    _changes = next.catchError((Object _) {});
    return next;
  }

  Future<void> clearAccountCache(String uid) {
    final next = _changes.then((_) async {
      await storage.box.delete('account:$uid');
      if (storage.accountId == uid) {
        _undo.clear();
        emit(state.copyWith(reminders: [], completions: []));
        await refresh();
      }
    });
    _changes = next.catchError((Object _) {});
    return next;
  }

  Future<int> importGuestRecords() {
    if (storage.accountId == null) throw StateError(t('sync_account_changed'));
    return mergeBackup(storage.guestReminders, storage.guestCompletions);
  }

  Future<void> _persist(
    List<Reminder> reminders,
    List<ReminderCompletion> history,
  ) async {
    final slots = reminderNotificationSlots(reminders);
    if (slots > 60 && slots > reminderNotificationSlots(state.reminders)) {
      throw StateError(t('error_notification_capacity'));
    }
    await storage.save(reminders, history);
    emit(
      state.copyWith(
        reminders: reminders,
        completions: history,
        clearError: true,
      ),
    );
    await refresh();
  }

  Future<void> save(Reminder reminder, {Reminder? expected}) =>
      _change(() async {
        if (expected != null) {
          final current = state.reminders
              .where((r) => r.id == reminder.id)
              .firstOrNull;
          if (current == null ||
              jsonEncode(current.toMap()) != jsonEncode(expected.toMap())) {
            throw StateError(t('error_reminder_changed_edit'));
          }
        }
        final error = reminder.validationError;
        if (error != null) throw ArgumentError(error);
        final reminders = [...state.reminders];
        final index = reminders.indexWhere((r) => r.id == reminder.id);
        if (index == -1) {
          reminders.add(reminder);
        } else {
          reminders[index] = reminder;
        }
        await _persist(reminders, state.completions);
      });

  Future<String?> complete(
    String id, {
    DateTime? at,
    Reminder? expected,
  }) async {
    String? completionId;
    await _change(() async {
      final index = state.reminders.indexWhere((r) => r.id == id);
      if (index == -1) return;
      final reminder = state.reminders[index];
      if (expected != null &&
          jsonEncode(reminder.toMap()) != jsonEncode(expected.toMap())) {
        throw StateError(t('error_reminder_changed'));
      }
      if (!reminder.isActive) return;
      final now = at ?? DateTime.now();
      final next = reminder.nextAfterCompletion(now);
      final updated = reminder.copyWith(
        dueAt: next,
        isCompleted: next == null,
        clearSnooze: true,
      );
      final reminders = [...state.reminders]..[index] = updated;
      completionId = reminderCompletionId(reminder);
      final history = [
        ...state.completions,
        ReminderCompletion(
          id: completionId!,
          reminderId: id,
          title: reminder.title,
          category: reminder.category,
          scheduledAt: reminder.dueAt,
          completedAt: now,
        ),
      ];
      await _persist(reminders, history);
      _undo[completionId!] = (reminder, updated);
    });
    return completionId;
  }

  Future<void> undoCompletion(String completionId) => _change(() async {
    final entry = _undo[completionId];
    if (entry == null) return;
    final current = state.reminders
        .where((r) => r.id == entry.$1.id)
        .firstOrNull;
    if (current == null ||
        jsonEncode(current.toMap()) != jsonEncode(entry.$2.toMap())) {
      throw StateError(t('error_undo_changed'));
    }
    await _persist(
      state.reminders.map((r) => r.id == entry.$1.id ? entry.$1 : r).toList(),
      state.completions.where((c) => c.id != completionId).toList(),
    );
    _undo.remove(completionId);
  });

  Future<void> snooze(String id, Duration duration) => _change(() async {
    if (duration <= Duration.zero) {
      throw ArgumentError(t('error_snooze_positive'));
    }
    final now = DateTime.now();
    final updated = state.reminders
        .map(
          (r) => r.id == id && r.isActive
              ? r.copyWith(
                  snoozedUntil:
                      (r.effectiveAt.isAfter(now) ? r.effectiveAt : now).add(
                        duration,
                      ),
                )
              : r,
        )
        .toList();
    await _persist(updated, state.completions);
  });

  Future<void> togglePause(String id) => _change(() async {
    final now = DateTime.now();
    final reminders = state.reminders.map((r) {
      if (r.id != id || r.isCompleted) return r;
      if (r.isPaused &&
          r.repeat == ReminderRepeat.once &&
          !r.dueAt.isAfter(now)) {
        throw StateError(t('error_date_passed'));
      }
      return r.copyWith(
        dueAt: r.isPaused && !r.dueAt.isAfter(now)
            ? r.nextOccurrence(now)
            : null,
        isPaused: !r.isPaused,
        clearSnooze: true,
      );
    }).toList();
    await _persist(reminders, state.completions);
  });

  Future<void> delete(String id) => _change(() async {
    await _persist(
      state.reminders.where((r) => r.id != id).toList(),
      state.completions,
    );
  });

  Future<int> mergeBackup(
    List<Reminder> incoming,
    List<ReminderCompletion> history,
  ) async {
    var added = 0;
    await _change(() async {
      for (final reminder in incoming) {
        final error = reminder.validationError;
        if (error != null) throw ArgumentError(error);
      }
      final ids = state.reminders.map((r) => r.id).toSet();
      final completionIds = state.completions.map((c) => c.id).toSet();
      final additions = incoming.where((r) => ids.add(r.id)).toList();
      added = additions.length;
      // Existing local records always win; importing a backup never silently
      // overwrites edits or reopens an already-completed local reminder.
      await _persist(
        [...state.reminders, ...additions],
        [
          ...state.completions,
          ...history.where((c) => completionIds.add(c.id)),
        ],
      );
    });
    return added;
  }

  Future<void> clearHistory() => _change(() => _persist(state.reminders, []));

  Future<void> setTheme(ThemeMode mode) async {
    await storage.box.put('themeMode', mode.name);
    emit(state.copyWith(themeMode: mode));
  }

  Future<void> setDefaultSound(ReminderSound sound) async {
    await storage.box.put('defaultSound', sound.name);
    emit(state.copyWith(defaultSound: sound));
  }

  void dismissError() => emit(state.copyWith(clearError: true));
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:medicine_app/blocs/reminder/reminder_cubit.dart';
import 'package:medicine_app/services/auth/auth_service.dart';
import 'package:medicine_app/services/sync/cloud_reminder_store.dart';

/// Coordinates account changes, durable local edits and live remote snapshots.
/// No snapshot or write completion from a former session may affect a new one.
class CloudReminderSync extends ChangeNotifier {
  CloudReminderSync({
    required this.auth,
    required this.cubit,
    required this.store,
  });
  static CloudReminderSync? current;
  final AuthService auth;
  final ReminderCubit cubit;
  final CloudReminderStore store;
  final List<StreamSubscription<CloudReminderSnapshot>> _streams = [];
  StreamSubscription<dynamic>? _local;
  Timer? _retry;
  Future<void> _sessions = Future.value();
  String? _uid;
  String? _desiredUid;
  int _epoch = 0;
  int? _flushingEpoch;
  bool _closed = false, _deleting = false, _error = false;
  final Map<String, bool> _server = {};

  String get statusKey {
    if (_desiredUid == null) return 'sync_guest';
    if (_error) return 'sync_error';
    if (_uid != _desiredUid ||
        _server.length < 2 ||
        _server.values.any((v) => !v)) {
      return 'sync_connecting';
    }
    if (cubit.storage.pending.isNotEmpty) return 'sync_pending';
    return 'sync_ready';
  }

  Future<void> start() {
    auth.addListener(_onAuth);
    _local = cubit.storage.box.watch().listen((_) {
      if (_closed) return;
      notifyListeners();
      unawaited(_flush());
    });
    _retry = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_flush()),
    );
    _onAuth(force: true);
    return _sessions;
  }

  void _onAuth({bool force = false}) {
    final user = auth.user;
    final next = user != null && !user.isAnonymous ? user.uid : null;
    if (!force && next == _desiredUid) return;
    _desiredUid = next;
    final epoch = ++_epoch;
    _sessions = _sessions.catchError((Object _) {}).then((_) async {
      if (_closed || epoch != _epoch) return;
      for (final stream in _streams) {
        await stream.cancel();
      }
      _streams.clear();
      _server.clear();
      _error = false;
      _deleting = false;
      _uid = next;
      await cubit.switchAccount(next);
      if (_closed || epoch != _epoch) return;
      await cubit.consumePendingActions();
      if (_closed || epoch != _epoch) return;
      if (next != null) {
        for (final collection in ['reminders', 'completions']) {
          _streams.add(
            store
                .watch(next, collection)
                .listen(
                  (snapshot) async {
                    if (_closed || epoch != _epoch || _deleting) return;
                    try {
                      await cubit.applyCloudSnapshot(
                        next,
                        collection,
                        snapshot.documents,
                        fromCache: snapshot.fromCache,
                      );
                      if (_closed || epoch != _epoch) return;
                      _server[collection] = !snapshot.fromCache;
                      _error = false;
                      notifyListeners();
                      unawaited(_flush());
                    } catch (_) {
                      if (!_closed && epoch == _epoch) {
                        _error = true;
                        notifyListeners();
                      }
                    }
                  },
                  onError: (Object _) {
                    if (!_closed && epoch == _epoch) {
                      _error = true;
                      notifyListeners();
                    }
                  },
                ),
          );
        }
        unawaited(_flush());
      }
      notifyListeners();
    });
  }

  Future<void> retry() async {
    _onAuth(force: true);
    await _sessions;
  }

  Future<void> _flush() async {
    final uid = _uid;
    final epoch = _epoch;
    if (_closed ||
        _deleting ||
        uid == null ||
        uid != _desiredUid ||
        cubit.storage.accountId != uid ||
        _flushingEpoch == epoch) {
      return;
    }
    final entries = cubit.storage.pending.entries.take(400);
    final batch = Map<String, Map<String, dynamic>>.fromEntries(entries);
    if (batch.isEmpty) return;
    _flushingEpoch = epoch;
    try {
      await store.write(uid, batch);
      // Only a server snapshot with the matching mutationId acknowledges a
      // queued edit. A newer edit made during upload remains in the outbox.
      if (!_closed && epoch == _epoch) {
        _error = false;
      }
    } catch (_) {
      if (!_closed && epoch == _epoch) {
        _error = true;
      }
    } finally {
      if (_flushingEpoch == epoch) _flushingEpoch = null;
      if (!_closed && epoch == _epoch) {
        notifyListeners();
        if (!_error &&
            cubit.storage.pending.entries.any(
              (entry) =>
                  batch[entry.key]?['mutationId'] != entry.value['mutationId'],
            )) {
          unawaited(_flush());
        }
      }
    }
  }

  Future<void> deleteAccountData() async {
    final uid = _uid;
    if (uid == null) return;
    _deleting = true;
    cubit.writesBlocked = true;
    try {
      // Flush queued SDK writes before removal so they cannot resurrect data.
      // The AuthService verifies recent authentication before this is called.
      await store.deleteAccountData(uid).timeout(const Duration(seconds: 45));
      await cubit.clearAccountCache(uid);
    } catch (_) {
      finishAccountDeletion();
      rethrow;
    }
  }

  void finishAccountDeletion() {
    _deleting = false;
    cubit.writesBlocked = false;
  }

  Future<void> close() async {
    _closed = true;
    _epoch++;
    auth.removeListener(_onAuth);
    _retry?.cancel();
    await _local?.cancel();
    for (final stream in _streams) {
      await stream.cancel();
    }
    super.dispose();
  }
}

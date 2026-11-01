import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:medicine_app/blocs/reminder/reminder_cubit.dart';
import 'package:medicine_app/models/reminder.dart';
import 'package:medicine_app/services/auth/auth_service.dart';
import 'package:medicine_app/services/reminder_actions.dart';
import 'package:medicine_app/services/reminder_storage.dart';
import 'package:medicine_app/services/sync/cloud_reminder_store.dart';
import 'package:medicine_app/services/sync/cloud_reminder_sync.dart';
import 'reminder_test.dart' show reminder, FakeNotifications;

class SessionUser implements User {
  SessionUser(this.uid, {this.isAnonymous = false});
  @override
  final String uid;
  @override
  final bool isAnonymous;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SessionAuth extends AuthService {
  User? current;
  @override
  User? get user => current;
  void use(User? value) {
    current = value;
    notifyListeners();
  }
}

class MemoryCloud implements CloudReminderStore {
  final channels = <String, StreamController<CloudReminderSnapshot>>{};
  final documents = <String, Map<String, Map<String, dynamic>>>{};
  final writes = <String>[];
  bool failWrites = false;
  @override
  Stream<CloudReminderSnapshot> watch(String uid, String collection) {
    final key = '$uid/$collection';
    final stream = channels.putIfAbsent(
      key,
      () => StreamController.broadcast(),
    );
    scheduleMicrotask(() => send(uid, collection));
    return stream.stream;
  }

  void send(String uid, String collection, {bool fromCache = false}) {
    final key = '$uid/$collection';
    channels[key]?.add(
      CloudReminderSnapshot(
        Map.from(documents[key] ?? {}),
        fromCache: fromCache,
      ),
    );
  }

  @override
  Future<void> write(
    String uid,
    Map<String, Map<String, dynamic>> mutations,
  ) async {
    if (failWrites) throw StateError('offline');
    writes.add(uid);
    for (final entry in mutations.entries) {
      final slash = entry.key.indexOf('/');
      final collection = entry.key.substring(0, slash);
      final id = entry.key.substring(slash + 1);
      (documents['$uid/$collection'] ??= {})[id] = Map.from(entry.value);
    }
    send(uid, 'reminders');
    send(uid, 'completions');
  }

  @override
  Future<void> deleteAccountData(String uid) async {
    documents.removeWhere((key, _) => key.startsWith('$uid/'));
  }

  Future<void> close() async {
    for (final stream in channels.values) {
      await stream.close();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Box<dynamic> box;
  late ReminderStorage storage;
  late ReminderCubit cubit;
  late FakeNotifications notifications;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('shien_sync_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('sync');
    storage = ReminderStorage(box);
    notifications = FakeNotifications();
    cubit = ReminderCubit(storage: storage, notifications: notifications);
  });
  tearDown(() async {
    await cubit.close();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'rapid account switches finish in the most recently requested scope',
    () async {
      await cubit.switchAccount('a');
      final toB = cubit.switchAccount('b');
      final backToA = cubit.switchAccount('a');
      await Future.wait([toB, backToA]);
      expect(storage.accountId, 'a');
      expect(cubit.state.scope, 'a');
    },
  );

  test(
    'guest edits never enter upload queue and account caches are isolated',
    () async {
      await cubit.save(reminder());
      expect(storage.pending, isEmpty);
      await cubit.switchAccount('alice');
      expect(cubit.state.reminders, isEmpty);
      await cubit.save(reminder(id: 'alice-only'));
      expect(storage.pending, hasLength(1));
      await cubit.switchAccount('bob');
      expect(cubit.state.reminders, isEmpty);
      expect(storage.pending, isEmpty);
      expect(notifications.scheduled, isEmpty);
      await cubit.switchAccount(null);
      expect(cubit.state.reminders.single.id, 'r1');
      expect(storage.pending, isEmpty);
      await cubit.switchAccount('alice');
      expect(cubit.state.reminders.single.id, 'alice-only');
      expect(storage.pending, hasLength(1));
    },
  );
  test('offline edit and deletion survive reopening Hive', () async {
    await cubit.switchAccount('alice');
    await cubit.save(reminder());
    await cubit.delete('r1');
    final mutation = storage.pending['reminders/r1']!['mutationId'];
    await box.close();
    box = await Hive.openBox<dynamic>('sync');
    final restored = ReminderStorage(box, accountId: 'alice');
    expect(restored.reminders, isEmpty);
    expect(restored.pending['reminders/r1']!['data'], isNull);
    expect(restored.pending['reminders/r1']!['mutationId'], mutation);
  });
  test('incomplete cache never clears existing durable records', () async {
    await cubit.switchAccount('alice');
    await cubit.save(reminder());
    final pending = storage.pending['reminders/r1']!;
    await cubit.applyCloudSnapshot('alice', 'reminders', {
      'r1': pending,
    }, fromCache: false);
    expect(storage.pending, isEmpty);
    await cubit.applyCloudSnapshot('alice', 'reminders', {}, fromCache: true);
    expect(cubit.state.reminders, hasLength(1));
    await cubit.applyCloudSnapshot('alice', 'reminders', {}, fromCache: false);
    expect(cubit.state.reminders, isEmpty);
  });
  test('late acknowledgement never removes a newer local edit', () async {
    await cubit.switchAccount('alice');
    await cubit.save(reminder());
    final first = storage.pending['reminders/r1']!;
    await cubit.save(
      Reminder.fromMap({...reminder().toMap(), 'title': 'New title'}),
    );
    final second = storage.pending['reminders/r1']!;
    await cubit.applyCloudSnapshot('alice', 'reminders', {
      'r1': first,
    }, fromCache: false);
    expect(cubit.state.reminders.single.title, 'New title');
    expect(
      storage.pending['reminders/r1']!['mutationId'],
      second['mutationId'],
    );
    await cubit.applyCloudSnapshot('alice', 'reminders', {
      'r1': second,
    }, fromCache: false);
    expect(storage.pending, isEmpty);
  });
  test('pending tombstone wins over a stale remote record', () async {
    await cubit.switchAccount('alice');
    await cubit.save(reminder());
    final old = storage.pending['reminders/r1']!;
    await cubit.delete('r1');
    final deleted = storage.pending['reminders/r1']!;
    await cubit.applyCloudSnapshot('alice', 'reminders', {
      'r1': old,
    }, fromCache: false);
    expect(cubit.state.reminders, isEmpty);
    await cubit.applyCloudSnapshot('alice', 'reminders', {
      'r1': deleted,
    }, fromCache: false);
    expect(storage.pending, isEmpty);
  });
  test(
    'callbacks from a former account cannot populate the current account',
    () async {
      await cubit.switchAccount('bob');
      await cubit.applyCloudSnapshot('alice', 'reminders', {
        'r1': {'data': reminder().toMap(), 'mutationId': 'late'},
      }, fromCache: false);
      expect(cubit.state.reminders, isEmpty);
      expect(storage.pending, isEmpty);
    },
  );
  test(
    'malformed cloud data is rejected before it reaches persistent cache',
    () async {
      await cubit.switchAccount('alice');
      await cubit.save(reminder());
      final before = box.get(storage.dataKey);
      await expectLater(
        cubit.applyCloudSnapshot('alice', 'reminders', {
          'r1': {
            'data': {'id': 'r1', 'title': 'bad'},
          },
        }, fromCache: false),
        throwsA(isA<Error>()),
      );
      expect(box.get(storage.dataKey), before);
      expect(cubit.state.reminders.single.title, 'Dizi saati');
    },
  );
  test(
    'IDs with path characters are encoded and round-trip without changing identity',
    () async {
      await cubit.switchAccount('alice');
      await cubit.save(reminder(id: 'a/b% c'));
      final entry = storage.pending.entries.single;
      expect(entry.key, 'reminders/a%2Fb%25%20c');
      await cubit.applyCloudSnapshot('alice', 'reminders', {
        'a%2Fb%25%20c': entry.value,
      }, fromCache: false);
      expect(cubit.state.reminders.single.id, 'a/b% c');
      expect(storage.pending, isEmpty);
    },
  );
  test(
    'guest import preserves both guest copy and existing account records',
    () async {
      await cubit.save(reminder());
      await cubit.switchAccount('alice');
      await cubit.save(
        Reminder.fromMap({...reminder().toMap(), 'title': 'Account copy'}),
      );
      expect(await cubit.importGuestRecords(), 0);
      expect(cubit.state.reminders.single.title, 'Account copy');
      await cubit.switchAccount(null);
      expect(cubit.state.reminders.single.title, 'Dizi saati');
    },
  );
  test(
    'same occurrence completed on two devices has one history identity',
    () async {
      final r = reminder(repeat: ReminderRepeat.daily);
      final a = ReminderAction.create(r, 'done', r.dueAt, scope: 'alice');
      final b = ReminderAction.create(r, 'done', r.dueAt, scope: 'alice');
      expect(a.id, b.id);
      await cubit.save(r);
      expect(await cubit.complete(r.id, at: r.dueAt), a.id);
    },
  );
  test(
    'cloud controller retries failures without uploading guest data',
    () async {
      final auth = SessionAuth();
      final cloud = MemoryCloud()..failWrites = true;
      final sync = CloudReminderSync(auth: auth, cubit: cubit, store: cloud);
      await sync.start();
      await cubit.save(reminder(id: 'guest'));
      expect(cloud.writes, isEmpty);
      auth.use(SessionUser('alice'));
      await sync.retry();
      await cubit.save(reminder(id: 'cloud'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(storage.pending, isNotEmpty);
      expect(sync.statusKey, 'sync_error');
      cloud.failWrites = false;
      await sync.retry();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(storage.pending, isEmpty);
      expect(cloud.documents['alice/reminders']!.keys, ['cloud']);
      expect(sync.statusKey, 'sync_ready');
      auth.use(null);
      await sync.retry();
      expect(cubit.state.reminders.single.id, 'guest');
      await sync.close();
      await cloud.close();
      auth.dispose();
    },
  );
}

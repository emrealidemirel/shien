import 'package:cloud_firestore/cloud_firestore.dart';

class CloudReminderSnapshot {
  const CloudReminderSnapshot(this.documents, {required this.fromCache});
  final Map<String, Map<String, dynamic>> documents;
  final bool fromCache;
}

abstract class CloudReminderStore {
  Stream<CloudReminderSnapshot> watch(String uid, String collection);
  Future<void> write(String uid, Map<String, Map<String, dynamic>> mutations);
  Future<void> deleteAccountData(String uid);
}

class FirestoreReminderStore implements CloudReminderStore {
  FirestoreReminderStore(this.firestore);
  final FirebaseFirestore firestore;

  @override
  Stream<CloudReminderSnapshot> watch(String uid, String collection) =>
      firestore
          .collection('users/$uid/$collection')
          .snapshots(includeMetadataChanges: true)
          .map(
            (snapshot) => CloudReminderSnapshot(
              {for (final doc in snapshot.docs) doc.id: doc.data()},
              fromCache:
                  snapshot.metadata.isFromCache ||
                  snapshot.metadata.hasPendingWrites,
            ),
          );

  @override
  Future<void> write(
    String uid,
    Map<String, Map<String, dynamic>> mutations,
  ) async {
    final batch = firestore.batch();
    for (final entry in mutations.entries) {
      // Tombstones preserve deletion across offline devices and acknowledge
      // deleted records by mutationId just like inserts/updates.
      batch.set(firestore.doc('users/$uid/${entry.key}'), {
        ...entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> deleteAccountData(String uid) async {
    await firestore.waitForPendingWrites();
    // Block writes from every device before deleting collections.
    await firestore.doc('users/$uid').set({
      'deleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final collection in ['reminders', 'completions', 'profile']) {
      while (true) {
        final page = await firestore
            .collection('users/$uid/$collection')
            .limit(400)
            .get(const GetOptions(source: Source.server));
        if (page.docs.isEmpty) break;
        final batch = firestore.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
  }
}

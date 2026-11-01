import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:medicine_app/services/auth/auth_service.dart';

class AccountProfileService extends ChangeNotifier {
  AccountProfileService({required this.auth, required this.firestore});
  static AccountProfileService? current;
  final AuthService auth;
  final FirebaseFirestore firestore;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  String? _uid;
  Map<String, dynamic> _data = {};
  bool _closed = false;

  String? get displayName {
    final custom = _data['displayName'] as String?;
    if (custom != null && custom.trim().isNotEmpty) return custom;
    return providerDisplayName(auth);
  }

  static String? providerDisplayName(AuthService auth) {
    final user = auth.user;
    if (user == null || user.isAnonymous) return null;
    if (user.displayName?.trim().isNotEmpty ?? false) return user.displayName;
    for (final provider in user.providerData) {
      if (provider.displayName?.trim().isNotEmpty ?? false) {
        return provider.displayName;
      }
    }
    return null;
  }

  String? get photoUrl {
    if (_data['photoHidden'] == true || photoBytes != null) return null;
    final user = auth.user;
    final url =
        user?.photoURL ??
        user?.providerData
            .map((p) => p.photoURL)
            .whereType<String>()
            .firstOrNull;
    return url != null && Uri.tryParse(url)?.scheme == 'https' ? url : null;
  }

  Uint8List? get photoBytes {
    final encoded = _data['photoBase64'];
    if (encoded is! String || encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  void start() {
    auth.addListener(_changed);
    _changed();
  }

  void _changed() {
    final user = auth.user;
    final uid = user != null && !user.isAnonymous ? user.uid : null;
    if (_uid == uid) {
      notifyListeners();
      return;
    }
    _uid = uid;
    _data = {};
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (uid != null) {
      _subscription = firestore
          .doc('users/$uid/profile/main')
          .snapshots()
          .listen(
            (snapshot) {
              if (_closed || _uid != uid) return;
              _data = snapshot.data() ?? {};
              notifyListeners();
            },
            onError: (Object _) {
              // Provider name/photo remain available if the profile cannot load.
            },
          );
    }
    notifyListeners();
  }

  Future<void> save({
    required String displayName,
    Uint8List? photo,
    bool removePhoto = false,
  }) async {
    final uid = _uid;
    final name = displayName.trim();
    if (uid == null || uid != auth.user?.uid) throw StateError('No account');
    if (name.isEmpty || name.length > 100) {
      throw ArgumentError('profile_name_invalid');
    }
    if (photo != null && photo.length > 128 * 1024) {
      throw ArgumentError('profile_photo_large');
    }
    final data = <String, dynamic>{
      'displayName': name,
      'updatedAt': FieldValue.serverTimestamp(),
      if (photo != null) 'photoBase64': base64Encode(photo),
      if (photo != null || removePhoto) 'photoHidden': removePhoto,
      if (removePhoto) 'photoBase64': null,
    };
    // Wait for server acknowledgement; the editor reports queued/offline work
    // honestly rather than claiming that another device already has it.
    await firestore
        .doc('users/$uid/profile/main')
        .set(data, SetOptions(merge: true))
        .timeout(const Duration(seconds: 20));
    if (_uid == uid) {
      try {
        await auth.user?.updateDisplayName(name);
      } catch (_) {
        // The canonical profile has already been saved in Firestore.
      }
    }
  }

  Future<void> close() async {
    _closed = true;
    auth.removeListener(_changed);
    await _subscription?.cancel();
    super.dispose();
  }
}

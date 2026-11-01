import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_app/services/auth/account_profile_service.dart';
import 'package:medicine_app/services/auth/auth_service.dart';

class ProfileUser implements User {
  ProfileUser({
    this.displayName,
    this.photoURL,
    this.isAnonymous = false,
    this.providerData = const [],
  });
  @override
  final String? displayName;
  @override
  final String? photoURL;
  @override
  final bool isAnonymous;
  @override
  final List<UserInfo> providerData;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ProfileProvider implements UserInfo {
  @override
  String get displayName => 'Ada';
  @override
  String get photoURL => 'https://example.com/photo.png';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ProfileAuth extends AuthService {
  ProfileAuth(this.user);
  @override
  final User? user;
}

class UnusedFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  AccountProfileService profile(User user) => AccountProfileService(
    auth: ProfileAuth(user),
    firestore: UnusedFirestore(),
  );

  test(
    'Google profile name and HTTPS photo are available without a custom profile',
    () {
      final service = profile(
        ProfileUser(
          displayName: 'Ada Lovelace',
          photoURL: 'https://example.com/avatar.png',
        ),
      );
      expect(service.displayName, 'Ada Lovelace');
      expect(service.photoUrl, 'https://example.com/avatar.png');
    },
  );

  test('provider metadata fills missing Firebase profile fields', () {
    final service = profile(ProfileUser(providerData: [ProfileProvider()]));
    expect(service.displayName, 'Ada');
    expect(service.photoUrl, 'https://example.com/photo.png');
  });

  test('email accounts without a profile have no invented name or photo', () {
    final service = profile(ProfileUser());
    expect(service.displayName, isNull);
    expect(service.photoUrl, isNull);
    expect(service.photoBytes, isNull);
  });

  test('insecure photo URLs are not loaded', () {
    final service = profile(
      ProfileUser(photoURL: 'http://example.com/photo.png'),
    );
    expect(service.photoUrl, isNull);
  });
}

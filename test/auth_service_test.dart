import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:medicine_app/services/auth/auth_service.dart';

class StubCredential implements UserCredential {
  @override
  AdditionalUserInfo? get additionalUserInfo => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubUser implements User {
  StubUser({required this.isAnonymous});
  @override
  final bool isAnonymous;
  @override
  List<UserInfo> get providerData => [];
  AuthProvider? linkedProvider;
  @override
  Future<UserCredential> linkWithProvider(AuthProvider provider) async {
    linkedProvider = provider;
    return StubCredential();
  }

  AuthCredential? linked;
  bool deleted = false;
  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    linked = credential;
    return StubCredential();
  }

  @override
  Future<void> delete() async {
    deleted = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class AppleProviderInfo implements UserInfo {
  @override
  String get providerId => 'apple.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class AppleDeletionUser extends StubUser {
  AppleDeletionUser({this.cancel = false, this.withCode = false})
    : super(isAnonymous: false);
  final bool cancel;
  final bool withCode;
  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async =>
      FreshToken();
  @override
  List<UserInfo> get providerData => [AppleProviderInfo()];
  @override
  Future<UserCredential> reauthenticateWithProvider(
    AuthProvider provider,
  ) async {
    if (cancel) throw FirebaseAuthException(code: 'web-context-canceled');
    return withCode ? AppleCredential() : StubCredential();
  }
}

class FreshToken implements IdTokenResult {
  @override
  DateTime get authTime => DateTime.now();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class AppleInfo implements AdditionalUserInfo {
  @override
  String get authorizationCode => 'test-single-use-code';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class AppleCredential extends StubCredential {
  @override
  AdditionalUserInfo get additionalUserInfo => AppleInfo();
}

class StubFirebaseAuth implements FirebaseAuth {
  @override
  User? currentUser;
  int guestCalls = 0, createCalls = 0, signOutCalls = 0;
  String? signedInEmail, language, resetEmail;
  AuthProvider? signedProvider;
  String? revokedCode;
  @override
  Future<void> revokeTokenWithAuthorizationCode(String code) async {
    revokedCode = code;
  }

  @override
  Future<UserCredential> signInWithProvider(AuthProvider provider) async {
    signedProvider = provider;
    return StubCredential();
  }

  @override
  Future<UserCredential> signInAnonymously() async {
    guestCalls++;
    currentUser = StubUser(isAnonymous: true);
    return StubCredential();
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    createCalls++;
    signedInEmail = email;
    return StubCredential();
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signedInEmail = email;
    return StubCredential();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    currentUser = null;
  }

  @override
  Future<void> setLanguageCode(String? languageCode) async {
    language = languageCode;
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    resetEmail = email;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'Apple deletion removes cloud data, revokes authorization and deletes account',
    () async {
      final user = AppleDeletionUser(withCode: true);
      final firebase = StubFirebaseAuth()..currentUser = user;
      final auth = AuthService(auth: firebase);
      var cloudDeleted = false;
      var finished = false;
      auth.beforeDeleteAccount = () async {
        expect(user.deleted, false);
        expect(firebase.revokedCode, isNull);
        cloudDeleted = true;
      };
      auth.afterDeleteAccount = () {
        finished = true;
      };
      await auth.deleteAccount();
      expect(cloudDeleted, true);
      expect(firebase.revokedCode, 'test-single-use-code');
      expect(user.deleted, true);
      expect(finished, true);
    },
  );

  for (final cancel in [true, false]) {
    test(
      'Apple deletion preserves records when reauthentication fails: cancel=$cancel',
      () async {
        final user = AppleDeletionUser(cancel: cancel);
        final auth = AuthService(auth: StubFirebaseAuth()..currentUser = user);
        var cloudDeleted = false;
        auth.beforeDeleteAccount = () async {
          cloudDeleted = true;
        };
        await expectLater(
          auth.deleteAccount(),
          throwsA(isA<FirebaseAuthException>()),
        );
        expect(cloudDeleted, false);
        expect(user.deleted, false);
      },
    );
  }

  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test('Apple remains hidden until configured and is only offered on iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AuthService().appleAvailable, false);
    expect(AuthService(appleConfigured: true).appleAvailable, true);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AuthService(appleConfigured: true).appleAvailable, false);
  });
  test('Apple upgrades a guest with provider linking', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final guest = StubUser(isAnonymous: true);
    final firebase = StubFirebaseAuth()..currentUser = guest;
    await AuthService(auth: firebase, appleConfigured: true).signInApple();
    expect(guest.linkedProvider, isA<AppleAuthProvider>());
    expect(firebase.signedProvider, isNull);
  });
  test('Apple sign-in requests a name and email', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final firebase = StubFirebaseAuth();
    await AuthService(auth: firebase, appleConfigured: true).signInApple();
    final provider = firebase.signedProvider as AppleAuthProvider;
    expect(provider.scopes, containsAll(['email', 'name']));
  });

  test('guest continuation reuses the existing session', () async {
    final firebase = StubFirebaseAuth();
    final service = AuthService(auth: firebase);
    await service.continueAsGuest();
    await service.continueAsGuest();
    expect(firebase.guestCalls, 1);
    service.dispose();
  });
  test(
    'registering from guest links credentials instead of replacing UID',
    () async {
      final guest = StubUser(isAnonymous: true);
      final firebase = StubFirebaseAuth()..currentUser = guest;
      final service = AuthService(auth: firebase);
      await service.registerEmail(' user@example.com ', 'test-password');
      expect(guest.linked, isA<EmailAuthCredential>());
      expect((guest.linked! as EmailAuthCredential).email, 'user@example.com');
      expect(firebase.createCalls, 0);
      expect(service.user, same(guest));
      service.dispose();
    },
  );
  test('registration without a guest creates an account', () async {
    final firebase = StubFirebaseAuth();
    final service = AuthService(auth: firebase);
    await service.registerEmail(' user@example.com ', 'test-password');
    expect(firebase.createCalls, 1);
    expect(firebase.signedInEmail, 'user@example.com');
    service.dispose();
  });
  test(
    'password reset uses the selected app language and trimmed email',
    () async {
      final firebase = StubFirebaseAuth();
      final service = AuthService(auth: firebase);
      await service.resetPassword(' user@example.com ', 'tr');
      expect(firebase.language, 'tr');
      expect(firebase.resetEmail, 'user@example.com');
      service.dispose();
    },
  );
  test('sign out clears Firebase session', () async {
    final firebase = StubFirebaseAuth()
      ..currentUser = StubUser(isAnonymous: false);
    final service = AuthService(auth: firebase);
    await service.signOut();
    expect(firebase.signOutCalls, 1);
    expect(service.user, isNull);
    service.dispose();
  });
  test('delete account invokes authenticated user deletion', () async {
    final user = StubUser(isAnonymous: false);
    final service = AuthService(auth: StubFirebaseAuth()..currentUser = user);
    await service.deleteAccount();
    expect(user.deleted, isTrue);
    service.dispose();
  });
  test(
    'invalid credentials do not disclose whether an email is registered',
    () {
      for (final code in [
        'user-not-found',
        'wrong-password',
        'invalid-credential',
      ]) {
        expect(
          authErrorKey(FirebaseAuthException(code: code)),
          'auth_invalid_credentials',
        );
      }
      expect(
        authErrorKey(FirebaseAuthException(code: 'requires-recent-login')),
        'auth_recent_login',
      );
      expect(
        authErrorKey(FirebaseAuthException(code: 'network-request-failed')),
        'auth_network_error',
      );
    },
  );
  test(
    'email validation accepts surrounding whitespace but rejects malformed addresses',
    () {
      expect(isValidAuthEmail(' name@example.com '), isTrue);
      for (final value in [
        '',
        'name',
        'name@',
        'a b@example.com',
        'name@example',
      ]) {
        expect(isValidAuthEmail(value), isFalse, reason: value);
      }
    },
  );
}

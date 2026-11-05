import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shien/firebase_options.dart';

/// Authentication remains separate from reminder storage and profile rendering.
class AuthService extends ChangeNotifier {
  AuthService({
    FirebaseAuth? auth,
    this.appleConfigured = const bool.fromEnvironment('SHIEN_APPLE_SIGN_IN'),
  }) : _auth = auth;
  final bool appleConfigured;
  bool get appleAvailable =>
      appleConfigured && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static final instance = AuthService();
  FirebaseAuth? _auth;
  StreamSubscription<User?>? _subscription;
  Future<void>? _googleInitialization;
  Future<void> Function()? beforeDeleteAccount;
  void Function()? afterDeleteAccount;

  bool get available => _auth != null;
  User? get user => _auth?.currentUser;
  FirebaseAuth get _ready =>
      _auth ?? (throw StateError('Authentication unavailable'));

  Future<void> initialize() async {
    if (_auth != null) return;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _auth = FirebaseAuth.instance;
    _subscription = _auth!.userChanges().listen((_) => notifyListeners());
    notifyListeners();
  }

  Future<void> continueAsGuest() async {
    if (user == null) await _ready.signInAnonymously();
  }

  Future<void> signInEmail(String email, String password) async {
    await _ready.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> registerEmail(String email, String password) async {
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    if (user?.isAnonymous ?? false) {
      await user!.linkWithCredential(credential);
    } else {
      await _ready.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    }
  }

  Future<void> signInGoogle() async {
    final auth = _ready;
    _googleInitialization ??= GoogleSignIn.instance.initialize();
    await _googleInitialization;
    final account = await GoogleSignIn.instance.authenticate();
    final credential = GoogleAuthProvider.credential(
      idToken: account.authentication.idToken,
    );
    if (user?.isAnonymous ?? false) {
      try {
        await user!.linkWithCredential(credential);
        return;
      } on FirebaseAuthException catch (error) {
        if (error.code != 'credential-already-in-use') rethrow;
        // The selected Google account already exists. Device data stays local.
      }
    }
    await auth.signInWithCredential(credential);
  }

  AppleAuthProvider _appleProvider() => AppleAuthProvider()
    ..addScope('email')
    ..addScope('name');

  Future<void> signInApple() async {
    if (!appleAvailable) throw StateError('Apple sign-in is not configured');
    final auth = _ready;
    if (user?.isAnonymous ?? false) {
      try {
        await user!.linkWithProvider(_appleProvider());
        return;
      } on FirebaseAuthException catch (error) {
        if (error.code != 'credential-already-in-use') rethrow;
      }
    }
    await auth.signInWithProvider(_appleProvider());
  }

  Future<void> resetPassword(String email, String language) async {
    await _ready.setLanguageCode(language);
    await _ready.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendVerification(String language) async {
    await _ready.setLanguageCode(language);
    await user?.sendEmailVerification();
  }

  Future<void> refreshUser() async => user?.reload();

  Future<void> signOut() async {
    await _ready.signOut();
    if (_googleInitialization != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Firebase is already signed out; a Google SDK failure cannot undo it.
      }
    }
  }

  Future<void> deleteAccount() async {
    final current = user;
    if (current == null) return;
    String? appleCode;
    if (!current.isAnonymous &&
        current.providerData.any((p) => p.providerId == 'apple.com')) {
      // Request a fresh, single-use authorization code for Apple's revocation.
      // Cancellation must leave the account and its cloud records intact.
      final result = await current.reauthenticateWithProvider(_appleProvider());
      appleCode = result.additionalUserInfo?.authorizationCode;
      if (appleCode == null || appleCode.isEmpty) {
        throw FirebaseAuthException(code: 'requires-recent-login');
      }
    }
    if (!current.isAnonymous && beforeDeleteAccount != null) {
      final token = await current.getIdTokenResult();
      final signedAt = token.authTime;
      if (signedAt == null ||
          DateTime.now().difference(signedAt) > const Duration(minutes: 4)) {
        throw FirebaseAuthException(code: 'requires-recent-login');
      }
    }
    try {
      await beforeDeleteAccount?.call();
      if (appleCode != null) {
        await _ready.revokeTokenWithAuthorizationCode(appleCode);
      }
      await current.delete();
    } finally {
      afterDeleteAccount?.call();
    }
    if (_googleInitialization != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Return catalog keys, never raw provider messages or account identifiers.
String authErrorKey(Object error) {
  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => 'auth_cancelled',
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'auth_unavailable',
      _ => 'auth_failed',
    };
  }
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'canceled' ||
      'cancelled-popup-request' ||
      'web-context-canceled' ||
      'popup-closed-by-user' => 'auth_cancelled',
      'invalid-email' => 'auth_invalid_email',
      'weak-password' => 'auth_weak_password',
      'email-already-in-use' ||
      'credential-already-in-use' => 'auth_email_in_use',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'auth_invalid_credentials',
      'network-request-failed' => 'auth_network_error',
      'too-many-requests' => 'auth_too_many_requests',
      'requires-recent-login' => 'auth_recent_login',
      'operation-not-allowed' ||
      'configuration-not-found' => 'auth_unavailable',
      'user-disabled' => 'auth_disabled',
      'account-exists-with-different-credential' => 'auth_other_provider',
      _ => 'auth_failed',
    };
  }
  return error is StateError ? 'auth_unavailable' : 'auth_failed';
}

bool isValidAuthEmail(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());

import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shien/l10n/codegen_loader.g.dart';
import 'package:shien/pages/reminder_email_auth_page.dart';
import 'package:shien/services/auth/auth_service.dart';
import 'package:shien/theme/reminder_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UiAuth extends AuthService {
  int calls = 0;
  String? email, language;
  Completer<void>? pending;
  @override
  bool get available => true;
  @override
  Future<void> signInEmail(String email, String password) async {
    calls++;
    this.email = email;
    if (pending != null) await pending!.future;
    throw FirebaseAuthException(code: 'invalid-credential');
  }

  @override
  Future<void> registerEmail(String email, String password) async {
    calls++;
  }

  @override
  Future<void> resetPassword(String email, String language) async {
    this.email = email;
    this.language = language;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  Future<void> mount(
    WidgetTester tester,
    UiAuth auth, {
    String language = 'tr',
  }) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('tr'), Locale('en')],
        startLocale: Locale(language),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: const CodegenLoader(),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: ReminderTheme.light,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: ReminderEmailAuthPage(auth: auth),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('invalid email is blocked before any request', (tester) async {
    final auth = UiAuth();
    await mount(tester, auth);
    await tester.enterText(find.byType(TextFormField).at(0), 'invalid');
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş yap'));
    await tester.pumpAndSettle();
    expect(find.text('Geçerli bir e-posta adresi yaz.'), findsOneWidget);
    expect(auth.calls, 0);
  });
  testWidgets('sign-in prevents repeated submission and shows a safe error', (
    tester,
  ) async {
    final auth = UiAuth()..pending = Completer<void>();
    await mount(tester, auth);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş yap'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(auth.calls, 1);
    auth.pending!.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('E-posta adresini ve şifreni kontrol et.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
  testWidgets(
    'registration validates confirmation and retains email when switching mode',
    (tester) async {
      final auth = UiAuth();
      await mount(tester, auth);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.tap(find.text('Hesabın yok mu? Hesap oluştur'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller!
            .text,
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'different-password',
      );
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
      expect(auth.calls, 0);
    },
  );
  testWidgets(
    'password reset follows English locale without claiming an account exists',
    (tester) async {
      final auth = UiAuth();
      await mount(tester, auth, language: 'en');
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.tap(find.text('Forgot password'));
      await tester.pumpAndSettle();
      expect(auth.language, 'en');
      expect(find.textContaining('If an account exists'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shien/services/auth/account_profile_service.dart';
import 'package:shien/services/sync/cloud_reminder_store.dart';
import 'package:shien/services/sync/cloud_reminder_sync.dart';
import 'package:shien/services/reminder_actions.dart';
import 'package:shien/services/auth/auth_service.dart';
import 'package:shien/l10n/app_localization.dart';
import 'package:shien/services/reminder_widget_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shien/l10n/codegen_loader.g.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shien/blocs/reminder/reminder_cubit.dart';
import 'package:shien/models/medicine.dart';
import 'package:shien/models/medicine_log.dart';
import 'package:shien/pages/reminder_home_page.dart';
import 'package:shien/services/notifications/reminder_notification_service.dart';
import 'package:shien/services/reminder_storage.dart';
import 'package:shien/theme/reminder_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Manrope', 'PatrickHand']) {
      final license = await rootBundle.loadString(
        'assets/fonts/OFL-$family.txt',
      );
      yield LicenseEntryWithLineBreaks([family], license);
    }
  });
  await _start();
}

Future<void> _start() async {
  try {
    await EasyLocalization.ensureInitialized();
    await initializeDateFormatting();
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(MedicineAdapter());
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RepeatCycleAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(MedicineLogAdapter());
    }
    final box = await Hive.openBox<dynamic>('reminders_v1');
    final storage = ReminderStorage(box);
    final medicines = await Hive.openBox<Medicine>('medicines');
    final logs = await Hive.openBox<MedicineLog>('medicineLogs');
    await storage.migrateLegacy(medicines, logs);
    final auth = AuthService.instance;
    try {
      await auth.initialize();
    } catch (error) {
      debugPrint('Authentication initialization failed: ${error.runtimeType}');
    }
    final account = auth.user;
    storage.accountId = account != null && !account.isAnonymous
        ? account.uid
        : null;
    await ReminderActionQueue.setActiveScope(storage.scope);
    final notifications = ReminderNotificationService()
      ..accountScope = storage.scope;
    try {
      await notifications.initialize();
    } catch (error) {
      debugPrint('Notification initialization failed: ${error.runtimeType}');
    }
    final widgets = ReminderWidgetService();
    try {
      await widgets.initialize();
    } catch (e) {
      debugPrint('Widget initialization failed: ${e.runtimeType}');
    }
    final cubit = ReminderCubit(
      storage: storage,
      notifications: notifications,
      widgets: widgets,
    );
    if (auth.available) {
      final firestore = FirebaseFirestore.instance;
      final profiles = AccountProfileService(auth: auth, firestore: firestore);
      AccountProfileService.current = profiles;
      profiles.start();
      final sync = CloudReminderSync(
        auth: auth,
        cubit: cubit,
        store: FirestoreReminderStore(firestore),
      );
      CloudReminderSync.current = sync;
      auth.beforeDeleteAccount = sync.deleteAccountData;
      auth.afterDeleteAccount = sync.finishAccountDeletion;
      await sync.start();
    }
    runApp(BlocProvider(create: (_) => cubit, child: const ReminderApp()));
    await cubit.consumePendingActions();
    await cubit.refresh();
  } catch (error) {
    debugPrint('Local startup failed: ${error.runtimeType}');
    runApp(_localizationRoot(const _StartupErrorApp()));
  }
}

class ReminderApp extends StatelessWidget {
  const ReminderApp({super.key});
  @override
  Widget build(BuildContext context) =>
      _localizationRoot(const _LocalizedReminderApp());
}

Widget _localizationRoot(Widget child) => EasyLocalization(
  supportedLocales: const [Locale('tr'), Locale('en')],
  fallbackLocale: const Locale('tr'),
  startLocale: const Locale('tr'),
  path: 'assets/translations',
  assetLoader: const CodegenLoader(),
  useOnlyLangCode: true,
  child: child,
);

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ReminderTheme.light,
    locale: context.locale,
    supportedLocales: context.supportedLocales,
    localizationsDelegates: context.localizationDelegates,
    home: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_off_outlined, size: 42),
                  const SizedBox(height: 20),
                  Text(
                    context.tr('error_startup'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('error_startup_detail'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _start,
                    child: Text(context.tr('retry')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _LocalizedReminderApp extends StatelessWidget {
  const _LocalizedReminderApp();
  @override
  Widget build(BuildContext context) {
    appLocale = context.locale.languageCode;
    Intl.defaultLocale = appLocale;
    return BlocBuilder<ReminderCubit, ReminderState>(
      buildWhen: (previous, next) =>
          previous.themeMode != next.themeMode || previous.scope != next.scope,
      builder: (context, state) => MaterialApp(
        key: ValueKey(state.scope),
        onGenerateTitle: (context) => context.tr('app_name'),
        debugShowCheckedModeBanner: false,
        theme: ReminderTheme.light,
        darkTheme: ReminderTheme.dark,
        themeMode: state.themeMode,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
        home: const ReminderHomePage(),
      ),
    );
  }
}

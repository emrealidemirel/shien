import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:medicine_app/blocs/reminder/reminder_cubit.dart';
import 'package:medicine_app/main.dart';
import 'package:medicine_app/pages/reminder_form_page.dart';
import 'package:medicine_app/components/reminder_components.dart';
import 'package:medicine_app/theme/reminder_theme.dart';
import 'package:medicine_app/services/reminder_collection.dart';
import 'package:medicine_app/models/reminder.dart';
import 'package:medicine_app/services/reminder_storage.dart';
import 'reminder_test.dart' show FakeNotifications;

void main() {
  late Directory directory;
  late ReminderCubit cubit;
  final boundaryKey = GlobalKey();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'locale': 'tr'});
    await EasyLocalization.ensureInitialized();
    await initializeDateFormatting();
    final loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await loader.load();
    final headings = FontLoader('PatrickHand')
      ..addFont(rootBundle.load('assets/fonts/PatrickHand-Regular.ttf'));
    await headings.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({'locale': 'tr'});
    await EasyLocalization.ensureInitialized();
    directory = await Directory.systemTemp.createTemp('reminder_ui_');
    Hive.init(directory.path);
    final box = await Hive.openBox<dynamic>('reminders_ui');
    cubit = ReminderCubit(
      storage: ReminderStorage(box),
      notifications: FakeNotifications(),
    );
    final now = DateTime.now();
    final samples = [
      ('Güne bir bardak suyla başla', ReminderCategory.health, 9, 0),
      ('Tasarım dosyasını gönder', ReminderCategory.work, 14, 30),
      ('Yeni bölüm başlıyor', ReminderCategory.entertainment, 21, 0),
    ];
    for (var index = 0; index < samples.length; index++) {
      final sample = samples[index];
      final at = DateTime(now.year, now.month, now.day, sample.$3, sample.$4);
      await cubit.save(
        Reminder(
          id: 'sample-$index',
          title: sample.$1,
          anchorAt: at,
          dueAt: at,
          createdAt: now,
          category: sample.$2,
          repeat: index == 0 ? ReminderRepeat.daily : ReminderRepeat.once,
          isPriority: index == 1,
          tags: index == 1 ? ['iş'] : const [],
        ),
      );
    }
  });
  tearDown(() async {
    await cubit.close();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: BlocProvider.value(value: cubit, child: const ReminderApp()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(
    String name,
    WidgetTester tester, {
    double pixelRatio = 2,
  }) async {
    // Asset decoding uses real async work; settle it before capturing a frame.
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/app_icon/brand_mark.png'),
        tester.element(find.byType(MaterialApp).first),
      ),
    );
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    tester.binding.rootElement?.visitChildren(rebuild);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('build/previews/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    debugDisableShadows = previousShadows;
  }

  if (const bool.fromEnvironment('SHIEN_STORE_PREVIEWS')) {
    for (final platform in ['ios', 'android', 'ipad']) {
      for (final language in ['tr', 'en']) {
        testWidgets('store previews $platform $language', (tester) async {
          await tester.runAsync(() async {
            if (language == 'en') {
              final titles = [
                'Start the day with water',
                'Send the design file',
                'Watch the new episode',
              ];
              for (var i = 0; i < titles.length; i++) {
                await cubit.save(
                  Reminder.fromMap({
                    ...cubit.state.reminders[i].toMap(),
                    'title': titles[i],
                    'tags': i == 1 ? ['work'] : [],
                  }),
                );
              }
            }
          });
          await mount(
            tester,
            size: switch (platform) {
              'ipad' => const Size(1032, 1376),
              'ios' => const Size(440, 956),
              _ => const Size(360, 640),
            },
          );
          await tester
              .element(find.byType(Scaffold).first)
              .setLocale(Locale(language));
          await tester.pumpAndSettle();
          await capture(
            'store/$platform-$language-today',
            tester,
            pixelRatio: platform == 'ipad' ? 2 : 3,
          );
          await tester.tap(find.text('Plan').last);
          await tester.pumpAndSettle();
          await capture(
            'store/$platform-$language-plan',
            tester,
            pixelRatio: platform == 'ipad' ? 2 : 3,
          );
          await tester.tap(
            find.text(language == 'tr' ? 'Listeler' : 'Lists').last,
          );
          await tester.pumpAndSettle();
          await capture(
            'store/$platform-$language-lists',
            tester,
            pixelRatio: platform == 'ipad' ? 2 : 3,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  Future<void> saveEditor(WidgetTester tester) async {
    await tester.runAsync(() async {
      final dynamic save = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Hatırlatıcıyı kaydet'),
          )
          .onPressed!;
      await save();
    });
    // The real parent closes the editor on save. Here it remains mounted to
    // inspect persistence, so its saving indicator keeps animating.
    await tester.pump();
  }

  for (final completed in [false, true]) {
    testWidgets(
      'metadata editing preserves occurrence and completion=$completed',
      (tester) async {
        final original = cubit.state.reminders.first.copyWith(
          isCompleted: completed,
          snoozedUntil: DateTime.now().add(const Duration(hours: 2)),
        );
        await tester.runAsync(() => cubit.save(original));
        var saved = false;
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: MaterialApp(
              theme: ReminderTheme.light,
              home: ReminderFormPage(
                reminder: original,
                onSaved: () => saved = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, 'Yeni başlık');
        await saveEditor(tester);
        final edited = cubit.state.reminders.firstWhere(
          (r) => r.id == original.id,
        );
        expect(saved, isTrue);
        expect(edited.title, 'Yeni başlık');
        expect(edited.anchorAt, original.anchorAt);
        expect(edited.dueAt, original.dueAt);
        expect(edited.snoozedUntil, original.snoozedUntil);
        expect(edited.isCompleted, completed);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('copying a completed reminder creates a separate active record', (
    tester,
  ) async {
    final original = cubit.state.reminders.first.copyWith(isCompleted: true);
    await tester.runAsync(() => cubit.save(original));
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          theme: ReminderTheme.light,
          home: ReminderFormPage(copyFrom: original, onSaved: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveEditor(tester);
    expect(cubit.state.reminders, hasLength(4));
    final copy = cubit.state.reminders.last;
    expect(copy.id, isNot(original.id));
    expect(copy.title, original.title);
    expect(copy.category, original.category);
    expect(copy.isActive, isTrue);
    expect(copy.dueAt.isAfter(DateTime.now()), isTrue);
    expect(cubit.state.reminders.first.isCompleted, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('collection sorting, Turkish search and clearing remain usable', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('Listeler').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tüm hatırlatıcılar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sıralama'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(
        CheckedPopupMenuItem<ReminderSort>,
        'Önem sırasına göre',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ReminderCard>(find.byType(ReminderCard).first)
          .reminder
          .isPriority,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), 'IS tasarim');
    await tester.pumpAndSettle();
    expect(find.byType(ReminderCard), findsOneWidget);
    await tester.tap(find.byTooltip('Aramayı temizle'));
    await tester.pumpAndSettle();
    expect(find.byType(ReminderCard), findsNWidgets(3));
    await tester.runAsync(() => cubit.setTheme(ThemeMode.dark));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await capture('collection-dark', tester);
    await tester.runAsync(() => cubit.setTheme(ThemeMode.light));
    await tester.pumpAndSettle();
    await capture('collection-light', tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('plan previews future occurrences and filters by day', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('Plan').last);
    await tester.pumpAndSettle();
    await capture('plan-light', tester);
    await tester.runAsync(() => cubit.setTheme(ThemeMode.dark));
    await tester.pumpAndSettle();
    await capture('plan-dark', tester);
    await tester.runAsync(() => cubit.setTheme(ThemeMode.light));
    await tester.pumpAndSettle();
    final future = find
        .byType(ReminderCard)
        .evaluate()
        .where((element) => !(element.widget as ReminderCard).allowComplete)
        .first;
    final card = future.widget as ReminderCard;
    await tester.ensureVisible(find.byWidget(card));
    await tester.tap(find.byWidget(card));
    await tester.pumpAndSettle();
    expect(find.text('Sıradaki hatırlatmayı aç'), findsOneWidget);
    expect(cubit.state.completions, isEmpty);
    await tester.tap(find.text('Sıradaki hatırlatmayı aç'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Düzenle'), findsOneWidget);
    Navigator.of(tester.element(find.byTooltip('Düzenle'))).pop();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 1600));
    await tester.pumpAndSettle();
    final dayChip = find.byType(ChoiceChip).at(4);
    await tester.ensureVisible(dayChip);
    await tester.tap(dayChip);
    await tester.pumpAndSettle();
    final dates = tester
        .widgetList<ReminderCard>(find.byType(ReminderCard))
        .map((r) => r.occurrenceAt)
        .toSet();
    expect(dates.length, lessThanOrEqualTo(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'upcoming and plan require confirmation and history is directly accessible',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byTooltip('Yaklaşan hatırlatmalar'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => tester.tap(find.byTooltip('Tamamla').hitTestable().first),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tamamlandı olarak işaretlensin mi?'), findsOneWidget);
      expect(cubit.state.completions, isEmpty);
      await capture('complete-confirmation', tester);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(cubit.state.completions, isEmpty);
      Navigator.of(tester.element(find.text('Sıradaki hatırlatmalar'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Tamamla').first);
      await tester.runAsync(
        () => tester.tap(find.byTooltip('Tamamla').hitTestable().first),
      );
      await tester.pumpAndSettle();
      expect(cubit.state.completions, isEmpty);
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Tamamla'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(cubit.state.completions, hasLength(1));
      await tester.tap(find.text('Bitenler').last);
      await tester.pumpAndSettle();
      expect(find.text('Tamamlananlar'), findsOneWidget);
      expect(find.text(cubit.state.completions.single.title), findsOneWidget);
      await capture('history-light', tester);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('digital time picker accepts a typed time before analog mode', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byTooltip('Yeni hatırlatıcı oluştur'));
    await tester.pumpAndSettle();
    await capture('editor-light', tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('reminder-time-field')),
    );
    await tester.tap(find.byKey(const ValueKey('reminder-time-field')));
    await tester.pumpAndSettle();
    final dialog = find.byType(TimePickerDialog);
    expect(
      tester.widget<TimePickerDialog>(dialog).initialEntryMode,
      TimePickerEntryMode.input,
    );
    final fields = find.descendant(
      of: dialog,
      matching: find.byType(TextField),
    );
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.first, '21');
    await tester.enterText(fields.last, '15');
    await capture('digital-time-picker', tester);
    await tester.tap(find.text('Seç'));
    await tester.pumpAndSettle();
    expect(find.text('21:15'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'offline profile keeps local reminders usable when Firebase is unavailable',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byTooltip('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Misafir hesabı'), findsOneWidget);
      for (final title in ['Google ile devam et', 'E-posta ile devam et']) {
        expect(
          tester.widget<ListTile>(find.widgetWithText(ListTile, title)).enabled,
          isFalse,
        );
      }
      expect(find.byType(TextField), findsNothing);
      await capture('profile-light', tester);
      await tester.tap(find.text('Misafir olarak devam et'));
      await tester.pumpAndSettle();
      expect(find.text('Bugünün planı'), findsOneWidget);
      expect(cubit.state.reminders, hasLength(3));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('form settings are grouped and repeat interval resets visibly', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byTooltip('Yeni hatırlatıcı oluştur'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tekrar'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ReminderFormPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Tekrar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Her gün'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Her gün'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 günde bir').last);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.widgetWithText(ChoiceChip, 'Her ay')),
      alignment: .3,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Her ay'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .initialValue,
      1,
    );
    expect(find.text('Her ay'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await capture('repeat-settings-light', tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('today, search, complete, history, theme and editor work', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('Bugünün planı'), findsOneWidget);
    await capture('today-light', tester);
    await tester.tap(find.text('Listeler').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tüm hatırlatıcılar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bölüm');
    await tester.pumpAndSettle();
    expect(find.text('Yeni bölüm başlıyor'), findsOneWidget);
    expect(find.text('Tasarım dosyasını gönder'), findsNothing);
    await tester.runAsync(() => tester.tap(find.byTooltip('Tamamla')));
    await tester.pumpAndSettle();
    expect(cubit.state.completions, isEmpty);
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Tamamla'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(cubit.state.completions, hasLength(1));
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Tamamlananlar').last);
    await tester.pumpAndSettle();
    expect(find.text('Yeni bölüm başlıyor'), findsOneWidget);
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ayarlar'));

    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Koyu'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(cubit.state.themeMode, ThemeMode.dark);
    await capture('settings-dark', tester);
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bugün'));
    await tester.pumpAndSettle();
    await capture('today-dark', tester);
    await tester.tap(find.byTooltip('Yeni hatırlatıcı oluştur'));
    await tester.pumpAndSettle();
    expect(find.text('Ne hatırlatalım?'), findsOneWidget);
    await capture('editor-dark', tester);
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).last),
    ).removeCurrentSnackBar();
    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Hatırlatıcıyı kaydet'),
        )
        .onPressed!
        .call();
    await tester.pump();
    expect(find.text('Hatırlatıcına bir başlık ekle.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Test hatırlatıcısı',
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('editor keeps navigation and draft; header actions open panels', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Misafir hesabı'), findsOneWidget);
    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Yaklaşan hatırlatmalar'));
    await tester.pumpAndSettle();
    expect(find.text('Sıradaki hatırlatmalar'), findsOneWidget);
    await tester.tapAt(const Offset(10, 80));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bugün'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Yeni hatırlatıcı oluştur'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Taslağım');
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Yeni hatırlatıcı oluştur'));
    await tester.pumpAndSettle();
    expect(find.text('Taslağım'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Hatırlatıcıyı kaydet'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(
      cubit.state.reminders.where((r) => r.title == 'Taslağım'),
      hasLength(1),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('priority and tag smart lists open their matching reminders', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('Listeler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Önemliler'));
    await tester.pumpAndSettle();
    expect(find.text('Tasarım dosyasını gönder'), findsOneWidget);
    expect(find.text('Yeni bölüm başlıyor'), findsNothing);
    await tester.tap(find.text('Listeler').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ActionChip, 'iş'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(ActionChip, 'iş'));
    await tester.pumpAndSettle();
    expect(find.text('#iş'), findsNWidgets(2));
    expect(find.text('Tasarım dosyasını gönder'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('expanded settings and profile stay usable with large text', (
    tester,
  ) async {
    await mount(tester, size: const Size(320, 740), scale: 1.5);
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture('profile-small-large-text', tester);
    Navigator.of(tester.element(find.text('Misafir hesabı'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Yeni hatırlatıcı oluştur'));
    await tester.pumpAndSettle();
    final scroller = find
        .descendant(
          of: find.byType(ReminderFormPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Tekrar'),
      200,
      scrollable: scroller,
    );
    await tester.tap(find.text('Tekrar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture('repeat-small-large-text', tester);
    await tester.scrollUntilVisible(
      find.text('Bildirim'),
      200,
      scrollable: scroller,
    );
    await tester.tap(find.text('Bildirim'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Bildirim sesi'),
      200,
      scrollable: scroller,
    );
    expect(tester.takeException(), isNull);
    await capture('sound-small-large-text', tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('editor stays usable with the keyboard open', (tester) async {
    await mount(tester, size: const Size(390, 844));
    await tester.tap(find.byTooltip('Yeni hatırlatıcı oluştur'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextFormField).first);
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final save = tester.getRect(find.text('Hatırlatıcıyı kaydet'));
    expect(save.bottom, lessThan(844 - 336));
    await capture('editor-keyboard', tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'settings is separate from tabs and language persists without changing data',
    (tester) async {
      await mount(tester);
      final before = cubit.state.reminders.map((r) => r.toMap()).toList();
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Yeni hatırlatıcı oluştur'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Özel taslağım');
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ayarlar'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      await tester.runAsync(() async {
        await tester.tap(find.text('English'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Ayarlar'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'en');
      await capture('settings-english', tester);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(find.text('Next 7 days'), findsOneWidget);
      await tester.tap(find.byTooltip('Add reminder'));
      await tester.pumpAndSettle();
      expect(find.text('Özel taslağım'), findsOneWidget);
      expect(find.text('New reminder'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reminder-date-field')));
      await tester.pumpAndSettle();
      expect(find.text('Choose date'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reminder-time-field')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Notification time'), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await capture('editor-english', tester);
      expect(cubit.state.reminders.map((r) => r.toMap()).toList(), before);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => EasyLocalization.ensureInitialized());
      await mount(tester, size: const Size(320, 740), scale: 1.5);
      expect(find.text('Today'), findsWidgets);
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(find.text('Settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'English'))
            .selected,
        isTrue,
      );
      await capture('settings-english-small', tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('Türkçe'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Ayarlar'), findsOneWidget);
      expect(find.text('Dil'), findsOneWidget);
      expect(prefs.getString('locale'), 'tr');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => EasyLocalization.ensureInitialized());
    },
  );

  testWidgets(
    'settings remains usable when cloud records exceed notification capacity',
    (tester) async {
      final at = DateTime.now().add(const Duration(days: 1));
      await tester.runAsync(() async {
        await cubit.switchAccount('capacity-test');
        await cubit.applyCloudSnapshot('capacity-test', 'reminders', {
          for (var i = 0; i < 61; i++)
            'cloud-$i': {
              'mutationId': 'remote-$i',
              'data': Reminder(
                id: 'cloud-$i',
                title: 'Reminder $i',
                anchorAt: at,
                dueAt: at,
                createdAt: at,
              ).toMap(),
            },
        }, fromCache: false);
      });
      await mount(tester);
      await tester.tap(find.byTooltip('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ayarlar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Dil'), findsOneWidget);
      expect(find.text('Türkçe'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('tablet landscape supports navigation and the reminder editor', (
    tester,
  ) async {
    await mount(tester, size: const Size(1376, 1032));
    await tester.tap(find.text('Plan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Yeni hatırlatıcı oluştur'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Tablet hatırlatıcısı',
    );
    await capture('tablet-landscape-editor', tester);
    expect(find.text('Hatırlatıcıyı kaydet'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('small phone and large text stay usable', (tester) async {
    await mount(tester, size: const Size(320, 740), scale: 1.5);
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Yeni hatırlatıcı oluştur'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await capture('small-phone-large-text', tester);
    await tester.tap(find.text('Plan').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture('plan-small-large-text', tester);
    await tester.tap(find.text('Listeler').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tüm hatırlatıcılar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture('collection-small-large-text', tester);
    await tester.tap(find.byTooltip('Yeni hatırlatıcı oluştur'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

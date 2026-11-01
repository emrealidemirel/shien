import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_app/l10n/codegen_loader.g.dart';
import 'package:medicine_app/services/reminder_quick_input.dart';

void main() {
  test(
    'catalogs have matching keys and placeholders and match bundled loader',
    () {
      Map<String, dynamic> read(String language) =>
          jsonDecode(
                File('assets/translations/$language.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final tr = read('tr'), en = read('en');
      expect(en.keys.toSet(), tr.keys.toSet());
      Set<String> args(String value) => RegExp(
        r'\{(\w+)\}',
      ).allMatches(value).map((m) => m.group(1)!).toSet();
      for (final key in tr.keys) {
        expect((tr[key] as String).trim(), isNotEmpty, reason: key);
        expect((en[key] as String).trim(), isNotEmpty, reason: key);
        expect(args(en[key] as String), args(tr[key] as String), reason: key);
      }
      for (final file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where(
                (f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'),
              )) {
        for (final match in RegExp(
          r"\bt\('([^']+)'",
        ).allMatches(file.readAsStringSync())) {
          expect(
            tr.containsKey(match.group(1)),
            isTrue,
            reason: '${file.path}: ${match.group(1)}',
          );
        }
      }
      expect(CodegenLoader.mapLocales['tr'], tr);
      expect(CodegenLoader.mapLocales['en'], en);
    },
  );

  test(
    'English quick input recognizes displayed examples and preserves content',
    () {
      final now = DateTime(2026, 10, 27, 12);
      final tomorrow = ReminderQuickInput.parse(
        'Pay the bill tomorrow at 09:00',
        now,
      )!;
      expect(tomorrow.title, 'Pay the bill');
      expect(tomorrow.at, DateTime(2026, 10, 28, 9));
      final relative = ReminderQuickInput.parse(
        'Call Alex in 30 minutes',
        now,
      )!;
      expect(relative.title, 'Call Alex');
      expect(relative.at, now.add(const Duration(minutes: 30)));
      expect(ReminderQuickInput.parse('Call Alex today at 09:00', now), isNull);
      expect(ReminderQuickInput.parse('Format 18:00', now)!.title, 'Format');
    },
  );
}

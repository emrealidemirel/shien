import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:medicine_app/l10n/codegen_loader.g.dart';

export 'package:easy_localization/easy_localization.dart'
    show BuildContextEasyLocalizationExtension;

String appLocale = 'tr';

/// Background isolates receive the language with the notification or widget.
/// They use the same generated catalogs without initializing a widget tree.
void useBackgroundLocale(String? language) {
  if (!trExists('app_name') && (language == 'tr' || language == 'en')) {
    appLocale = language!;
  }
}

/// Models and background work have no BuildContext. Before the UI loads its
/// translations, resolve text from the bundled catalog for the chosen language.
String t(String key, {Map<String, String>? args}) {
  if (trExists(key)) {
    return tr(key, namedArgs: args);
  }
  var text = CodegenLoader.mapLocales[appLocale]![key] as String? ?? key;
  for (final entry in (args ?? <String, String>{}).entries) {
    text = text.replaceAll('{${entry.key}}', entry.value);
  }
  return text;
}

/// Register locale dependencies even when a widget uses translated model labels.
T localized<T>(BuildContext context, T Function() build) {
  Localizations.localeOf(context);
  return build();
}

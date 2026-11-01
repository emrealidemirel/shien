import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReminderTheme {
  static const accent = Color(0xFF365C9C);
  static const paper = Color(0xFFF6F7F9);
  static const ink = Color(0xFF202735);
  static const surfaceRadius = 16.0;
  static const controlRadius = 14.0;
  static const compactRadius = 10.0;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      error: dark ? const Color(0xFFF0AAA0) : const Color(0xFFB04439),
      onError: dark ? const Color(0xFF601B14) : Colors.white,
      brightness: brightness,
      primary: dark ? const Color(0xFFACC6F4) : accent,
      onPrimary: dark ? const Color(0xFF172E50) : Colors.white,
      primaryContainer: dark
          ? const Color(0xFF293B56)
          : const Color(0xFFE7EDF7),
      onPrimaryContainer: dark
          ? const Color(0xFFDBE7FC)
          : const Color(0xFF294B7C),
      secondaryContainer: dark
          ? const Color(0xFF293B56)
          : const Color(0xFFE7EDF7),
      onSecondaryContainer: dark
          ? const Color(0xFFDBE7FC)
          : const Color(0xFF294B7C),
      surface: dark ? const Color(0xFF202630) : Colors.white,
      surfaceDim: dark ? const Color(0xFF151A22) : const Color(0xFFDCE1E9),
      surfaceBright: dark ? const Color(0xFF353D49) : const Color(0xFFFAFBFD),
      surfaceContainerLowest: dark ? const Color(0xFF10151C) : Colors.white,
      surfaceContainerLow: dark
          ? const Color(0xFF1B212B)
          : const Color(0xFFF3F5F9),
      surfaceContainer: dark
          ? const Color(0xFF252D39)
          : const Color(0xFFEDF0F5),
      surfaceContainerHigh: dark
          ? const Color(0xFF2D3643)
          : const Color(0xFFE6EBF2),
      surfaceContainerHighest: dark
          ? const Color(0xFF384352)
          : const Color(0xFFDFE5EE),
      inverseSurface: dark ? const Color(0xFFEDF0F5) : const Color(0xFF293341),
      onInverseSurface: dark
          ? const Color(0xFF293341)
          : const Color(0xFFF3F5F9),
      onSurface: dark ? const Color(0xFFEAF0F8) : ink,
      onSurfaceVariant: dark
          ? const Color(0xFFBAC5D4)
          : const Color(0xFF626F80),
      outlineVariant: dark ? const Color(0xFF3A4555) : const Color(0xFFE0E5ED),
      outline: dark ? const Color(0xFF8C9CB2) : const Color(0xFF76859A),
      secondary: dark ? const Color(0xFFB8C8DD) : const Color(0xFF536881),
      onSecondary: dark ? const Color(0xFF26384D) : Colors.white,
      tertiary: dark ? const Color(0xFFD8C48E) : const Color(0xFF786638),
      onTertiary: dark ? const Color(0xFF382C0E) : Colors.white,
      tertiaryContainer: dark
          ? const Color(0xFF443E2C)
          : const Color(0xFFF0EAD9),
      onTertiaryContainer: dark
          ? const Color(0xFFEDE1BF)
          : const Color(0xFF514625),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: dark ? const Color(0xFF151A22) : paper,
    );
    final text = base.textTheme
        .apply(fontFamily: 'Manrope')
        .copyWith(
          headlineLarge: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: 0,
            color: scheme.onSurface,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: 0,
            color: scheme.onSurface,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.2,
            letterSpacing: 0,
            color: scheme.onSurface,
          ),
          titleMedium: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: scheme.onSurface,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 15,
            height: 1.6,
            color: scheme.onSurface,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            height: 1.55,
            color: scheme.onSurface,
          ),
          bodySmall: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            height: 1.5,
            color: scheme.onSurfaceVariant,
          ),
          labelLarge: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        );
    return base.copyWith(
      textTheme: text,
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        iconColor: scheme.onSurfaceVariant,
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        toolbarHeight: 64,
        titleTextStyle: text.headlineMedium,
        backgroundColor: base.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 54),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.all(18),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compactRadius),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.onPrimaryContainer,
        labelStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: base.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
      ),
    );
  }
}

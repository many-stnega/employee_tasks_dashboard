import 'package:material_ui/material_ui.dart';

abstract final class AppTheme {
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightSecondary = Color(0xFF64748B);
  static const Color lightPrimary = Color(0xFF3B82F6);
  static const Color lightValue = Color(0xFF0F766E);
  static const Color lightTint = Color(0xFFEFF6FF);

  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkText = Color(0xFFF1F5F9);
  static const Color darkSecondary = Color(0xFFB0BDD0);
  static const Color darkPrimary = Color(0xFF60A5FA);
  static const Color darkValue = Color(0xFF5EEAD4);
  static const Color darkTint = Color(0xFF1E3A5F);

  static ThemeData forMode(bool dark) {
    final scheme = ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: dark ? darkPrimary : lightPrimary,
      onPrimary: Colors.white,
      primaryContainer: dark ? darkTint : lightTint,
      onPrimaryContainer: dark ? darkText : lightText,
      secondary: dark ? darkValue : lightValue,
      onSecondary: dark ? darkBg : Colors.white,
      surface: dark ? darkSurface : lightSurface,
      onSurface: dark ? darkText : lightText,
      onSurfaceVariant: dark ? darkSecondary : lightSecondary,
      outline: dark ? darkBorder : lightBorder,
      error: const Color(0xFFDC2626),
      onError: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? darkBg : lightBg,
      cardColor: scheme.surface,
      dividerColor: scheme.outline,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.primary,
        ),
      ),
    );
  }
}

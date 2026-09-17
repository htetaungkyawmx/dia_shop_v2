import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette and Material 3 themes.
///
/// One accent (violet) carries the brand, gold marks money and diamonds, and
/// status colours stay consistent between light and dark so a green chip always
/// means the same thing.
class AppTheme {
  const AppTheme._();

  static const brand = Color(0xFF6C5CE7);
  static const brandDeep = Color(0xFF4B3FD1);
  static const accent = Color(0xFF22D3EE);
  static const gold = Color(0xFFF5B14C);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);

  static const _darkBackground = Color(0xFF07080D);
  static const _darkSurface = Color(0xFF11141D);
  static const _darkSurfaceHigh = Color(0xFF191E2A);
  static const _lightBackground = Color(0xFFF6F6FB);

  static const radius = 18.0;
  static const radiusSmall = 12.0;

  static LinearGradient get brandGradient => const LinearGradient(
        colors: [brand, Color(0xFF8E7BFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static const LinearGradient brandGradientDark = LinearGradient(
    colors: [Color(0xFF2A2170), Color(0xFF0E1016)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get goldGradient => const LinearGradient(
        colors: [Color(0xFFF5B14C), Color(0xFFE08A2E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? const Color(0xFF8E7BFF) : brand,
      secondary: accent,
      tertiary: gold,
      error: danger,
      surface: isDark ? _darkSurface : Colors.white,
      surfaceContainerHighest:
          isDark ? _darkSurfaceHigh : const Color(0xFFEDEDF5),
    );

    final base = isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final textTheme = _textTheme(base.textTheme, scheme);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? _darkBackground : _lightBackground,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? _darkBackground : _lightBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: _border(scheme, isDark)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: _border(scheme, isDark),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _darkSurfaceHigh : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle:
            textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        border: _inputBorder(_border(scheme, isDark)),
        enabledBorder: _inputBorder(_border(scheme, isDark)),
        focusedBorder: _inputBorder(scheme.primary, width: 1.6),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSmall + 2)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: _border(scheme, isDark)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSmall + 2)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: textTheme.labelLarge),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? _darkSurfaceHigh : const Color(0xFFEFEFF6),
        side: BorderSide(color: _border(scheme, isDark)),
        labelStyle: textTheme.labelMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? _darkSurface : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }

  static Color _border(ColorScheme scheme, bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE3E3ED);

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall + 2),
        borderSide: BorderSide(color: color, width: width),
      );

  /// Inter for latin text, with Noto Sans Myanmar behind it so Burmese never
  /// falls back to a system font that clips its stacked glyphs.
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    final myanmar = GoogleFonts.notoSansMyanmar().fontFamily;
    final fallback = myanmar == null ? null : <String>[myanmar];

    TextStyle inter({
      required double size,
      required FontWeight weight,
      double? height,
    }) =>
        GoogleFonts.inter(
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: scheme.onSurface,
        ).copyWith(fontFamilyFallback: fallback);

    return GoogleFonts.interTextTheme(base)
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
          fontFamilyFallback: fallback,
        )
        .copyWith(
          displaySmall: inter(size: 30, weight: FontWeight.w700, height: 1.2),
          headlineSmall: inter(size: 22, weight: FontWeight.w700, height: 1.3),
          titleLarge: inter(size: 19, weight: FontWeight.w700),
          titleMedium: inter(size: 15.5, weight: FontWeight.w600),
          labelLarge: inter(size: 15, weight: FontWeight.w600),
        );
  }
}

/// Colours for each order / top-up state, used by chips and detail headers.
class StatusPalette {
  const StatusPalette._();

  static Color of(String status) => switch (status) {
        'COMPLETED' || 'APPROVED' => AppTheme.success,
        'PROCESSING' => AppTheme.info,
        'PENDING' => AppTheme.warning,
        'REJECTED' || 'CANCELLED' => AppTheme.danger,
        'REFUNDED' => AppTheme.brand,
        _ => AppTheme.warning,
      };
}

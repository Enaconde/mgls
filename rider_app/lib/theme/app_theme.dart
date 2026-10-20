import 'package:flutter/material.dart';

abstract final class AppColors {
  // PLACEHOLDER: owner to choose the brand colour and logo.
  static const brand = Color(0xFF245E61);
  static const ink = Color(0xFF111111);
}

abstract final class AppSpacing {
  static const unit = 8.0;
  static const page = 16.0;
  static const cardRadius = 16.0;
  static const tapTarget = 48.0;
  static const icon = 24.0;
}

abstract final class AppTypography {
  static const title = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  static const price = TextStyle(fontSize: 22, fontWeight: FontWeight.w600);
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    // Some Roboto distributions lack U+20AE. Use installed platform fonts as
    // fallbacks so the tugrik sign remains readable without bundling assets.
    final text = base.textTheme.apply(
      fontFamilyFallback: const ['Noto Sans', 'Arial'],
    );
    return base.copyWith(
      // Merge, don't replace: the base styles carry the light/dark text
      // colours, and a bare TextStyle would leave dark titles on dark cards.
      textTheme: text.copyWith(
        titleMedium: text.titleMedium!.merge(AppTypography.title),
        titleLarge: text.titleLarge!.merge(AppTypography.price),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        margin: const EdgeInsets.all(AppSpacing.page),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSpacing.tapTarget, AppSpacing.tapTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page,
            vertical: AppSpacing.unit,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppSpacing.tapTarget, AppSpacing.tapTarget),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSpacing.tapTarget),
          iconSize: AppSpacing.icon,
        ),
      ),
    );
  }
}

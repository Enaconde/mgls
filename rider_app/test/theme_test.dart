import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/theme/app_theme.dart';

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  double luminance(Color c) {
    double channel(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  final la = luminance(a), lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final entry in {
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  }.entries) {
    test('${entry.key} theme titles are readable on cards', () {
      final theme = entry.value;
      final card = theme.cardTheme.color ?? theme.colorScheme.surface;
      for (final style in [
        theme.textTheme.titleMedium!,
        theme.textTheme.titleLarge!,
      ]) {
        expect(style.color, isNotNull);
        expect(contrast(style.color!, card), greaterThanOrEqualTo(4.5));
      }
    });
    test(
      '${entry.key} search names, grey areas and input text have contrast',
      () {
        final theme = entry.value;
        final scheme = theme.colorScheme;
        for (final foreground in [
          scheme.onSurface,
          scheme.onSurfaceVariant,
          theme.textTheme.bodyMedium!.color!,
          theme.textTheme.bodySmall!.color!,
          theme.textTheme.titleMedium!.color!,
        ]) {
          expect(
            contrast(foreground, scheme.surface),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrast(foreground, theme.scaffoldBackgroundColor),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrast(foreground, scheme.surfaceContainerHigh),
            greaterThanOrEqualTo(4.5),
          );
        }
        expect(
          contrast(scheme.onSecondaryContainer, scheme.secondaryContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.onSurface, scheme.secondaryContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  }
}

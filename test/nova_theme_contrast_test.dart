import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';

double contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return (a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05);
}

void main() {
  for (final brightness in Brightness.values) {
    test('NOVA semantic text roles meet AA in $brightness', () {
      final theme = NovaTheme.build(brightness);
      final scheme = theme.colorScheme;
      final pairs = <(Color, Color)>[
        (scheme.onPrimary, scheme.primary),
        (scheme.onPrimaryContainer, scheme.primaryContainer),
        (scheme.onSecondary, scheme.secondary),
        (scheme.onSecondaryContainer, scheme.secondaryContainer),
        (scheme.onError, scheme.error),
        (scheme.onErrorContainer, scheme.errorContainer),
        (scheme.onInverseSurface, scheme.inverseSurface),
        for (final surface in [
          theme.scaffoldBackgroundColor,
          scheme.surface,
          scheme.surfaceContainerHigh,
          scheme.surfaceContainerHighest,
        ]) ...[
          (scheme.onSurface, surface),
          (scheme.onSurfaceVariant, surface),
          (scheme.secondary, surface),
        ],
      ];
      for (final (foreground, background) in pairs) {
        expect(contrast(foreground, background), greaterThanOrEqualTo(4.5),
            reason: '$foreground on $background');
      }
    });
  }

  test('poster badge stays readable over the brightest possible image', () {
    final background = Color.alphaBlend(
        NovaColors.ink.withValues(alpha: .72), NovaColors.white);
    expect(contrast(NovaColors.white, background), greaterThanOrEqualTo(4.5));
    expect(contrast(NovaColors.rating, background), greaterThanOrEqualTo(3));
  });

  test('Arabic and English have identical keys and substitution fields', () {
    Map<String, dynamic> read(String locale) =>
        jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
            as Map<String, dynamic>;
    final en = read('en')..removeWhere((key, _) => key.startsWith('@'));
    final ar = read('ar')..removeWhere((key, _) => key.startsWith('@'));
    expect(ar.keys.toSet(), en.keys.toSet());
    Set<String> placeholders(String text) => RegExp(r'\{\w+\}')
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toSet();
    for (final key in en.keys) {
      expect(placeholders(ar[key] as String), placeholders(en[key] as String),
          reason: key);
    }
  });
}

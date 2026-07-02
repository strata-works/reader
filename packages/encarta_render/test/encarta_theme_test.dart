// packages/encarta_render/test/encarta_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:encarta_render/encarta_render.dart';

void main() {
  test('faithfulInSpirit factory produces a usable, debug-off theme', () {
    final t = EncartaTheme.faithfulInSpirit();
    expect(t, isA<ThemeExtension<EncartaTheme>>());
    expect(t.body.fontSize, isNotNull);
    expect(t.measure, greaterThan(400));
    expect(t.debugUnstyledTags, isFalse);
    // section heading levels are distinct and clamp out of range
    expect(t.sectionTitleStyle(1).fontSize, greaterThan(t.sectionTitleStyle(4).fontSize!));
    expect(t.sectionTitleStyle(99).fontSize, t.sectionTitleStyle(4).fontSize);
    // chrome/portal getters the app consumes are populated (theme owns all pixels)
    expect(t.chromeColor, isA<Color>());
    expect(t.onChromeColor, isA<Color>());
    expect(t.accentColor, isA<Color>());
    expect(t.surfaceColor, isA<Color>());
  });

  test('copyWith can flip debug highlight mode without losing styles', () {
    final t = EncartaTheme.faithfulInSpirit();
    final debug = t.copyWith(debugUnstyledTags: true);
    expect(debug.debugUnstyledTags, isTrue);
    expect(debug.body, t.body);
  });
}

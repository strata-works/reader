// packages/encarta_render/lib/src/encarta_theme.dart
import 'package:flutter/material.dart';

/// Bag of ALL concrete styling the renderer consumes. The renderer assigns
/// semantic roles; this decides every pixel. ThemeExtension so it can ride a
/// Flutter [ThemeData] if the host wants.
@immutable
class EncartaTheme extends ThemeExtension<EncartaTheme> {
  const EncartaTheme({
    required this.background,
    required this.foreground,
    required this.chromeColor,
    required this.onChromeColor,
    required this.accentColor,
    required this.surfaceColor,
    required this.measure,
    required this.blockSpacing,
    required this.sectionIndentPerDepth,
    required this.body,
    required this.intro,
    required this.author,
    required this.quote,
    required this.example,
    required this.listItem,
    required this.enumerator,
    required this.xrefStyle,
    required this.headlineDefault,
    required this.sectionTitles,
    required this.ruleColor,
    required this.fractionFontScale,
    required this.debugUnstyledTags,
    required this.debugUnstyledColor,
  });

  final Color background;
  final Color foreground;
  final Color chromeColor; // app toolbar chrome (blue/teal) — read by the app
  final Color onChromeColor; // foreground on chrome — read by the app
  final Color accentColor; // accent/highlight — read by the app
  final Color surfaceColor; // light content surface (portal tiles) — read by the app
  final double measure; // max content width — read by renderer + app
  final double blockSpacing; // vertical gap between blocks
  final double sectionIndentPerDepth; // indent step for nested sections / enumerators
  final TextStyle body; // pkey
  final TextStyle intro; // intro
  final TextStyle author; // author byline
  final TextStyle quote; // block quote
  final TextStyle example; // worked example
  final TextStyle listItem; // listitem text
  final TextStyle enumerator; // sec/seca/secb/secc labels
  final TextStyle xrefStyle; // link decoration merged onto base
  final TextStyle headlineDefault; // headline (all type variants)
  final List<TextStyle> sectionTitles; // by depth 1..n (clamped)
  final Color ruleColor;
  final double fractionFontScale; // fs type=2 numerator/denominator scale
  final bool debugUnstyledTags; // highlight unknown/rare tags
  final Color debugUnstyledColor;

  /// Returns the section heading style for [depth] (1-based), clamping to
  /// the available range so callers never receive null or throw.
  TextStyle sectionTitleStyle(int depth) {
    final i = (depth - 1).clamp(0, sectionTitles.length - 1);
    return sectionTitles[i];
  }

  /// The default theme — Encarta-era blue/teal chrome over a light content
  /// area with crisp, readable typography. "Faithful in spirit" per spec §8.
  factory EncartaTheme.faithfulInSpirit() {
    const ink = Color(0xFF1A1A1A);
    const teal = Color(0xFF0B7285);
    const linkBlue = Color(0xFF1B5E9B);
    return const EncartaTheme(
      background: Color(0xFFFBFBF7),
      foreground: ink,
      chromeColor: Color(0xFF1B5E8C), // Encarta-era blue/teal toolbar
      onChromeColor: Color(0xFFFFFFFF),
      accentColor: teal,
      surfaceColor: Color(0xFFFFFFFF), // light content/portal-tile surface
      measure: 680,
      blockSpacing: 14,
      sectionIndentPerDepth: 16,
      body: TextStyle(fontSize: 16, height: 1.5, color: ink),
      intro: TextStyle(
          fontSize: 18,
          height: 1.5,
          color: ink,
          fontWeight: FontWeight.w500),
      author: TextStyle(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: Color(0xFF555555)),
      quote: TextStyle(
          fontSize: 16,
          height: 1.5,
          fontStyle: FontStyle.italic,
          color: Color(0xFF333333)),
      example: TextStyle(fontSize: 15, height: 1.45, color: ink),
      listItem: TextStyle(fontSize: 16, height: 1.45, color: ink),
      enumerator:
          TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: teal),
      xrefStyle: TextStyle(
          color: linkBlue, decoration: TextDecoration.underline),
      headlineDefault:
          TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink),
      sectionTitles: [
        TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: teal),
        TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: teal),
        TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ink),
        TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink),
      ],
      ruleColor: Color(0xFFCCCCCC),
      fractionFontScale: 0.72,
      debugUnstyledTags: false,
      debugUnstyledColor: Color(0x33FF0000),
    );
  }

  @override
  EncartaTheme copyWith({
    Color? background,
    Color? foreground,
    Color? chromeColor,
    Color? onChromeColor,
    Color? accentColor,
    Color? surfaceColor,
    double? measure,
    double? blockSpacing,
    double? sectionIndentPerDepth,
    TextStyle? body,
    TextStyle? intro,
    TextStyle? author,
    TextStyle? quote,
    TextStyle? example,
    TextStyle? listItem,
    TextStyle? enumerator,
    TextStyle? xrefStyle,
    TextStyle? headlineDefault,
    List<TextStyle>? sectionTitles,
    Color? ruleColor,
    double? fractionFontScale,
    bool? debugUnstyledTags,
    Color? debugUnstyledColor,
  }) {
    return EncartaTheme(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      chromeColor: chromeColor ?? this.chromeColor,
      onChromeColor: onChromeColor ?? this.onChromeColor,
      accentColor: accentColor ?? this.accentColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      measure: measure ?? this.measure,
      blockSpacing: blockSpacing ?? this.blockSpacing,
      sectionIndentPerDepth:
          sectionIndentPerDepth ?? this.sectionIndentPerDepth,
      body: body ?? this.body,
      intro: intro ?? this.intro,
      author: author ?? this.author,
      quote: quote ?? this.quote,
      example: example ?? this.example,
      listItem: listItem ?? this.listItem,
      enumerator: enumerator ?? this.enumerator,
      xrefStyle: xrefStyle ?? this.xrefStyle,
      headlineDefault: headlineDefault ?? this.headlineDefault,
      sectionTitles: sectionTitles ?? this.sectionTitles,
      ruleColor: ruleColor ?? this.ruleColor,
      fractionFontScale: fractionFontScale ?? this.fractionFontScale,
      debugUnstyledTags: debugUnstyledTags ?? this.debugUnstyledTags,
      debugUnstyledColor: debugUnstyledColor ?? this.debugUnstyledColor,
    );
  }

  @override
  EncartaTheme lerp(ThemeExtension<EncartaTheme>? other, double t) {
    if (other is! EncartaTheme) return this;
    return t < 0.5 ? this : other;
  }
}

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
  // ── Encarta-2009 revival palette (cool teal/blue software chrome, cleaned up).
  // Text styles leave fontFamily null on purpose: the app installs Selawik
  // (the open Segoe UI substitute) globally, so every role inherits it while
  // this package stays font-agnostic.
  static const Color _ink = Color(0xFF1B2831); // cool near-black body text
  static const Color _inkSoft = Color(0xFF51636D); // captions, byline, meta
  static const Color _teal = Color(0xFF0C6E93); // Encarta section-heading blue-teal
  static const Color _accent = Color(0xFF159AC0); // bright teal — active states
  static const Color _link = Color(0xFF1466B8); // classic hyperlink blue
  static const Color _surface = Color(0xFFFCFDFE); // cool near-white content bg
  static const Color _hairline = Color(0xFFD6E0E7); // cool rules/borders

  /// The default theme — a faithful-in-spirit Encarta 2009 revival: cool
  /// teal/blue chrome, Selawik (Segoe-substitute) type, crisp reading measure.
  factory EncartaTheme.faithfulInSpirit() {
    return const EncartaTheme(
      background: _surface,
      foreground: _ink,
      chromeColor: Color(0xFF14648B), // mid teal-blue; the toolbar builds a gradient from it
      onChromeColor: Color(0xFFFFFFFF),
      accentColor: _accent,
      surfaceColor: Color(0xFFFFFFFF),
      measure: 700,
      blockSpacing: 15,
      sectionIndentPerDepth: 18,
      body: TextStyle(fontSize: 15.5, height: 1.62, color: _ink),
      intro: TextStyle(fontSize: 17, height: 1.58, color: _ink),
      author: TextStyle(
          fontSize: 13.5, fontStyle: FontStyle.italic, color: _inkSoft),
      quote: TextStyle(
          fontSize: 15.5,
          height: 1.6,
          fontStyle: FontStyle.italic,
          color: Color(0xFF34505C)),
      example: TextStyle(fontSize: 14.5, height: 1.55, color: _ink),
      listItem: TextStyle(fontSize: 15.5, height: 1.55, color: _ink),
      enumerator:
          TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _accent),
      xrefStyle:
          TextStyle(color: _link, decoration: TextDecoration.underline),
      headlineDefault:
          TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink),
      sectionTitles: [
        TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: _teal),
        TextStyle(fontSize: 17.5, fontWeight: FontWeight.w600, color: _teal),
        TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: _ink),
        TextStyle(
            fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF34505C)),
      ],
      ruleColor: _hairline,
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

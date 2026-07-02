import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';

// ── Design-system palette (Encarta-2009 revival). ────────────────────────────
const _kContentBg = Color(0xFFFCFDFE);
const _kCardBg = Color(0xFFFFFFFF);
const _kHairline = Color(0xFFD6E0E7);
const _kAccent = Color(0xFF159AC0);
const _kSectionTeal = Color(0xFF0C6E93);
const _kInk = Color(0xFF1B2831);
const _kInkSoft = Color(0xFF51636D);
const _kPaleTeal = Color(0xFFEAF4F8);
const _kMaxWidth = 1040.0;

/// Data bag for the Home portal view.
class HomeViewData {
  final TitleRef? hero;
  final List<TitleRef> tiles;
  final List<String> azLetters;
  const HomeViewData({
    required this.hero,
    required this.tiles,
    required this.azLetters,
  });
}

/// Encarta portal: hero featured article + tile grid + A-Z strip + search + random.
class HomeView extends StatefulWidget {
  final HomeViewData data;
  final void Function(int refid) onOpenArticle;
  final void Function(String letter) onBrowseLetter;
  final void Function(String query) onSearch;
  final VoidCallback onRandom;

  const HomeView({
    super.key,
    required this.data,
    required this.onOpenArticle,
    required this.onBrowseLetter,
    required this.onSearch,
    required this.onRandom,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final et = Theme.of(context).extension<EncartaTheme>();
    final accent = et?.accentColor ?? _kAccent;
    final hairline = et?.ruleColor ?? _kHairline;
    final bg = et?.background ?? _kContentBg;

    return ColoredBox(
      color: bg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Masthead: wordmark + tagline + search row.
                _Masthead(
                  controller: _controller,
                  accent: accent,
                  onSearch: widget.onSearch,
                  onRandom: widget.onRandom,
                ),
                const SizedBox(height: 28),
                // Hero: featured article card.
                if (widget.data.hero != null) ...[
                  _HeroCard(
                    hero: widget.data.hero!,
                    accent: accent,
                    onTap: () =>
                        widget.onOpenArticle(widget.data.hero!.refid),
                  ),
                  const SizedBox(height: 32),
                ],
                // Featured tile grid.
                if (widget.data.tiles.isNotEmpty) ...[
                  _PaneLabel('FEATURED', accent: accent),
                  const SizedBox(height: 12),
                  _TileGrid(
                    tiles: widget.data.tiles,
                    accent: accent,
                    hairline: hairline,
                    onTap: widget.onOpenArticle,
                  ),
                  const SizedBox(height: 32),
                ],
                // A-Z browse strip.
                if (widget.data.azLetters.isNotEmpty) ...[
                  _PaneLabel('BROWSE A–Z', accent: accent),
                  const SizedBox(height: 12),
                  _AzStrip(
                    letters: widget.data.azLetters,
                    accent: accent,
                    hairline: hairline,
                    onTap: widget.onBrowseLetter,
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pane label ("FEATURED", "BROWSE A-Z") ────────────────────────────────────
class _PaneLabel extends StatelessWidget {
  const _PaneLabel(this.text, {required this.accent});
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: _kInkSoft,
          ),
        ),
        const SizedBox(height: 5),
        Container(height: 2, width: 22, color: accent),
      ],
    );
  }
}

// ── Masthead ──────────────────────────────────────────────────────────────────
class _Masthead extends StatelessWidget {
  const _Masthead({
    required this.controller,
    required this.accent,
    required this.onSearch,
    required this.onRandom,
  });

  final TextEditingController controller;
  final Color accent;
  final void Function(String) onSearch;
  final VoidCallback onRandom;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Encarta',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: _kSectionTeal,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'The recovered 2009 encyclopedia',
          style: TextStyle(
            fontSize: 13,
            color: _kInkSoft,
          ),
        ),
        const SizedBox(height: 20),
        // Centered search row: search field (max 620) + Surprise me button.
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _SearchField(
                    controller: controller,
                    accent: accent,
                    onSearch: onSearch,
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  key: const Key('home.random'),
                  onPressed: onRandom,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    fixedSize: const Size.fromHeight(40),
                    minimumSize: const Size(0, 40),
                    alignment: Alignment.center,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    // height:1.0 drops the font's extra leading so the label
                    // sits dead-center in the 40px button.
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                  ),
                  child: const Text('Surprise me'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Search field ─────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.accent,
    required this.onSearch,
  });

  final TextEditingController controller;
  final Color accent;
  final void Function(String) onSearch;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSearch,
      style: const TextStyle(fontSize: 15, color: _kInk),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, size: 20, color: _kInkSoft),
        hintText: 'Search the Encarta encyclopedia…',
        hintStyle: TextStyle(
          fontSize: 14,
          color: _kInkSoft.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: _kCardBg,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kHairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────
class _HeroCard extends StatefulWidget {
  const _HeroCard({
    required this.hero,
    required this.accent,
    required this.onTap,
  });

  final TitleRef hero;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final disableAnim = MediaQuery.of(context).disableAnimations;
    final duration =
        disableAnim ? Duration.zero : const Duration(milliseconds: 150);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: duration,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: _hovered ? 0.12 : 0.06),
                blurRadius: _hovered ? 18 : 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 4 px accent-teal left border.
                Container(width: 4, color: widget.accent),
                // Content area.
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(24, 22, 28, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Eyebrow label.
                        Text(
                          'FEATURED ARTICLE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: widget.accent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Hero title via CaptionText (handles <it> etc.).
                        CaptionText(
                          widget.hero.title,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: _kInk,
                            height: 1.25,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Featured tile grid ────────────────────────────────────────────────────────
class _TileGrid extends StatelessWidget {
  const _TileGrid({
    required this.tiles,
    required this.accent,
    required this.hairline,
    required this.onTap,
  });

  final List<TitleRef> tiles;
  final Color accent;
  final Color hairline;
  final void Function(int refid) onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final t in tiles)
          SizedBox(
            width: 232,
            child: _TileCard(
              tile: t,
              accent: accent,
              hairline: hairline,
              onTap: onTap,
            ),
          ),
      ],
    );
  }
}

class _TileCard extends StatefulWidget {
  const _TileCard({
    required this.tile,
    required this.accent,
    required this.hairline,
    required this.onTap,
  });

  final TitleRef tile;
  final Color accent;
  final Color hairline;
  final void Function(int refid) onTap;

  @override
  State<_TileCard> createState() => _TileCardState();
}

class _TileCardState extends State<_TileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final disableAnim = MediaQuery.of(context).disableAnimations;
    final duration =
        disableAnim ? Duration.zero : const Duration(milliseconds: 120);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onTap(widget.tile.refid),
        child: AnimatedContainer(
          duration: duration,
          clipBehavior: Clip.antiAlias,
          constraints: const BoxConstraints(minHeight: 72),
          decoration: BoxDecoration(
            color: _hovered ? _kPaleTeal : _kCardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered ? widget.accent : widget.hairline,
              width: _hovered ? 1.5 : 1.0,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 3 px teal left accent bar.
                Container(width: 3, color: widget.accent),
                // Tile text content.
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(13, 16, 16, 16),
                    child: CaptionText(
                      widget.tile.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _kInk,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── A-Z browse strip ──────────────────────────────────────────────────────────
class _AzStrip extends StatelessWidget {
  const _AzStrip({
    required this.letters,
    required this.accent,
    required this.hairline,
    required this.onTap,
  });

  final List<String> letters;
  final Color accent;
  final Color hairline;
  final void Function(String letter) onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final l in letters)
          _AzChip(
            letter: l,
            accent: accent,
            hairline: hairline,
            onTap: onTap,
          ),
      ],
    );
  }
}

class _AzChip extends StatefulWidget {
  const _AzChip({
    required this.letter,
    required this.accent,
    required this.hairline,
    required this.onTap,
  });

  final String letter;
  final Color accent;
  final Color hairline;
  final void Function(String letter) onTap;

  @override
  State<_AzChip> createState() => _AzChipState();
}

class _AzChipState extends State<_AzChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final disableAnim = MediaQuery.of(context).disableAnimations;
    final duration =
        disableAnim ? Duration.zero : const Duration(milliseconds: 120);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onTap(widget.letter),
        child: AnimatedContainer(
          duration: duration,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hovered ? widget.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered ? widget.accent : widget.hairline,
            ),
          ),
          child: Center(
            child: Text(
              widget.letter,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _hovered ? Colors.white : _kInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

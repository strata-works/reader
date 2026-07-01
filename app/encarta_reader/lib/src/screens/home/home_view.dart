import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';

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

/// Encarta portal: hero featured article + featured tile grid + A–Z + search + random.
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
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Prominent search.
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onSubmitted: widget.onSearch,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search the Encarta encyclopedia…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        // Hero featured article.
        if (widget.data.hero != null)
          InkWell(
            onTap: () => widget.onOpenArticle(widget.data.hero!.refid),
            child: Container(
              height: 160,
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CaptionText(widget.data.hero!.title,
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
          ),
        const SizedBox(height: 24),
        // Featured tile grid.
        if (widget.data.tiles.isNotEmpty) ...[
          const Text('Featured', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final t in widget.data.tiles)
                SizedBox(
                  width: 200,
                  height: 90,
                  child: Card(
                    child: InkWell(
                      onTap: () => widget.onOpenArticle(t.refid),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: CaptionText(t.title),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        // A–Z browse strip.
        if (widget.data.azLetters.isNotEmpty) ...[
          const Text('Browse A–Z',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final letter in widget.data.azLetters)
                OutlinedButton(
                  onPressed: () => widget.onBrowseLetter(letter),
                  child: Text(letter),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        // Random article.
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const Key('home.random'),
            onPressed: widget.onRandom,
            icon: const Icon(Icons.casino),
            label: const Text('Random article'),
          ),
        ),
      ],
    );
  }
}

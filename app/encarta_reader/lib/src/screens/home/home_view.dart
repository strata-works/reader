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
class HomeView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Prominent search.
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onSubmitted: onSearch,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search the Encarta encyclopedia…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        // Hero featured article.
        if (data.hero != null)
          InkWell(
            onTap: () => onOpenArticle(data.hero!.refid),
            child: Container(
              height: 160,
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(data.hero!.title,
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
          ),
        const SizedBox(height: 24),
        // Featured tile grid.
        if (data.tiles.isNotEmpty) ...[
          const Text('Featured', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final t in data.tiles)
                SizedBox(
                  width: 200,
                  height: 90,
                  child: Card(
                    child: InkWell(
                      onTap: () => onOpenArticle(t.refid),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(t.title),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        // A–Z browse strip.
        if (data.azLetters.isNotEmpty) ...[
          const Text('Browse A–Z',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final letter in data.azLetters)
                OutlinedButton(
                  onPressed: () => onBrowseLetter(letter),
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
            onPressed: onRandom,
            icon: const Icon(Icons.casino),
            label: const Text('Random article'),
          ),
        ),
      ],
    );
  }
}

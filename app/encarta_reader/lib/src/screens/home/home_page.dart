import 'package:auto_route/auto_route.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';

import '../../widgets/app_scope.dart';
import 'home_view.dart';

const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// Pure assembly of the Home portal: first featured = hero, rest = tiles, A–Z strip.
///
/// If [featured] returns an empty list and [fallback] is provided, [fallback]
/// is called instead — so Home is never blank even if the curated group is empty.
Future<HomeViewData> buildHomeViewData({
  required Future<List<TitleRef>> Function({int limit}) featured,
  Future<List<TitleRef>> Function({int limit})? fallback,
}) async {
  var feats = await featured(limit: 12);
  if (feats.isEmpty && fallback != null) {
    feats = await fallback(limit: 12);
  }
  return HomeViewData(
    hero: feats.isEmpty ? null : feats.first,
    tiles: feats.length > 1 ? feats.sublist(1) : const [],
    azLetters: _alphabet.split(''),
  );
}

@RoutePage()
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<HomeViewData>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final db = AppScope.of(context).db;
    if (db == null) return; // guard: shell-only mode (no DB)
    _future = buildHomeViewData(
      featured: db.featured,
      fallback: ({int limit = 12}) => db.titlesIndex(limit: limit),
    );
  }

  Future<void> _random() async {
    final scope = AppScope.of(context);
    final article = await scope.db!.randomArticle();
    if (article != null && mounted) {
      scope.navigator.openArticle(article.refid);
    }
  }

  void _browseLetter(String letter) {
    // The A–Z strip drives Search with a prefix query (titlesIndex powers the list).
    AppScope.of(context).navigator.openSearch(letter);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return FutureBuilder<HomeViewData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(
              child: Text('Something went wrong loading this home.'));
        }
        return HomeView(
          data: snap.data!,
          onOpenArticle: scope.navigator.openArticle,
          onBrowseLetter: _browseLetter,
          onSearch: scope.navigator.openSearch,
          onRandom: _random,
          onPlayMindMaze: () => AppScope.of(context).navigator.openMindMaze(),
        );
      },
    );
  }
}

import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';

import '../nav/app_navigator.dart';
import '../nav/history_controller.dart';

/// Encarta-era top toolbar: home, back/forward, and a search box. Frames all screens.
class EncartaToolbar extends StatefulWidget {
  final EncartaTheme theme;
  final HistoryController history;
  final AppNavigator navigator;
  final String initialQuery;

  const EncartaToolbar({
    super.key,
    required this.theme,
    required this.history,
    required this.navigator,
    this.initialQuery = '',
  });

  @override
  State<EncartaToolbar> createState() => _EncartaToolbarState();
}

class _EncartaToolbarState extends State<EncartaToolbar> {
  late final TextEditingController _search =
      TextEditingController(text: widget.initialQuery);

  @override
  void initState() {
    super.initState();
    widget.history.addListener(_onHistory);
  }

  void _onHistory() => setState(() {});

  @override
  void dispose() {
    widget.history.removeListener(_onHistory);
    _search.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final q = value.trim();
    if (q.isNotEmpty) widget.navigator.openSearch(q);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Material(
      color: t.chromeColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              key: const Key('toolbar.home'),
              color: t.onChromeColor,
              icon: const Icon(Icons.home),
              tooltip: 'Home',
              onPressed: widget.navigator.openHome,
            ),
            IconButton(
              key: const Key('toolbar.back'),
              color: t.onChromeColor,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: widget.history.canGoBack ? widget.navigator.back : null,
            ),
            IconButton(
              key: const Key('toolbar.forward'),
              color: t.onChromeColor,
              icon: const Icon(Icons.arrow_forward),
              tooltip: 'Forward',
              onPressed:
                  widget.history.canGoForward ? widget.navigator.forward : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const Key('toolbar.search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: _submit,
                style: TextStyle(color: t.onChromeColor),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: t.surfaceColor,
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search Encarta…',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

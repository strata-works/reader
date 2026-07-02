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

    // Hover overlay: white @ 14% circle; no splash/ripple.
    final navButtonStyle = ButtonStyle(
      fixedSize: const WidgetStatePropertyAll(Size(34, 34)),
      minimumSize: const WidgetStatePropertyAll(Size(34, 34)),
      maximumSize: const WidgetStatePropertyAll(Size(34, 34)),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      splashFactory: NoSplash.splashFactory,
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return Colors.white.withValues(alpha: 0.14);
        }
        return Colors.transparent;
      }),
      shape: const WidgetStatePropertyAll(CircleBorder()),
    );

    // Material(transparency) provides the Material ancestor that TextField
    // requires; the visible chrome comes from the Container gradient below.
    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: 52,
        decoration: const BoxDecoration(
          // Vertical teal → blue gradient per design spec.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E86B0), Color(0xFF0C567C)],
          ),
          // 1px bottom edge in the darker gradient stop.
          border: Border(
            bottom: BorderSide(color: Color(0xFF0C567C), width: 1),
          ),
          // Soft drop-shadow: blur 6, y 2, black @ 12%.
          boxShadow: [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            IconButton(
              key: const Key('toolbar.home'),
              iconSize: 20,
              color: t.onChromeColor,
              icon: const Icon(Icons.home),
              tooltip: 'Home',
              onPressed: widget.navigator.openHome,
              style: navButtonStyle,
            ),
            IconButton(
              key: const Key('toolbar.back'),
              iconSize: 20,
              color: t.onChromeColor,
              disabledColor: Colors.white38,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed:
                  widget.history.canGoBack ? widget.navigator.back : null,
              style: navButtonStyle,
            ),
            IconButton(
              key: const Key('toolbar.forward'),
              iconSize: 20,
              color: t.onChromeColor,
              disabledColor: Colors.white38,
              icon: const Icon(Icons.arrow_forward),
              tooltip: 'Forward',
              onPressed:
                  widget.history.canGoForward ? widget.navigator.forward : null,
              style: navButtonStyle,
            ),
            const SizedBox(width: 12),
            // Search field: white, 34px tall, radius 6, grows to fill up to 560px.
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SizedBox(
                    height: 34,
                    child: TextField(
                      key: const Key('toolbar.search'),
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _submit,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1B2831),
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 16,
                          color: Color(0xFF51636D), // ink-soft
                        ),
                        hintText: 'Search Encarta…',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF51636D).withValues(alpha: 0.7),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

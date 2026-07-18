// Task 9: assembles the Encarta 3-D Tour reader screen — loads a tour's
// assets (Task 6's loadTour), then stacks the flutter_scene viewport (Task 7's
// TourView) with the tappable hotspot overlay (Task 8's HotspotOverlay) and a
// dismissible label popup when a hotspot is selected.
//
// Task 7 (this pass): first-person walkthrough chrome on top of the above —
// an overview/walk mode toggle, glide travel between a tour's ANCHORED
// hotspots ("stops"), a collapsible stops panel, and the existing label card
// reused as walk-mode narration.
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'hotspot_overlay.dart';
import 'tour_adapter.dart';
import 'tour_view.dart';

enum _TourMode { overview, walk }

@RoutePage()
class ToursPage extends StatefulWidget {
  final String tourId;

  /// Overrides the [AssetBundle] used by [loadTour]; production leaves this
  /// null so [loadTour] falls back to [rootBundle]. Exposed for widget tests
  /// that need to force the missing-assets path deterministically.
  @visibleForTesting
  final AssetBundle? bundleOverride;

  const ToursPage({
    super.key,
    @PathParam('tourId') required this.tourId,
    this.bundleOverride,
  });

  @override
  State<ToursPage> createState() => _ToursPageState();
}

class _ToursPageState extends State<ToursPage>
    with SingleTickerProviderStateMixin {
  late final Future<TourAssets> _future;

  // Initial framing for the Acropolis tour.
  //
  // The tour is a small diorama meant to be seen from INSIDE its sky dome:
  // the monuments (lod*/newcolumnt*/boxbase*/Torch* meshes) cluster within
  // ~10 units of the origin at y~0-1, the walkable .3wm floor is ~14x19
  // units, and the one giant mesh (sky6_8, ~116 units across) is the sky
  // dome enclosing it all. Every AABB-derived framing (scene center y~122,
  // statue centroid y~91, .x bbox center y~13) orbits OUTSIDE the dome and
  // shows only its grey shell -- the `.3cl` statue clouds are UNPLACED
  // (only scale is recoverable; see quarry/tour3d.py) and inflate every
  // aggregate box. So: target the site center at torso height and orbit at
  // ~25 units, comfortably inside the dome, with a gentle downward
  // elevation. Azimuth keeps the Task-1 spike's three-quarter direction.
  //
  // NOTE: task-10-report.md's "environment-level compositing issue" theory
  // about blank renders was wrong. The blank viewport happened whenever the
  // app ran without Flutter GPU enabled: Scene.initializeStaticResources()
  // throws, TourView used to swallow the error, and the placeholder sat on
  // "Loading 3-D tour…" forever. Fixed by enabling Impeller + Flutter GPU in
  // the platform Info.plists (FLTEnableImpeller / FLTEnableFlutterGPU) and
  // surfacing renderer-init errors in TourView's placeholder. With GPU
  // enabled this framing renders the Parthenon as expected.
  OrbitCamera _camera = OrbitCamera(
    target: Vector3(-1.3, 1.5, -4.1),
    distance: 25.0,
    azimuth: 0.6640461628266847,
    elevation: 0.25,
    fovYRadians: 55 * math.pi / 180,
    near: 0.5,
    far: 4000.0,
  );

  Hotspot? _selected;

  // Walk-mode state.
  _TourMode _mode = _TourMode.overview;
  Walkmap? _walkmap;
  WalkCamera? _walkCamera;
  int? _currentStop;
  bool _panelOpen = false;

  // Travelable stops (anchored hotspots), computed once from the loaded
  // assets and cached here (corpus order).
  List<Hotspot>? _stops;

  // Glide-travel animation: 1200 ms ease-in-out between two WalkCameras.
  late final AnimationController _glideCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final CurvedAnimation _glideCurve = CurvedAnimation(
    parent: _glideCtrl,
    curve: Curves.easeInOut,
  );
  WalkCamera? _glideFrom, _glideTo;
  int? _glideTarget;
  bool get _gliding => _glideCtrl.isAnimating;

  @override
  void initState() {
    super.initState();
    // `onError` swallows failures on this SEPARATE listener: `_future` itself
    // still carries the error to FutureBuilder (which shows the friendly
    // "assets not found" message) — without this, a rejected `_future`
    // becomes an unhandled-exception zone error via this second `.then`
    // chain, since nothing else observes it.
    _future = loadTour(widget.tourId, bundle: widget.bundleOverride);
    _future.then(_onAssetsLoaded, onError: (_) {});
    _glideCurve.addListener(() {
      final f = _glideFrom, t = _glideTo;
      if (f == null || t == null) return;
      setState(() => _walkCamera = glideBetween(f, t, _glideCurve.value));
    });
    _glideCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && _glideTarget != null) {
        setState(() {
          _currentStop = _glideTarget;
          _selected = _stops![_glideTarget!];
        });
      }
    });
  }

  @override
  void dispose() {
    _glideCurve.dispose();
    _glideCtrl.dispose();
    super.dispose();
  }

  // Caches the travelable stops, then kicks off the walkmap load. Runs once
  // the tour's JSON assets have resolved (chained onto `_future`).
  Future<void> _onAssetsLoaded(TourAssets assets) async {
    _stops = assets.tour.hotspots.where((h) => h.anchor.length2 > 0).toList();
    await _loadWalkmap(assets);
  }

  // Loads the walkmap sidecar via the same (possibly overridden) bundle
  // loadTour used; a missing/unreadable walkmap degrades to null rather than
  // failing the whole page (walk mode is simply unavailable — see the mode
  // toggle's disabled condition below).
  Future<void> _loadWalkmap(TourAssets assets) async {
    Walkmap? map;
    try {
      final data = await (widget.bundleOverride ?? rootBundle).load(
        assets.walkmapAsset,
      );
      map = Walkmap.fromBytes(ByteData.sublistView(data.buffer.asUint8List()));
    } catch (_) {
      map = null;
    }
    if (mounted) setState(() => _walkmap = map);
  }

  // Enters walk mode, framing the first stop the first time; re-entering
  // keeps whatever pose was last active.
  void _enterWalkMode(List<Hotspot> stops) {
    setState(() {
      _mode = _TourMode.walk;
      if (_walkCamera == null && stops.isNotEmpty) {
        _walkCamera = WalkCamera.fromHotspot(stops[0]);
        _currentStop = 0;
        _selected = stops[0];
      }
    });
  }

  void _onModeTogglePressed(List<Hotspot> stops) {
    if (_mode == _TourMode.overview) {
      _enterWalkMode(stops);
    } else {
      setState(() => _mode = _TourMode.overview);
    }
  }

  // Glides from the current walk pose to `stops[index]` over 1200 ms
  // ease-in-out, locking TourView's input for the duration. On completion,
  // `_currentStop` advances and the narration card switches to the new stop.
  void _travelTo(List<Hotspot> stops, int index) {
    final from = _walkCamera ?? WalkCamera.fromHotspot(stops[index]);
    _glideFrom = from;
    _glideTo = WalkCamera.fromHotspot(stops[index]);
    _glideTarget = index;
    _glideCtrl
      ..reset()
      ..forward();
  }

  void _onStopTapped(List<Hotspot> stops, int index) {
    if (_mode == _TourMode.overview) {
      _enterWalkMode(stops);
    }
    _travelTo(stops, index);
  }

  void _onHotspotTap(Hotspot h, List<Hotspot> stops) {
    if (_mode == _TourMode.walk) {
      final idx = stops.indexWhere((s) => s.id == h.id);
      if (idx != -1) {
        _travelTo(stops, idx);
        return;
      }
    }
    setState(() => _selected = h);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Dark background, matching the Task-1 spike's Scaffold, rather than
      // the app's light theme default: a light background made it
      // impossible to tell whether unrendered/transparent 3-D content was
      // "blank" vs. simply blending into the page background during the
      // manual render check.
      backgroundColor: const Color(0xFF10131A),
      body: FutureBuilder<TourAssets>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          final assets = snapshot.data!;
          // Defensive fallback matching _onAssetsLoaded's computation, in
          // case this build runs before that callback (should not happen in
          // practice: it is chained onto the very same future).
          final stops = _stops ??= assets.tour.hotspots
              .where((h) => h.anchor.length2 > 0)
              .toList();
          return LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final camera = _mode == _TourMode.walk ? _walkCamera! : _camera;
              return Stack(
                children: [
                  // Positioned.fill gives TourView's CustomPaint(size:
                  // Size.infinite) TIGHT constraints matching the viewport,
                  // mirroring the Task-1 spike's Positioned.fill(...
                  // RepaintBoundary(... CustomPaint...)). As a bare
                  // (non-Positioned) Stack child it only gets LOOSE
                  // constraints. This did NOT turn out to be the cause of the
                  // blank render found during this task's manual check (see
                  // the _camera comment above and task-10-report.md) — that
                  // traced to an environment-level flutter_scene/Impeller
                  // compositing issue affecting the spike too — but tightening
                  // the constraints to match the spike's structure is still
                  // correct and should be kept regardless.
                  Positioned.fill(
                    child: TourView(
                      glbAsset: assets.glbAsset,
                      pointsAsset: assets.pointsAsset,
                      camera: camera,
                      onOrbitChanged: (c) => setState(() => _camera = c),
                      onWalkChanged: (c) => setState(() => _walkCamera = c),
                      walkmap: _walkmap,
                      showPoints: _mode == _TourMode.overview,
                      inputLocked: _gliding,
                    ),
                  ),
                  HotspotOverlay(
                    hotspots: assets.tour.hotspots,
                    camera: camera,
                    viewport: size,
                    onTap: (h) => _onHotspotTap(h, stops),
                  ),
                  _TourHeader(
                    mode: _mode,
                    currentStop: _currentStop,
                    stopCount: stops.length,
                    gliding: _gliding,
                    walkAvailable: _walkmap != null && stops.isNotEmpty,
                    onToggleMode: () => _onModeTogglePressed(stops),
                    onPrev: (_currentStop ?? 0) > 0 && !_gliding
                        ? () => _travelTo(stops, _currentStop! - 1)
                        : null,
                    onNext: (_currentStop ?? -1) < stops.length - 1 && !_gliding
                        ? () => _travelTo(stops, _currentStop! + 1)
                        : null,
                  ),
                  _StopsPanel(
                    stops: stops,
                    currentStop: _currentStop,
                    open: _panelOpen,
                    onToggle: () => setState(() => _panelOpen = !_panelOpen),
                    onSelect: (i) => _onStopTapped(stops, i),
                  ),
                  if (_selected != null)
                    _HotspotLabelCard(
                      key: const ValueKey('tour-narration'),
                      hotspot: _selected!,
                      onClose: () => setState(() => _selected = null),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// The top chrome row: overview/walk mode toggle, prev/next stop controls,
/// and a "stop N / total" counter once a stop is current.
class _TourHeader extends StatelessWidget {
  final _TourMode mode;
  final int? currentStop;
  final int stopCount;
  final bool gliding;
  final bool walkAvailable;
  final VoidCallback onToggleMode;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _TourHeader({
    required this.mode,
    required this.currentStop,
    required this.stopCount,
    required this.gliding,
    required this.walkAvailable,
    required this.onToggleMode,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    // The toggle stays enabled while already in walk mode (so the page can
    // always return to overview) even if the walkmap later became
    // unavailable; entering walk mode from overview requires it.
    final toggleEnabled = mode == _TourMode.walk || walkAvailable;
    final navEnabled = mode == _TourMode.walk && !gliding;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          color: Colors.black.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('tour-mode-toggle'),
                tooltip: mode == _TourMode.overview
                    ? 'Enter walkthrough'
                    : 'Return to overview',
                icon: Icon(
                  mode == _TourMode.overview
                      ? Icons.directions_walk
                      : Icons.public,
                  color: Colors.white,
                ),
                onPressed: toggleEnabled ? onToggleMode : null,
              ),
              IconButton(
                key: const ValueKey('tour-prev-stop'),
                tooltip: 'Previous stop',
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: navEnabled ? onPrev : null,
              ),
              IconButton(
                key: const ValueKey('tour-next-stop'),
                tooltip: 'Next stop',
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: navEnabled ? onNext : null,
              ),
              if (currentStop != null)
                Text(
                  'stop ${currentStop! + 1} / $stopCount',
                  style: const TextStyle(color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A collapsible right-side panel listing every travelable stop; tapping an
/// entry travels there (switching to walk mode first if needed).
class _StopsPanel extends StatelessWidget {
  final List<Hotspot> stops;
  final int? currentStop;
  final bool open;
  final VoidCallback onToggle;
  final void Function(int index) onSelect;

  const _StopsPanel({
    required this.stops,
    required this.currentStop,
    required this.open,
    required this.onToggle,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 56,
      right: 0,
      bottom: 24,
      width: open ? 220 : 48,
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IconButton(
              key: const ValueKey('tour-stops-panel-toggle'),
              tooltip: open ? 'Collapse stops' : 'Show stops',
              icon: Icon(
                open ? Icons.chevron_right : Icons.chevron_left,
                color: Colors.white,
              ),
              onPressed: onToggle,
            ),
            if (open)
              Expanded(
                child: ListView.builder(
                  itemCount: stops.length,
                  itemBuilder: (context, i) {
                    final h = stops[i];
                    return ListTile(
                      key: ValueKey('stop-${h.id}'),
                      title: Text(
                        h.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                      selected: currentStop == i,
                      onTap: () => onSelect(i),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A dismissible card near the bottom of the viewport showing the selected
/// hotspot's text. Doubles as the walk-mode narration card (see
/// `ValueKey('tour-narration')` at its call site).
class _HotspotLabelCard extends StatelessWidget {
  final Hotspot hotspot;
  final VoidCallback onClose;

  const _HotspotLabelCard({
    super.key,
    required this.hotspot,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: Card(
        color: Colors.black.withValues(alpha: 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  hotspot.text,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

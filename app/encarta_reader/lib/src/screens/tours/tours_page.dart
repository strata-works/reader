// Task 9: assembles the Encarta 3-D Tour reader screen — loads a tour's
// assets (Task 6's loadTour), then stacks the flutter_scene viewport (Task 7's
// TourView) with the tappable hotspot overlay (Task 8's HotspotOverlay) and a
// dismissible label popup when a hotspot is selected.
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

class _ToursPageState extends State<ToursPage> {
  late final Future<TourAssets> _future;

  // Initial framing for the Acropolis tour.
  //
  // Mirrors the Task-1 spike's proven-working `buildTourCamera()` eye/target
  // (tour_spike_app.dart), converted from a fixed eye position to
  // azimuth/elevation/distance: target = scene AABB center shifted down
  // ~40 units (the Parthenon body sits low; the raw AABB is inflated by
  // spires/statues), distance/azimuth/elevation reproduce
  // `target + Vector3(radius*0.9, radius*0.55, radius*1.15)` with radius=170.
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
    target: Vector3(-0.8, 82.55, -56.6),
    distance: 265.27627108356296,
    azimuth: 0.6640461628266847,
    elevation: 0.3602014204225637,
    fovYRadians: 55 * math.pi / 180,
    near: 1.0,
    far: 4000.0,
  );

  Hotspot? _selected;

  @override
  void initState() {
    super.initState();
    _future = loadTour(widget.tourId, bundle: widget.bundleOverride);
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
          return LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
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
                      camera: _camera,
                      onCameraChanged: (c) => setState(() => _camera = c),
                    ),
                  ),
                  HotspotOverlay(
                    hotspots: assets.tour.hotspots,
                    camera: _camera,
                    viewport: size,
                    onTap: (h) => setState(() => _selected = h),
                  ),
                  if (_selected != null)
                    _HotspotLabelCard(
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

/// A dismissible card near the bottom of the viewport showing the selected
/// hotspot's text.
class _HotspotLabelCard extends StatelessWidget {
  final Hotspot hotspot;
  final VoidCallback onClose;

  const _HotspotLabelCard({required this.hotspot, required this.onClose});

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

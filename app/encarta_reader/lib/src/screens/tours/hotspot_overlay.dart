import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// Renderer-agnostic tappable overlay that projects each [Hotspot]'s 3-D
/// anchor to screen space via [camera] and lays a marker over it. Meant to
/// sit in a [Stack] above the 3-D [TourView] (Task 7).
class HotspotOverlay extends StatelessWidget {
  final List<Hotspot> hotspots;
  final TourCamera camera;
  final Size viewport;
  final void Function(Hotspot) onTap;

  const HotspotOverlay({
    super.key,
    required this.hotspots,
    required this.camera,
    required this.viewport,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final viewProj =
        camera.viewProjectionMatrix(viewport.width / viewport.height);
    final markers = <Widget>[];
    for (final h in hotspots) {
      final Vector2? s =
          projectToScreen(h.anchor, viewProj, viewport.width, viewport.height);
      if (s == null) continue;
      if (s.x < 0 || s.y < 0 || s.x > viewport.width || s.y > viewport.height) {
        continue;
      }
      markers.add(Positioned(
        left: s.x - 14,
        top: s.y - 14,
        child: GestureDetector(
          key: ValueKey('hotspot-${h.id}'),
          onTap: () => onTap(h),
          child: const _Marker(),
        ),
      ));
    }
    return Stack(children: markers);
  }
}

class _Marker extends StatelessWidget {
  const _Marker();

  @override
  Widget build(BuildContext context) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black54, width: 1.5),
        ),
        child: const Icon(Icons.info_outline, size: 16, color: Colors.black87),
      );
}

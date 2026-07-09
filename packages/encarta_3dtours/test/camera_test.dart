import 'package:vector_math/vector_math_64.dart';
import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:test/test.dart';

void main() {
  test('a point at the camera target projects near screen center', () {
    final cam = OrbitCamera(
      target: Vector3.zero(),
      azimuth: 0,
      elevation: 0,
      distance: 5,
    );
    const width = 800.0, height = 600.0;
    final vp = cam.viewProjectionMatrix(width / height);
    final o = projectToScreen(Vector3.zero(), vp, width, height);
    expect(o, isNotNull);
    expect(o!.x, closeTo(400, 1.0));
    expect(o.y, closeTo(300, 1.0));
  });

  test('a point behind the camera projects to null', () {
    final cam = OrbitCamera(
      target: Vector3.zero(),
      azimuth: 0,
      elevation: 0,
      distance: 5,
    );
    const width = 800.0, height = 600.0;
    final vp = cam.viewProjectionMatrix(width / height);
    // camera looks down -Z from +Z(=5); a point far behind the eye (+Z) is off-screen/behind
    expect(projectToScreen(Vector3(0, 0, 50), vp, width, height), isNull);
  });
}

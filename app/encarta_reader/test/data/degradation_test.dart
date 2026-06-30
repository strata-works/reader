import 'package:encarta_render/encarta_render.dart';
import 'package:encarta_reader/src/data/degradation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the DB title when present', () {
    final t = resolveDisplayTitle(
      refid: 5,
      dbTitle: 'Photosynthesis',
      outline: const EncartaOutline([]),
    );
    expect(t, 'Photosynthesis');
  });

  test('falls back to the first outline entry title', () {
    final t = resolveDisplayTitle(
      refid: 5,
      dbTitle: '',
      outline: const EncartaOutline(
        [OutlineEntry(title: 'Overview', anchorId: 'a1', depth: 0)],
      ),
    );
    expect(t, 'Overview');
  });

  test('falls back to the refid string when nothing else exists', () {
    final t = resolveDisplayTitle(
      refid: 99,
      dbTitle: '',
      outline: const EncartaOutline([]),
    );
    expect(t, 'Article 99');
  });
}

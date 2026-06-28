import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

void main() {
  test('MediaItem holds fields and supports value equality', () {
    const a = MediaItem(
      mediaRefid: 7,
      role: 'image',
      group: 'media',
      title: 'Eagle',
      caption: 'A bald eagle',
      credit: 'NPS',
      assetPath: 'image/abc123.jpg',
      ext: '.jpg',
      kind: 'image',
    );
    const b = MediaItem(
      mediaRefid: 7,
      role: 'image',
      group: 'media',
      title: 'Eagle',
      caption: 'A bald eagle',
      credit: 'NPS',
      assetPath: 'image/abc123.jpg',
      ext: '.jpg',
      kind: 'image',
    );
    expect(a.assetPath, 'image/abc123.jpg');
    expect(a.title, 'Eagle');
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });
}

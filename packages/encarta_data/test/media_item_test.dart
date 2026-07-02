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
    const c = MediaItem(
      mediaRefid: 99,
      role: 'video',
      group: 'media',
      title: 'Wolf',
      caption: 'A grey wolf',
      credit: 'USFWS',
      assetPath: 'video/xyz789.mp4',
      ext: '.mp4',
      kind: 'video',
    );

    const noOptionals = MediaItem(
      mediaRefid: 1,
      role: 'image',
      group: 'misc',
      assetPath: 'image/foo.png',
      ext: '.png',
      kind: 'image',
    );

    expect(a.assetPath, 'image/abc123.jpg');
    expect(a.title, 'Eagle');
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(equals(c)));
    expect(noOptionals.title, isNull);
    expect(noOptionals.caption, isNull);
    expect(noOptionals.credit, isNull);
  });
}

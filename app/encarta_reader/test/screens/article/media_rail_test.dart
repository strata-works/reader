// app/encarta_reader/test/screens/article/media_rail_test.dart
import 'dart:io';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_reader/src/screens/article/media_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

late Directory _root;
late EncartaAssets _assets;

MediaItem _imageItem() => const MediaItem(
      mediaRefid: 1,
      role: 'image',
      group: 'article',
      title: 'Saturn',
      caption: 'The ringed planet',
      credit: 'NASA',
      assetPath: 'image/abc123.jpg',
      ext: '.jpg',
      kind: 'image',
    );

MediaItem _audioItem() => const MediaItem(
      mediaRefid: 2,
      role: 'audio',
      group: 'article',
      title: 'Clip',
      caption: 'A sound clip',
      credit: 'Encarta',
      assetPath: 'audio/missing.wma',
      ext: '.wma',
      kind: 'audio',
    );

// Corpus quirk: WMV files are classified kind='other'.
MediaItem _videoOtherItem() => const MediaItem(
      mediaRefid: 3,
      role: 'video',
      group: 'article',
      title: 'Movie',
      caption: null,
      credit: null,
      assetPath: 'other/missing.wmv',
      ext: '.wmv',
      kind: 'other',
    );

/// Audio item whose title contains inline markup (asset path is missing so the
/// unavailable poster is shown, which also renders the title via CaptionText).
MediaItem _audioItemWithMarkupTitle() => const MediaItem(
      mediaRefid: 4,
      role: 'audio',
      group: 'article',
      title: 'Opening Lines of <it>Henry V</it>',
      caption: null,
      credit: null,
      assetPath: 'audio/missing_markup.wma',
      ext: '.wma',
      kind: 'audio',
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    _root = Directory.systemTemp.createTempSync('encarta_reader_media_rail');
    _assets = EncartaAssets.forTesting(AssetConfig(_root.path));
  });
  tearDown(() => _root.deleteSync(recursive: true));

  testWidgets('renders EncartaImage for image-kind item, shows caption + credit',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MediaRail(
          media: [_imageItem()],
          assets: _assets,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(EncartaImage), findsOneWidget);
    // EncartaImage renders caption and prefixes credit with "Credit: "
    expect(find.text('The ringed planet'), findsOneWidget);
    expect(find.textContaining('NASA'), findsOneWidget);
  });

  testWidgets('renders EncartaAudio for audio-kind item', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MediaRail(
          media: [_audioItem()],
          assets: _assets,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(EncartaAudio), findsOneWidget);
  });

  testWidgets(
      'renders EncartaVideo for other-kind item when ext is .wmv (corpus quirk)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MediaRail(
          media: [_videoOtherItem()],
          assets: _assets,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(EncartaVideo), findsOneWidget);
  });

  testWidgets('empty media list renders empty rail without crashing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MediaRail(media: const [], assets: _assets),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(EncartaImage), findsNothing);
    expect(find.byType(EncartaAudio), findsNothing);
    expect(find.byType(EncartaVideo), findsNothing);
  });

  testWidgets(
      'media title with inline markup renders plain text + italic, '
      'no raw <it> tag text visible', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MediaRail(
          media: [_audioItemWithMarkupTitle()],
          assets: _assets,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Raw tag strings must not appear anywhere.
    expect(find.textContaining('<it>'), findsNothing,
        reason: 'opening <it> tag must be stripped from title');
    expect(find.textContaining('</it>'), findsNothing,
        reason: 'closing </it> tag must be stripped from title');

    // The visible text "Henry V" (inside <it>) must be present at least once.
    // The card title row AND the figure's own unavailable-media text both render
    // the title, so two RichText widgets containing "Henry V" are expected.
    expect(
      find.textContaining('Henry V', findRichText: true),
      findsWidgets,
      reason: 'italic inner text must be visible',
    );

    // Verify the "Henry V" span is italic.
    final captionWidgets = find.byType(CaptionText);
    expect(captionWidgets, findsWidgets,
        reason: 'CaptionText must be used to render the title');

    bool hasItalicHenryV = false;
    for (final element in tester.elementList(captionWidgets)) {
      final richTexts = find.descendant(
        of: find.byElementPredicate((e) => e == element),
        matching: find.byType(RichText),
      );
      for (final rtElement in tester.elementList(richTexts)) {
        final rt = rtElement.widget as RichText;
        void checkSpan(InlineSpan span) {
          if (span is TextSpan) {
            if ((span.text ?? '').contains('Henry V') &&
                span.style?.fontStyle == FontStyle.italic) {
              hasItalicHenryV = true;
            }
            for (final child in span.children ?? <InlineSpan>[]) {
              checkSpan(child);
            }
          }
        }
        checkSpan(rt.text);
      }
    }
    expect(hasItalicHenryV, isTrue,
        reason: '<it>Henry V</it> must render as italic text');
  });
}

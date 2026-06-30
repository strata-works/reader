import 'dart:convert';
import 'dart:typed_data';
import 'package:xml/xml.dart';

/// One entry in the "In this article" outline (a section's title).
class OutlineEntry {
  const OutlineEntry({required this.title, required this.anchorId, required this.depth});
  final String title;
  final String anchorId;
  final int depth;
}

/// The section/sectiontitle tree, flattened in document order for the outline pane.
/// Task 5 fills this in; this is the minimal placeholder.
class EncartaOutline {
  const EncartaOutline(this.entries);
  final List<OutlineEntry> entries;
}

/// Parsed, render-ready model of one article body. Pure data over `package:xml`;
/// no IO, no SQLite, no encarta_data/encarta_assets deps.
/// The renderer walks [blocks] lazily.
class EncartaDoc {
  EncartaDoc._({required this.title, required this.blocks, required this.outline});

  final String title;
  final List<XmlElement> blocks;
  final EncartaOutline outline;

  /// Parse [xml] bytes (UTF-8) into an [EncartaDoc].
  ///
  /// Structure handled:
  ///   `<content refid=.. revision=..><text xml:space="preserve">…blocks…</text></content>`
  /// Fallback (no `<text>` wrapper):
  ///   `<content refid=.. revision=..>…blocks…</content>`
  ///
  /// Never throws — malformed or empty XML degrades to an empty [blocks] list.
  static EncartaDoc parse(Uint8List xml, {required String title}) {
    try {
      final source = utf8.decode(xml);
      if (source.trim().isEmpty) {
        return EncartaDoc._(title: title, blocks: const [], outline: const EncartaOutline([]));
      }
      final document = XmlDocument.parse(source);
      final content = document.rootElement; // <content>
      final texts = content.findElements('text').toList();
      final XmlElement body = texts.isNotEmpty ? texts.first : content;
      final blocks = body.childElements.toList();
      return EncartaDoc._(title: title, blocks: blocks, outline: _buildOutline(blocks));
    } catch (_) {
      return EncartaDoc._(title: title, blocks: const [], outline: const EncartaOutline([]));
    }
  }

  static EncartaOutline _buildOutline(List<XmlElement> blocks) {
    // Collect every id already present in the document to avoid collisions.
    final existingIds = <String>{};
    for (final b in blocks) {
      final bid = b.getAttribute('id');
      if (bid != null && bid.isNotEmpty) existingIds.add(bid);
      for (final d in b.descendantElements) {
        final id = d.getAttribute('id');
        if (id != null && id.isNotEmpty) existingIds.add(id);
      }
    }

    final entries = <OutlineEntry>[];
    // Dedicated counter — independent of how many outline entries have been
    // added, so ids are stable even when parent sections are titleless.
    var syntheticCounter = 0;

    void walk(Iterable<XmlElement> els, int depth) {
      for (final el in els) {
        if (el.name.local != 'section') continue;

        // Establish the anchor id. When no real id exists, stamp a synthetic
        // one directly onto the element so that allAnchorIds() and the future
        // section renderer both see the same value (single source of truth).
        final anchorId = () {
          final real = el.getAttribute('id');
          if (real != null && real.isNotEmpty) return real;
          // Find next free synthetic id.
          String candidate;
          do {
            candidate = 'sec-$syntheticCounter';
            syntheticCounter++;
          } while (existingIds.contains(candidate));
          existingIds.add(candidate); // reserve so later sections don't reuse it
          el.setAttribute('id', candidate);
          return candidate;
        }();

        final titleEls = el.findElements('sectiontitle').toList();
        final title = titleEls.isNotEmpty ? titleEls.first.innerText.trim() : '';
        if (title.isNotEmpty) {
          entries.add(OutlineEntry(title: title, anchorId: anchorId, depth: depth));
        }
        walk(el.childElements, depth + 1);
      }
    }
    walk(blocks, 1);
    return EncartaOutline(entries);
  }

  /// Every element `id` attribute in the body, in document order.
  /// Used for paraID deep-links and section/title outline anchors.
  Iterable<String> allAnchorIds() sync* {
    for (final b in blocks) {
      final bid = b.getAttribute('id');
      if (bid != null && bid.isNotEmpty) yield bid;
      for (final d in b.descendantElements) {
        final id = d.getAttribute('id');
        if (id != null && id.isNotEmpty) yield id;
      }
    }
  }
}

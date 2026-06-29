import 'package:flutter/widgets.dart';

/// Builds an inline image widget for an `inlinebmp`, given its raw `id` attribute
/// (verbatim) and `type` attribute (as int). Resolution depends on both: `type=27`
/// → `id` is an asset baggage_id (resolvable); `type=28` → `id` is an original
/// `NAME.DIB` filename (unresolvable → placeholder). The renderer passes both
/// through and NEVER interprets them; the host injects this.
typedef AssetResolver = Widget Function(String inlineId, int inlineType);

/// Called when an internal `xref` is tapped. [paraId] is the `paraID` deep-link, if any.
typedef XrefTap = void Function(int targetRefid, {String? paraId});

/// Returns the title for a refid, or null if the refid is absent from the corpus
/// (used for `inlinetitle` fallback and to suppress dead `xref` links).
typedef TitleForRefid = String? Function(int refid);

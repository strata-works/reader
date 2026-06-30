# float_column — maintenance/popularity check (open question §11.6)

**Decision:** Do NOT add `float_column` yet. Default media presentation remains
block-level (rail / between paragraphs), which is simpler and more
Encarta-faithful (spec §5, §6, §7). Tiny `inlinebmp` glyphs are the only truly
inline images and are handled by `EncartaAssets.inlineBmp` (no float needed).

**Check performed (date: 2026-06-30):**

| Field | Value |
|---|---|
| Latest version / last publish | 4.0.3 / ~15 months ago (≈ March 2025) |
| Likes | 83 |
| Pub points | 160 / 160 (perfect) |
| Downloads | 10.7 k (weekly average) |
| Dart 3 + null-safety | Yes — requires Dart SDK ≥ 3.5; WASM-ready |
| Declared platforms incl. macOS/desktop | Yes — iOS, Android, Web, Windows, macOS, Linux (all 6) |
| Only dependency | Flutter SDK (no third-party deps) |
| License | MIT |
| Publisher | ronbooth.com (verified) |
| Static analysis | No errors, warnings, lints, or formatting issues |
| Notable open issues on recent Flutter/desktop | None flagged in pub.dev scoring; GitHub not checked in-depth |

**Summary:** The package is technically sound — perfect pub points, all platforms
including macOS desktop, Dart 3 / null-safe, MIT license, zero static-analysis
issues, and minimal dependency footprint (Flutter only). The one concern is
recency: last published ~15 months ago, which is borderline against the
"actively maintained within ~12 months" adoption criterion from the spec.

**Adopt-it trigger (revisit only if all hold):**

1. A concrete design need for true text-wrap-around-image emerges (no such need
   identified as of this check).
2. At the time of adoption: the package has been published within the past
   12 months (re-verify — it is currently borderline at ~15 months).
3. Dart-3 / null-safe confirmed (currently satisfied).
4. Desktop (macOS) platform listed (currently satisfied).

If adopted, add `float_column` as a Flutter dependency to `encarta_assets`
(which already owns the media/asset layer) — **not** to `encarta_render`,
keeping the renderer dependency-free per architecture contract.

**Verdict:** CONDITIONALLY HEALTHY. The package's technical quality is excellent,
but re-check publish recency before depending on it. Block-level media stays the
default; do not add this dependency now.

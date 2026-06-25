# Encarta Reader UI — design spec

**Date:** 2026-06-25
**Repo:** `/Users/nexus/projects/experiments/strata/reader/` (this repo — new, sibling to `akc` and `quarry`)
**Status:** design approved in brainstorming; ready for implementation planning (`writing-plans`).

This spec is written to be **self-contained**: a fresh session started in this repo
should be able to implement from it without the original brainstorming transcript.
All input paths, data facts, and decisions are inline below.

---

## 1. Goal & framing

Build a **faithful-in-spirit reader** for the recovered Microsoft Encarta 2009
corpus — a **showcase/restoration demo** ("look what we recovered"), not a
shipped product and not a personal one-off. It should feel unmistakably
Encarta-era while rendering crisply on a modern machine.

**Fidelity target = "faithful in spirit, cleaned up"** (the layout DNA and
density of Encarta 2009, modern-crisp rendering — *not* pixel-cloning 2009
gradients/chrome). A **pixel-faithful recreation** is kept as a **documented
alternate research path**, not the build target.

**Platform:** native **desktop** app, **Flutter** (primary target macOS arm64;
Flutter keeps Windows/Linux/mobile open later). Flutter was chosen deliberately —
we expect to produce **reusable Flutter packages** out of this work (the renderer
above all), so the architecture is package-first, not a monolith.

**Guiding principle:** use existing packages where they earn their place; don't
reinvent wheels for no benefit; but don't contort the design to avoid a small,
well-bounded custom package when that's the right tool (the XML renderer).

---

## 2. The data layer (already complete — these are the inputs)

The ETL is **done** and lives in the **`quarry`** repo. The reader is **read-only**
over its outputs. Nothing in this project writes the corpus.

### Locations
- **DB:** `/Users/nexus/projects/experiments/strata/quarry/build/encarta.sqlite`
  (~718 MB) — open **read-only**.
- **Asset binaries:** `/Users/nexus/projects/experiments/strata/quarry/build/assets/`
  (~3.4 GB, 450,388 files), organized `image/ audio/ other/` with hashed filenames.
- **Future derived assets:** `…/build/assets_derived/` (PNG/mp3/mp4 from the
  transcode pipeline — see §9, NEX-395). May not exist yet; the reader must work
  without it.
- The app takes the **data directory as configuration** (default = the quarry
  build dir) so it isn't hard-wired to one machine.

### Schema (read-only)
```sql
article(refid INTEGER PRIMARY KEY, source TEXT, title TEXT, xml BLOB)
xref(refid INTEGER, target_refid INTEGER, PRIMARY KEY(refid,target_refid))
asset(baggage_id TEXT PRIMARY KEY, hash TEXT, kind TEXT, ext TEXT, path TEXT, source TEXT)
media(refid INTEGER PRIMARY KEY, "group" TEXT, title TEXT, credit TEXT, caption TEXT, source TEXT)
media_file(media_refid INTEGER, role TEXT, baggage_id TEXT, ext TEXT, PRIMARY KEY(media_refid,role))
article_media(article_refid INTEGER, media_refid INTEGER, PRIMARY KEY(article_refid,media_refid))
article_fts USING fts5(body, content='', contentless_delete=1, tokenize='unicode61')  -- CONTENTLESS
```

### Corpus facts (counts that shape the UI)
- `article`: **116,119** rows (UTF-8 `xml` bodies; **116,116 have titles**, 3 stubs don't).
  `source` tiers: CONTDLX 69,949 · CONTSTD 44,055 · CONTSTC 1,478 · CONTKDC 637.
- `xref`: **211,505** article→article links (the "Related" graph).
- `asset`: **409,937**. Kinds: `other` 346,465 (mostly WMV video + unclassified `.dib`),
  `audio` 53,120 (mostly WMA + some game `.wav`), `image` 6,481, `xml` 3,630,
  `caption` 233, `midi` 8. **Note:** image count is undercounted — many images are
  `.dib`/`.bmp` sitting in `other` (a known minor ETL misclassification). Resolve by
  path/ext, not by `kind`.
- `media`: **307,183**. `media_file`: **514,398** (100% resolve to a stored asset).
  `article_media`: **158,354** (article→media join works end-to-end).
- `media_file.role`: thumb 169,966 · ticon 155,830 · picon 154,714 · image 23,968 ·
  xml 3,627 · cc 2,796 (captions) · audio 2,442 · item/surround/background/mouseover (small).
- `media."group"`: maps 99,707 · article 41,885 · media 30,122 · quotation 29,706 ·
  weblink 29,148 · archive 18,707 · timetopic 13,061 · **home 8,594** · author 6,230 · …
  These are **media roles, not subject categories**. There is **no topical taxonomy**
  in the data. (`home` is a lead — possibly Encarta's real curated home-page content;
  validate before relying on it for the Home screen.)

### Renderer source = the article XML vocabulary
- Full spec: **`/Users/nexus/projects/experiments/strata/quarry/docs/VOCABULARY.md`**
  (32 elements, empirically surveyed over all 116k bodies). Read it before building
  `encarta_render`.
- Decision already made (NEX-393): **renderer = "option (b)"** — treat the XML as
  semantic source and build **our own** presentation. Do **not** port the embedded
  XSL (it lives as PE resources inside `MSENCXML.DLL`; high-effort, only reproduces
  2009 desktop styling).
- Key tags: `content`(root) → `text`(body) → `pkey`(dominant paragraph unit),
  `section`(nestable; `type` 4/5/6/7 = depth) + `sectiontitle`, `sec/seca/secb/secc`
  (outline enumerators I/A/B/C), `list`/`listitem`, `intro`/`headline`/`author`/
  `quote`/`example`, `rule`, `br`. Inline: `i b u smallcaps sub sup fs`(fractions,
  `type=2`)`fl cq item notation`. **`inlinetitle`** is an **empty placeholder** →
  substitute the resolved `article.title` (41,282 articles use it). **`xref`**: `type=8`
  (194k) internal `RefID`→`article.refid`; `type=9` external (carries `URL`); subtypes
  10/11/14/15/16/17 are internal `RefID`-bearing (render as links regardless); `paraID`
  = deep-link to a paragraph in the target. **`inlinebmp id="<NAME>.DIB"`** = inline
  image resolved by stem against the asset store. Bodies contain **no `msencdata:`
  URLs** — article media comes from the `article_media → media_file → asset` join, not
  inline.

---

## 3. Architecture — pub workspace, four units

A **pub workspace** (`resolution: workspace`, single shared lockfile) containing
three reusable packages + a thin app:

```
reader/                         (pub workspace root)
├─ pubspec.yaml                 (workspace: declares members)
├─ packages/
│  ├─ encarta_data/            read-only DB access (drift); typed queries
│  ├─ encarta_render/          XML → Flutter widget tree (the headline reusable pkg)
│  └─ encarta_assets/          asset resolution + media playback widgets
└─ app/
   └─ encarta_reader/          screens, navigation, theme; wires the packages
```

Dependency graph (`→` = depends on):
```
encarta_reader → encarta_render
              → encarta_data
              → encarta_assets
encarta_render → (only an injected AssetResolver / link callbacks — NO direct dep
                  on encarta_data or encarta_assets)
```

**Core invariant:** `encarta_render` never touches SQLite or `dart:io`. It is pure
presentation over a parsed model + injected callbacks (`AssetResolver`, `onXrefTap`,
`titleForRefid`). That keeps it a clean, reusable, golden-testable package.

**Read path for one article:**
1. `encarta_data.getArticle(refid)` → `{title, source, xmlBytes}`.
2. `encarta_data` also returns the article's media list (`article_media → media_file
   → asset`) and outbound xrefs (with target titles).
3. `encarta_render` parses `xml` → widget tree; for each `xref`/`inlinebmp`/media slot
   it calls the injected callbacks.
4. `encarta_assets` resolves each ref to a concrete file, **preferring** a derived
   file in `assets_derived/`, **falling back** to the original (with degradation).
5. App renders; `xref` taps push a new article route (with back/forward history).

---

## 4. `encarta_data` (read-only data access)

**Engine: `drift`** in **existing-database, read-only** mode (no migrations — we
don't own the schema). Use **`.drift` files** for raw SQL so we get **typed result
rows** and **build-time SQL validation** for the FTS/join queries (enable the `fts5`
analyzer extension). Drift runs on the `sqlite3` FFI, so FTS5/`bm25` are fully
available.

**Public API (typed):**
- `getArticle(refid) → Article{refid, title, source, xmlBytes}`
- `search(query, {limit, offset}) → List<SearchHit{refid, title, rank}>`
- `mediaForArticle(refid) → List<MediaItem{mediaRefid, role, group, title, caption,
  credit, assetPath, ext, kind}>`
- `outboundXrefs(refid) → List<XrefTarget{targetRefid, title}>`
- `titlesIndex({prefix, limit, offset}) → List<TitleRef>`  (A–Z browse)
- `randomArticle()` ; `featured()` (probes `media."group"='home'`)

**FTS constraint (important):** the FTS5 table is **contentless** (`content=''`), so
queries return **matching refids + `bm25` rank only** — `snippet()`/`highlight()`
return nothing. **Search snippets are generated by us** from `article.xml` (strip
tags around the first query hit). Assume **`article_fts` rowid == `article.refid`**;
**verify during implementation** and add a mapping if not.

**Testing:** pure Dart, no Flutter — unit tests against a small fixture `.sqlite`
(a few dozen articles) checked into the package.

---

## 5. `encarta_render` (XML → widget tree) — the centerpiece

Parse with **`package:xml`**; walk the document into a Flutter widget tree. **No HTML
round-trip** (we evaluated transforming to HTML + `flutter_widget_from_html` and
rejected it: we'd still hand-write the tag→HTML transform *and* custom factories for
the non-HTML tags, while inheriting an HTML engine's perf cliffs on long docs and
losing styling control — keep that route only as a documented fallback).

**Mapping (all 32 tags; see VOCABULARY.md for exact frequencies/attrs):**
- **Blocks → vertical widgets:** `pkey`→paragraph; `section`/`sectiontitle`→nested
  heading+body indented by `type` depth; `intro`/`headline`/`author`/`quote`/`example`
  →styled blocks; `list`/`listitem`→bulleted/ordered by `type`; `sec/seca/secb/secc`
  →outline enumerators (I / A / B / C prefixes); `rule`→divider; `br`→line break.
- **Inline → `TextSpan` runs:** `i b u smallcaps sub sup`→styled spans; `fs type=2`
  →fraction layout; rare `fl cq item notation`→graceful default styling.
- **`inlinetitle`** → substitute injected `article.title`.
- **`xref`** → tappable span/widget. `type=9`→external URL via `url_launcher`
  (system browser). All other types→internal link via injected
  `onXrefTap(targetRefid, paraID?)`. `paraID`→scroll-anchor in the target article.
  A `RefID` not present in the corpus → render as plain text (no dead link).
- **`inlinebmp id="X.DIB"`** → small inline image via `WidgetSpan`, resolved by stem
  through the injected `AssetResolver`.

**Stances:**
- **Never drop text.** Unknown/rare tags render their children with sensible defaults
  (optional debug "unstyled tag" highlight mode).
- **Theme decides pixels, renderer decides structure.** All concrete styling comes
  from `EncartaTheme` (§8); the renderer only assigns semantic roles.
- **Media is block-level** (see §6 / §7-Article): the renderer emits figures as
  block widgets (rail/full-width), not floated-in-prose. (`float_column` is the
  sanctioned tool if we ever want true text-wrap-around-image — see §6 — but block
  is the default.)

**Testing (most important package):** **golden + widget tests** over fixture XML
exercising every one of the 32 tags + xref/inlinebmp callbacks.

---

## 6. `encarta_assets` (resolution + media playback)

**Resolve:** given `(mediaRefid, role)` or an `inlinebmp` stem → `media_file →
asset.path` → file under the configured data dir. **Prefer** `assets_derived/` (PNG/
mp3/mp4); **fall back** to the original.

**Per format:**
- **Images (`.dib`):** Flutter decodes BMP, but a raw `.dib` lacks the 14-byte BMP
  file header. Provide a **runtime header-prepend shim** (cached) so images render
  **today**, before any transcode exists; use derived PNG when present.
- **Audio (WMA) / Video (WMV):** use **`media_kit`** (bundles libmpv) — it **plays
  WMV/WMA originals natively on desktop**. Consequence: the transcode pipeline
  (NEX-395) is a **size/portability/web optimization, not a prerequisite**. (`just_audio`/
  `video_player` were rejected — weaker on desktop and would force transcode first.)

**Widgets exposed:** `EncartaImage`, `EncartaAudio`, `EncartaVideo`, plus the
`AssetResolver` the renderer calls. `encarta_assets` owns `dart:io` + `media_kit`;
the renderer stays storage/format-agnostic.

**`float_column` note:** the pub package **`float_column`** solves CSS-`float`-style
text-wrap-around-image in native Flutter (single Flutter dependency, all platforms).
We default to **block-level media** (simpler, more Encarta-faithful), but `float_column`
is the **sanctioned tool** for any future inline-figure float — pending a quick
maintenance/popularity check before depending on it.

**Testing:** resolution + degradation tests with fake files (derived-present,
original-only, missing).

---

## 7. Screens & navigation (app: `encarta_reader`)

A persistent **Encarta-era top toolbar** (home button + search box) frames all
screens. Three screens, each chosen from mocked alternatives:

**Article view — three-pane (locked):**
- **Left:** "In this article" outline (the `section`/`sectiontitle` tree) + "Related"
  (outbound xrefs).
- **Center:** the rendered article body.
- **Right:** media rail (figures/images from `article_media`, with caption/credit).
- **Media is block-level** — no text-flows-around-image (Flutter `Text` can't float
  natively without `float_column`; we keep media in the rail / between paragraphs).
  Tiny `inlinebmp` glyphs are the only truly-inline images.

**Search — results + live preview (locked):**
- Two columns: **left** = ranked results (thumbnail from ticon/thumb role · title ·
  our generated snippet · tier badge); **right** = **live preview** of the selected
  article without leaving search. bm25-ranked, paginated.

**Home / Browse — Encarta-style portal (locked):**
- Hero featured article + a grid of featured tiles (lead: `media."group"='home'`) +
  an **A–Z browse strip** (→ `titlesIndex`) + prominent search. No subject categories
  (none exist in the data); entry points are featured / A–Z / search / random.

**Navigation: `auto_route`** (type-safe, codegen — pairs with drift's codegen) +
a small **history controller** for browser-like **Back/Forward** (the Encarta "Back"
behavior). Routes: `/` (Home), `/search?q=` (Search), `/article/:refid` (Article,
optional paragraph anchor for `paraID`). No web/deep-linking requirement (desktop
app), which is why `auto_route` over `go_router` is a clean DX call — **not** because
go_router is unmaintained (it is actively maintained by flutter.dev; the choice is
pure preference + no deep-link need).

---

## 8. Look & theme

**`EncartaTheme`** centralizes all pixel styling so package structure stays
theme-independent. **Faithful-in-spirit:** cool Encarta-era palette (blue/teal
toolbar chrome over a light content area), crisp readable typography with a
comfortable article measure, three-pane density that reads as "encyclopedia."
Period-evocative but clean — **not** pixel-cloning 2009 gradients.

**Alternate research path (documented, not built):** a **pixel-faithful** Encarta
2009 skin (exact chrome/fonts/icons). If ever pursued, the 2009 XSL can be pulled
from `MSENCXML.DLL` resources for reference.

---

## 9. Scope boundaries

**In scope (this spec):** the Flutter reader — the three screens, the four
packages, image rendering (incl. `.dib` shim), and **audio + video playback of
originals via `media_kit`**.

**Separate spec — transcode pipeline (quarry, NEX-395):** `.dib`→PNG, WMA→AAC/Opus,
WMV→H.264 mp4. It is a **parallel/optional** workstream: the reader prefers derived
assets when present but **never blocks** on it (media_kit plays originals; the `.dib`
shim covers images). Lives in `quarry` (Python/ffmpeg ETL), not here.

**Future spec — games:** we recovered MindMaze **assets** (`MINDMAZE.EIT`: 137
assets — 35 `.wav`, 5 MIDI, 97 other incl. `Area0`–`Area8` `.lst` data + `.dib` art),
but **not a playable game** — making it playable needs (1) reverse-engineering the
`.lst` format and (2) rebuilding the game loop in Flutter. **Timeline is not even
extracted** (`TIMELINE.EIT` fails in the LIT path). Games are explicitly **out of
this spec**, a follow-on once the reader exists.

**Also future (not now):** dictionary (NEX-397), REL*/related expansion (NEX-396),
mobile/web targets (Flutter keeps them open).

---

## 10. Cross-cutting concerns

**Graceful degradation (never crash, never blank):**
- Missing/unresolved asset → placeholder + caption/credit still shown.
- Un-playable media (rare with media_kit) → poster + "media unavailable."
- Missing title (the 3 stubs) → fall back to first `headline`, else the refid.
- Broken `xref` target (refid absent) → plain text, not a dead link.
- Malformed/unknown XML → render what parses, default-style unknowns, never drop text.

**Performance (116k corpus, some long articles):** paginated FTS results; article
body rendered lazily (builder over top-level blocks); decoded-image + `.dib`-conversion
caches; `media_kit` players lazy-initialized.

**Testing summary:** `encarta_data` unit tests vs fixture `.sqlite`; `encarta_render`
golden/widget tests over all 32 tags; `encarta_assets` resolution/degradation tests;
app integration smoke (open article → search → tap xref → Back).

---

## 11. Open questions to validate during implementation

1. **FTS rowid == `article.refid`?** Verify; add a mapping table/query if not.
2. **`media."group"='home'`** — is it Encarta's real curated home content? Validate
   before using it to populate Home portal tiles (fallback: featured = high-media or
   notable articles).
3. **Thumbnail role choice** — which of `ticon`/`thumb`/`picon` for search thumbnails
   and the article hero; confirm against real assets.
4. **`xref` subtypes** 10/11/14/15/16/17 exact semantics (all render as links
   regardless; refine labels if a distinction emerges).
5. **`.dib` classification** — assets are `kind=other`; resolve by path/ext/stem, not
   `kind`. (Optional upstream ETL fixup in quarry.)
6. **`float_column`** maintenance/popularity check before depending on it.

---

## 12. References

- Tag vocabulary: `quarry/docs/VOCABULARY.md`
- ETL status: `quarry/docs/REPORT-2026-06-24.md`
- Decoder repo: `akc` (`strata-works/akc`) · ETL repo: `quarry` (`strata-works/quarry`)
- Memory: `native-lzx-and-pipeline-state.md` (data-layer state + resume point)
- Linear: NEX-393 (vocab, Done), NEX-394 (ETL, media/titles/encoding closed),
  NEX-395 (transcode — the separate pipeline spec), NEX-396 (search/REL*),
  NEX-397 (dictionary).

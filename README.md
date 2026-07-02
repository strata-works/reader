# Encarta Reader

A faithful-in-spirit desktop reader — and game — for the recovered **Microsoft Encarta 2009** corpus. It renders the encyclopedia's articles, media, and cross-references, and plays a rebuilt version of Encarta's **MindMaze** castle trivia game, all from the decoded content produced by the sibling extraction pipeline.

## Purpose & Disclaimer

This project is for educational, archival, interoperability, and digital-preservation research. It is **not affiliated with, endorsed by, or sponsored by Microsoft**. The **repository contains only reader/renderer code** — it does not include or redistribute any Encarta content. At runtime the app reads and displays content from a corpus **you supply and build yourself** (see [Data source](#data-source)); you are responsible for having the legal right to that data. The software is provided as-is, without warranty.

## What it is

A Dart **pub workspace** (single shared lockfile) split into focused packages, plus a Flutter macOS app:

| Unit | Responsibility |
|---|---|
| `packages/encarta_data` | Read-only, typed access to the corpus SQLite DB (drift over sqlite3): articles, FTS5 full-text search, the cross-reference graph, media, and the MindMaze question bank. Pure Dart. |
| `packages/encarta_render` | Renders article XML into Flutter widgets — the ~32 Encarta body tags (sections, paragraphs, xrefs, inline bitmaps, fractions, lists…). Deliberately isolated: no io/data/assets/sqlite imports. |
| `packages/encarta_assets` | Asset resolution + media playback (`media_kit`); the `.dib` bitmap shim; the MindMaze art transcode tool. The only package allowed to touch `dart:io` / `media_kit`. |
| `packages/encarta_mindmaze` | Pure-Dart, **headless game core** for MindMaze: the maze graph, characters, question selection, and the `GameSession` state machine (lives + retry, reach the goal room to win). Zero Flutter/sqlite deps. |
| `app/encarta_reader` | The Flutter macOS app: a home portal, full-text search, a three-pane article reader, and the `/mindmaze` game screen. |

## Data source

The reader **consumes** the build artifacts of the companion `quarry` ETL pipeline (which decodes the raw `.AKC`/`.EIT`/LIT containers via the portable `strata-akc-portable` decoder):

- `encarta.sqlite` — ~116k articles + contentless FTS5 + xref graph + media metadata + **8,020 MindMaze questions**.
- `assets/` — ~410k content-addressed, deduped asset binaries (images, audio, video).
- `assets_derived/` — transcoded/derived assets (e.g. the MindMaze art PNGs; see below).

By default the app reads these from `quarry/build` (see `packages/encarta_assets/lib/src/asset_config.dart`). Point `AssetConfig` at your own build dir if it lives elsewhere.

## Running

Prerequisites: the Flutter SDK, macOS (the app currently targets macOS), and a built `encarta.sqlite` + `assets/` from the `quarry` pipeline.

```bash
dart pub get                       # from the workspace root
cd app/encarta_reader
flutter run -d macos               # or: flutter build macos
```

The home portal offers featured/random articles, A–Z browse, full-text search, and a **Play MindMaze** button.

### MindMaze art (one-time)

MindMaze room backdrops and character sprites are transcoded from the recovered `.dib` art into PNGs (sprites get their cyan color-key turned transparent). Generate them once:

```bash
cd packages/encarta_assets
dart run tool/transcode_mindmaze_art.dart   # writes <build>/assets_derived/mindmaze/*.png
```

Without this step the game still runs — rooms just show labeled placeholders instead of art.

## MindMaze

MindMaze is Encarta's first-person castle trivia game, rebuilt in phases as its own spec → plan → implementation cycles (see `docs/superpowers/`):

1. **Decode** (in `quarry`) — parse `MINDMAZE.DB` into `mm_question`/`mm_answer` tables.
2. **Data API** — `EncartaDb.mindmazeQuestions(area)` serves a castle wing's questions.
3. **Game core** (`encarta_mindmaze`) — the headless engine + a small authored maze.
4. **Playable room UI** — the `/mindmaze` screen: answer a character's question, walk through doors, win or lose.

Later phases (full 9-wing castle, audio, animation, end screens) build on the same engine.

## Testing

Each package is test-first (`flutter test` / `dart test`). From the workspace root you can run a package's suite, e.g.:

```bash
flutter test app/encarta_reader
dart test packages/encarta_mindmaze
```

## Development docs

Design specs and implementation plans live under `docs/superpowers/specs/` and `docs/superpowers/plans/`.

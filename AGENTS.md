# AGENTS

## Current Rules
- All new feature work must use Flutter.
- UI and business state must remain strictly separated.
- Before every new modification, read this file and continue with the existing architecture.
- After every modification, run `flutter analyze` and keep the project analyzer-clean.

## Layout Notes
- The app uses a landscape dashboard shell.
- Current implementation has moved away from whole-page global scaling.
- Shared shell areas such as left navigation and top bar should remain reusable and stable.

## Implemented / In Progress
- Auth pages: migrated to Flutter 2.0 UI.
- Home page: migrated to Flutter 2.0 UI baseline.
- AI chat, courseware, cloud drive, video center, music companion, notes, collection, recording system: all have Flutter 2.0 pages connected.
- Smart campus: currently kept in a stable placeholder-safe version to avoid project-wide breakage before the full rebuild.
- Dictation secondary page: implemented with real menu + textbook APIs and 2.0 layout.
- Sight singing / music theory / answer questions / voice / instrumental secondary pages:
  - unified under `lib/features/study_catalog/`
  - share the dictation 2.0 visual structure
  - use 1.0 menu/textbook API rules and route branching
  - router now points these routes to real Flutter pages instead of placeholders
- Music play tertiary page:
  - implemented under `lib/features/music_play/`
  - route `/musicPlay` now points to a real Flutter page
  - detail data uses 1.0 `textbookDetail` API rules
  - long-audio playback uses `media_kit`
  - bottom piano interaction reuses the existing Flutter short-audio ecosystem via `flutter_soloud`
  - page startup must not block on full piano/metronome asset preload
  - musicPlay should warm up piano audio in the background and load textbook detail first

## Technical Direction
- For secondary study pages, prefer a reusable catalog architecture instead of duplicating page logic.
- Shared responsibilities are split into:
  - `data/`: API repository
  - `state/`: route args, state model, controller
  - `ui/`: page and presentational widgets
- Route-specific behavior such as target page parameters should be configured, not hard-coded per screen when possible.

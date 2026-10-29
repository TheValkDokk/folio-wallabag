# Contributing to Folio

Folio is a small app with a narrow job: read your own wallabag library, on your
phone, without a feed. Patches that keep it small and honest are welcome.

## Run it

```bash
flutter pub get
flutter analyze
flutter run
```

You do not need a wallabag server to develop. A local API double ships in the
repo:

```bash
python3 tool/mock_wallabag.py
flutter run --dart-define=MOCK_CONNECT=http://127.0.0.1:8000
```

Useful debug hooks: `--dart-define=OPEN_ENTRY=101` (open a reader),
`--dart-define=OPEN_SETTINGS=true` (open settings). Both are compiled out unless
the define is set.

## Rules of the house

- **No telemetry, no analytics, no third-party SDKs.** The only network calls are
  to the user's wallabag instance. A PR that adds tracking will be closed.
- **No account system.** Folio has no backend of its own, and that is the point.
- **Offline is the default, not a mode.** Any new action must survive airplane
  mode: write locally, queue the remote call, replay on sync.
- Keep the design language: paper, ink, one deep-green accent, serif headings.
  No gradients, no confetti, no streaks.
- `dart format` before committing; avoid reformatting files you did not change.

## Pull requests

1. Small, focused commits with a sentence explaining *why*.
2. Say what you tested and on which platform — "it compiles" is not a test.
3. If you touched the reader, include a before/after screenshot.
4. New dependencies need a reason; the current list is deliberately short.

## Good first issues

- Paginated archive and starred lists
- Server-side search (`/api/entries.json?term=`)
- Share extension (iOS) / share intent (Android)
- Tag editing
- Translations (all strings currently live in the widgets that use them)

## License

By contributing you agree your work is released under GPL-3.0.

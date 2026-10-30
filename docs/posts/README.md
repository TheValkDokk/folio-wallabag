# Launch copy

Publish-ready posts for Folio. Same facts, different voice per channel — do not
cross-post identical text, it reads as spam and detanks on Reddit.

| file | where | when |
| --- | --- | --- |
| `wallabag-forum.md` | wallabag Discussions → Showcase + Matrix `#wallabag` | day 1 — highest intent |
| `devto-wallabag-client.md` | dev.to (also fits Hashnode / Medium) | day 1–2 |
| `show-hn.md` | Hacker News | Tue–Thu, 08:00–10:00 ET |
| `reddit.md` | r/selfhosted (megathread comment only), r/wallabag, r/androidapps | one sub per day |
| `devto-offline-sync.md` | dev.to / r/FlutterDev | after the first post lands |
| `social-thread.md` | Mastodon (Bluesky without tags) | launch day |

Post order and reasoning live in [`../LAUNCH.md`](../LAUNCH.md). Short version:
wallabag community first, HN second, Reddit after, stores last.

## Rules

- Disclose authorship everywhere. Every community in this list punishes stealth
  promotion harder than self-promotion.
- One post per subreddit per day. r/androidapps requires the `[Dev]` tag and a
  free/no-ads statement — both are in `reddit.md`.
- Never ask for upvotes. Reply to every comment for six hours; that is what
  converts, not the submission.
- Read each sub's rules first. r/selfhosted removes young-project posts outside
  its New Project Megathread — a removal there costs more than waiting.
- Link the repo, not the release, on forum/HN posts — a release page hides the
  story and the licence.

## Facts these posts rely on (keep them true)

- GitHub repo `TheValkDokk/folio-wallabag`, GPL-3.0, public.
- Verified against a real wallabag 2.6.15 instance, not only the bundled mock.
- APKs: split-per-ABI + universal, published to the rolling `main-latest`
  pre-release on every push to `main`, with `SHA256SUMS.txt`.
- iOS builds from source; no App Store listing.
- Known gaps: no share extension, archive pagination, local-only search, tag
  editing display-only.

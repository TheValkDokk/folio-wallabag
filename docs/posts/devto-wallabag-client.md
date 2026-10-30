---
title: "I got tired of my self-hosted read-later app, so I wrote a new client"
published: false
description: "Wallabag 2.6.15 in Docker, a Flutter client, and four bugs that a mock server could never have caught. Folio is GPL-3.0, offline-first, and speaks only the public v2 API."
tags: flutter, selfhosted, opensource, privacy
cover_image: https://raw.githubusercontent.com/TheValkDokk/folio-wallabag/main/docs/screenshots/home.png
canonical_url: https://github.com/TheValkDokk/folio-wallabag
---

Pocket is gone. If you were one of the people who exported your archive and stood
up [wallabag](https://wallabag.org) instead, you did the right thing — and then
you hit the client problem.

The official iOS app went closed-source with paid tiers this year. The Android
client works, in the way a filing cabinet works. So I wrote
**[Folio](https://github.com/TheValkDokk/folio-wallabag)**, a Flutter client for
iOS and Android, GPL-3.0, and it exists because of one sentence:

> A reading list is a decade of attention. It should look like a book, not a feed.

## What it does

Reader first, everything else second.

- **Typography you control**: 15–30 pt, line height, serif or sans, and Paper /
  Sepia / Night pages. Reading position is saved per article as percent plus
  scroll offset, so you come back to the paragraph, not the top.
- **Read aloud** with the system voice.
- **Unread / Starred / Archive / Everything** with live counts, swipe to
  archive, long-press for star, original, delete.
- **Offline first**: the list, every article you've opened, and every action are
  local. Archive, star and delete are optimistic and queued; the queue replays
  on the next sync. Airplane mode doesn't lose intent.
- **Auth** is OAuth password grant (or paste an existing token). The password is
  used once and never stored — only the token is.
- **Demo mode** with four sample articles, so the app is explorable before you
  own a server.

No account with me, no analytics, no server of mine that can be shut down and
take your library with it. The only outbound requests go to the instance you
configure.

Install: APKs are on the
[releases page](https://github.com/TheValkDokk/folio-wallabag/releases). iOS
builds from source for now — no App Store listing yet, and I'd rather say that
than pretend otherwise.

## The part worth reading: my mock server lied to me four times

I built the whole sync path against a small mock wallabag I wrote myself
(`tool/mock_wallabag.py`). It was pleasant, fast, and worthless as evidence —
it was written by the same person who wrote the client, so all it could ever
prove was that the client agrees with itself.

So I ran the real thing: wallabag 2.6.15 in Docker on SQLite, created a user and
an OAuth client, saved real articles, and pointed the app at it. Four bugs fell
out, none of which the mock could produce:

**1. Dates are ISO strings, not epoch ints.** Real wallabag returns
`created_at: "2026-10-30T04:36:18+0000"`. My parser did `as num?` because the
mock used integers. The list rendered empty with a red banner. One coercion
helper now accepts `num`, ISO-8601, and `"0"`/`"1"`.

**2. Star and archive returned 200 OK and changed nothing.** This is the worst
failure mode I know of. Wallabag's PATCH endpoint reads **form** parameters
named `archive` and `starred`; I was sending JSON with `is_starred`. The server
accepted it, returned 200, and ignored it. If I hadn't reloaded the entry from
the server, I would have shipped a client whose star button is decorative. The
test now asserts the entry *changed*, not that the request returned.

**3. The reader showed a title and the word END.** `openFull()` replaced the
entry in the store instead of filling in the caller's entry, so the open screen
kept pointing at the pre-fetch copy. Classic object identity bug, invisible
until you have real content.

**4. There was no title at all.** Wallabag strips the `h1` from extracted
content and stores it separately, so rendering `content` alone gives you an
article with no headline.

The generalizable lesson: an integration test written by the same person as the
code is a unit test wearing a costume. If you maintain a self-hosted service and
maintain a client for it, run the client against the real binary once before
shipping. It cost me an afternoon and it saved the release.

## How it's built

- Flutter 3.44, target iOS 16+ and Android 8+, no state-management framework
  wars — a single `ChangeNotifier` store with a JSON snapshot in
  `SharedPreferences`.
- A tiny API layer over wallabag's v2 endpoints (OAuth, entries, PATCH, DELETE).
- Reader is a `WebView` with injected CSS, so the typography controls are a
  stylesheet swap and the article stays offline-cached.
- CI builds split-per-ABI APKs and a universal APK on every push to `main`, with
  checksums, published to a rolling `main-latest` release. Version tags cut a
  permanent release.
- `python3 tool/mock_wallabag.py` still ships in the repo — it is genuinely
  useful for UI work, as long as you don't confuse it with integration testing.

## Known gaps, stated plainly

No share extension yet (adding a link works from the in-app sheet). Search runs
over the local cache, not the server's index. The archive box shows the first
page fetched plus what you've touched locally. Tag editing and highlights are
display-only. F-Droid needs fastlane metadata. These are open issues, not
surprises.

## If you run wallabag

I'd rather have your bug reports than your stars. Specifically: what breaks on
your instance version, what the Android client does that I don't, and whether
share-sheet capture is the thing that would make you use this daily — because
that's what I'll build next.

- Repo: https://github.com/TheValkDokk/folio-wallabag
- APKs: https://github.com/TheValkDokk/folio-wallabag/releases
- License: GPL-3.0. Not affiliated with the wallabag project; it speaks the
  public v2 API only.

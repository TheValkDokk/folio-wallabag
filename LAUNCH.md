# Launch plan

How to get Folio in front of the people who actually have a wallabag server.

## Positioning

> **Folio — a calm, offline-first wallabag reader for iOS and Android.**
> No account, no feed, no telemetry. Your server, your articles, your phone.

The hook is not "another Flutter app". It is: **Pocket is gone, wallabag is the
durable answer, and its clients are the weak link.** Every post should lead with
the reader experience (screenshots) and the privacy posture, then the technical
detail.

Who this is for:

1. Self-hosters already running wallabag (they have the pain today).
2. Pocket refugees who moved to wallabag and hate the official app.
3. Flutter/Dart developers (secondary — they star, they don't convert).

## Assets

- Repo: https://github.com/TheValkDokk/folio-wallabag
- Release with APKs: https://github.com/TheValkDokk/folio-wallabag/releases/tag/v1.0.0
- Screenshots: `docs/screenshots/` (welcome, home, reader, settings)
- A 20-second screen recording beats all of them — record: open list → swipe
  archive → open article → change type size → night page.

## Order of operations

Do not fire everything at once. Each channel has a different half-life, and a
repo with zero stars converts badly. Sequence over ~3 weeks.

### Day 1 — make the repo legible

- [x] README with screenshots, install path, honest limits
- [x] LICENSE (GPL-3.0), CONTRIBUTING, CI
- [ ] Record the 20s demo GIF, put it at the top of the README
- [ ] Add 8–10 "good first issue" tickets (archive pagination, share intent,
      server search, tag editing) so visitors see a live project, not a dump
- [ ] Pin the repo on your GitHub profile

### Day 2 — the wallabag community first (highest intent, lowest noise)

These are the only people who can use the app on day one.

1. **wallabag forum / GitHub Discussions** (`wallabag/wallabag` → Discussions →
   Showcase). Post the screenshots, say what is missing, ask what they want next.
   Be a user of their software, not a marketer.
2. **Matrix/IRC** `#wallabag` — one short message with the link, then answer
   questions. No repeat posting.
3. **awesome-selfhosted** — PR adding Folio under *Read-it-later* next to
   wallabag. Follow their CONTRIBUTING exactly; a bad PR gets closed fast.

Copy for the forum:

> I run wallabag for my own reading and got tired of the client situation, so I
> built one: Folio, a Flutter client for iOS and Android, GPL-3.0.
>
> Offline-first (writes queue and replay), per-article typography, reading
> position saved per article, TTS, and no account or telemetry anywhere — it
> only talks to the server you configure. APKs are in Releases; iOS builds from
> source.
>
> It speaks the public v2 API only, so it should work with any 2.4+ instance.
> Two things I know are missing: share-sheet capture, and paginated archive.
> What else would you need before using it daily?

### Day 3–4 — Show HN (the single biggest lever)

- **When**: Tuesday–Thursday, 08:00–10:00 US Eastern. Not Friday, not a weekend.
- **Title** (pick one, keep it plain — HN punishes marketing):
  - `Show HN: Folio – an open-source wallabag reader for iOS and Android`
  - `Show HN: I built a calm client for my self-hosted reading list`
- **URL**: the repo.
- **First comment** (post immediately, it is where the real discussion happens):

> I self-host wallabag and the client gap kept me on a browser tab. The official
> iOS app went closed-source/paid this year and the Android one is, charitably,
> dated — so this is a Flutter client that does the boring things well:
>
> - offline-first: the list, opened articles and every write are local; archive/
>   star/delete queue and replay
> - reader with real typography controls (size, leading, serif/sans, paper/
>   sepia/night), position saved per article, TTS
> - auth is OAuth password grant or a pasted token; the password is never stored
> - no account, no analytics, no server of mine
>
> It only speaks the public v2 API. Built with a small mock wallabag server
> (`tool/mock_wallabag.py`) so I could test the sync path without PHP+MySQL —
> happy to talk about that.
>
> Known gaps: no share extension, archive pagination, local-only search. I would
> rather ship those with feedback than guess.

Rules that matter: reply to every comment for the first six hours, never ask for
upvotes, never repost the same link within a week, and take criticism about the
"why not just use the official app" question head-on (closed source, paid tiers,
no offline-first guarantees).

### Day 5 — Reddit (one sub per day, disclose authorship in the title or first line)

- `r/selfhosted` — "I built an open-source client for my wallabag server
  (iOS/Android, Flutter)" — this sub is the best fit by a wide margin.
- `r/wallabag` — small, high intent; short post, link, offer to fix bugs.
- `r/androidapps` — read their dev rules first: they require the `[Dev]` tag and
  a free/no-ads statement. APK link, not Play Store.
- `r/FlutterDev` — different post: "What I learned building an offline-first
  sync queue in Flutter" with the repo in the comments. Framed as engineering,
  not promotion.
- `r/opensource`, `r/privacy` — smaller; post after the others land, with a
  privacy angle ("your reading list is a decade of attention").

### Day 6–7 — distribution that keeps working after launch week

- **IzzyOnDroid** (fastest Android store): open a packaging request on
  `IzzyOnDroid/repo` with the release APK. Usually days, not months.
- **F-Droid**: needs `fastlane/metadata/android/en-US/` (title, short/full
  description, changelogs, screenshots) and a `metadata/` recipe. Slower, but it
  is where the self-hosted Android crowd actually browses. Do it after the
  share-intent feature, so the listing is not immediately stale.
- **Mastodon** (`#selfhosted #wallabag #opensource #flutter`), Bluesky, X — one
  thread with the GIF, tag the wallabag account.
- **Product Hunt** — optional. Only worth it with a polished GIF, a tagline and
  someone answering comments all day. Do it after 100+ stars, not before.
- **Answer old threads**: the Pocket-alternatives HN thread and Reddit threads
  from the shutdown are still read. A genuinely useful comment ("here is what I
  built, here is what it lacks") is fine; a bare link is spam.

## What "success" looks like

Track weekly, not hourly:

- GitHub stars (vanity) and **release asset downloads** (real installs)
- Issues opened by strangers (the only proof people are using it)
- Wallabag forum replies (the audience you actually want)
- iOS build reports ("it compiled on my machine") — that is your TestFlight
  waitlist

## If it gets traction

1. Ship the share extension first — it is the #1 reason people bounce back to
   Pocket-style apps.
2. Then archive pagination and server search.
3. Then ask the wallabag project whether they want to link to it from their
   clients page (they have a third-party clients list).
4. TestFlight, then the App Store — at that point the build quality bar is the
   review, not stars.

## Things not to do

- Don't post the same link to five subs on the same day; Reddit treats it as
  spam and mods check post history.
- Don't claim it is "better than the official app" in the title. Show the reader
  and let people say it.
- Don't add analytics "just to measure the launch". It would contradict the
  entire pitch.

# wallabag forum / GitHub Discussions

Target: `wallabag/wallabag` → Discussions → Showcase. Also the Matrix/IRC
`#wallabag` channel (one short message, then answer questions; no reposting).

This is the highest-intent audience that exists for this app — they already run
the server. Post as a user of their software, not as a marketer.

## Title

```
Folio — a Flutter client for wallabag (iOS + Android), offline-first, GPL-3.0
```

## Body

> I run wallabag for my own reading and got tired of the client situation, so I
> built one: Folio, GPL-3.0, one Flutter codebase for iOS and Android.
>
> - offline-first: the list, opened articles and every write are local; archive/
>   star/delete are optimistic and the queue replays on the next sync
> - reader typography: 15–30 pt, line height, serif/sans, paper/sepia/night,
>   position saved per article, read-aloud via the system voice
> - auth: OAuth password grant (password used once, never stored) or paste an
>   existing token
> - no account, no telemetry, no intermediary server — it only talks to your
>   instance
> - demo mode with four sample articles so it's explorable without a server
>
> It speaks the public v2 API only, so 2.4+ should work. I verified it against a
> real 2.6.15 container (SQLite) as well as the bundled mock — that's where I
> found that `PATCH /api/entries/{id}.json` silently ignores JSON bodies: it
> wants form params `archive` / `starred` and still answers `200 OK`. Worth
> knowing if anyone else is writing a client.
>
> Missing, and I'd rather say it than let you find out: no share extension
> (adding a link works from the in-app sheet), archive shows the first page plus
> local changes, search is over the local cache, tag editing is display-only.
>
> What would you need before using it daily? Share-sheet capture and pagination
> are next on my list; I'd rather build in your order than mine.
>
> Repo and APKs: https://github.com/TheValkDokk/folio-wallabag

## Follow-up answers

**"Which API version / compatibility?"**
> Public v2, tested on 2.6.15. It doesn't touch anything v2-specific that changed
> recently, so 2.4/2.5 should behave; if it doesn't, the error message should
> say which field failed and I'll fix it fast.

**"Why not contribute to the official Android app instead?"**
> Different platforms mattered to me — one Flutter codebase covers the iOS gap,
> which is where the closed-source/paid shift left people with nothing. Happy to
> see the API client (`lib/wallabag.dart`) reused elsewhere.

**"Does it sync reading progress across devices?"**
> Not yet. Position is local per device. Wallabag's API doesn't expose a shared
> progress field I can trust, so doing it properly means annotations or a small
> server-side addition — genuine design work, not a checkbox.

**"F-Droid?"**
> Planned; needs fastlane metadata and a stable signing key, which the CI now
> produces. IzzyOnDroid first, since it's days rather than months.

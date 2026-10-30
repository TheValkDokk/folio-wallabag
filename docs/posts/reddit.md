# Reddit posts

One subreddit per day. Disclose authorship in the title or the first line —
r/androidapps requires the `[Dev]` tag and a free/no-ads statement.

---

## r/selfhosted (best fit by a wide margin)

**Title**

```
I built an open-source client for my wallabag server (iOS/Android, Flutter)
```

**Body**

> I run wallabag for my own reading and got tired of the client situation, so I
> wrote one: Folio, GPL-3.0, Flutter, one codebase for both platforms.
>
> What it does:
> - offline-first — the list, opened articles and every action are local;
>   archive/star/delete queue and replay when you're back online
> - reader with real typography controls (size, leading, serif/sans,
>   paper/sepia/night), reading position saved per article, TTS
> - OAuth password grant or paste a token; password used once, never stored
> - no account with me, no analytics, no telemetry — it only talks to your server
>
> Public v2 API only, so any 2.4+ instance should work. APKs are in Releases;
> iOS builds from source (no App Store listing).
>
> The honest part: I tested it against a mock I wrote myself, which proved
> nothing. When I finally ran it against wallabag 2.6.15 in Docker, four real
> bugs appeared — including a PATCH that returned `200 OK` and changed nothing,
> because star/archive are form params in wallabag's API, not JSON. If you're
> writing your own client against that API, learn from my afternoon.
>
> Known gaps: no share extension yet, archive pagination, search is local-only,
> tag editing is display-only. What would you need before using it daily?
>
> Repo: https://github.com/TheValkDokk/folio-wallabag

**First comment (post immediately)**

> The mock-server story in more detail, since a few of you will ask:
>
> 1. `created_at` is an ISO string (`2026-10-30T04:36:18+0000`), not an epoch
>    int — my parser did `as num?` and the list came back empty.
> 2. `PATCH /api/entries/{id}.json` wants form-encoded `archive` / `starred`.
>    Send JSON with `is_starred` and you get 200 OK and no change. My test now
>    asserts the entry changed, not that the request succeeded.
> 3. `openFull()` replaced the store entry instead of filling the caller's, so
>    the reader showed a title and "END".
> 4. wallabag strips the `h1` from extracted content and stores it separately —
>    render `content` alone and the article has no headline.
>
> Also: `python3 tool/mock_wallabag.py` ships in the repo and is genuinely handy
> for UI work. Just don't call it an integration test.

---

## r/wallabag (small, high intent — short)

**Title**

```
A Flutter client for wallabag — offline-first, GPL-3.0, APKs in Releases
```

**Body**

> Long-time wallabag user here. I got frustrated with the client situation and
> wrote Folio: iOS + Android from one Flutter codebase, public v2 API only.
>
> Offline-first (writes queue and replay), per-article typography, saved reading
> position, TTS, no telemetry. Tested against a real 2.6.15 instance, not just a
> mock — that's where the silent-PATCH bug got caught.
>
> Missing, and I know it: share-sheet capture, paginated archive, server-side
> search. If one of those is the blocker for you, say which, because that's the
> build order.
>
> https://github.com/TheValkDokk/folio-wallabag

---

## r/androidapps (`[Dev]` tag + free/no-ads statement required)

**Title**

```
[Dev] Folio — a free, ad-free, open-source wallabag reader (no Play Store)
```

**Body**

> Folio is a client for [wallabag](https://wallabag.org), the self-hosted
> read-later server. Free, no ads, no in-app purchases, no analytics, GPL-3.0.
> Not on the Play Store: APKs are on GitHub Releases.
>
> You need your own wallabag instance (or a demo mode to look around). It's for
> people who'd rather own their reading list than rent it.
>
> Android 8+, arm64 and universal APKs, checksums published with each build.
> Built with Flutter; offline-first, so it works on the underground.
>
> Repo / APKs: https://github.com/TheValkDokk/folio-wallabag/releases

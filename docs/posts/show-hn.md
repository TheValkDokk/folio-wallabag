# Show HN

**Submit**: Tue–Thu, 08:00–10:00 US Eastern. URL field = the repo, never the
release. Post the first comment immediately after submitting.

## Title

```
Show HN: Folio – an open-source wallabag reader for iOS and Android
```

Alternate (plainer, often scores better):

```
Show HN: A Flutter client for my self-hosted reading list
```

## URL

```
https://github.com/TheValkDokk/folio-wallabag
```

## First comment

> I self-host wallabag and the client gap kept me on a browser tab. The official
> iOS app went closed-source with paid tiers this year and the Android one is,
> charitably, dated — so this is a Flutter client that does the boring things
> well:
>
> - offline-first: the list, opened articles and every write are local; archive/
>   star/delete queue and replay on the next sync
> - reader with real typography controls (15–30 pt, leading, serif/sans, paper/
>   sepia/night), reading position saved per article, TTS
> - auth is OAuth password grant or a pasted token; the password is never stored
> - no account, no analytics, no server of mine
>
> It speaks the public v2 API only, so any 2.4+ instance should work.
>
> The interesting part was testing it. I built the sync path against a mock
> wallabag I wrote myself, which proves only that the client agrees with itself.
> Against a real 2.6.15 container, four bugs fell out: ISO date strings where my
> parser expected epoch ints, a PATCH that returned 200 OK and changed nothing
> because star/archive are *form* params not JSON, a reader showing title + END
> because openFull() replaced the entry instead of filling it, and no title at
> all because wallabag stores the h1 separately from the extracted content.
>
> Known gaps: no share extension, archive pagination, search is local-only.
> I'd rather ship those with feedback than guess.
>
> APKs in Releases, GPL-3.0, happy to talk about any of it.

## Reply ammunition

**"Why not just use the official app?"**
> On iOS it went closed-source and gained paid tiers this year; on Android it's
> the same client I bounced off. And neither is offline-first in a way I trust —
> my commute has no signal.

**"Why not KOReader / Readwise / Reeder / Omnivore?"**
> Different shape. Those are readers over a sync service you don't own.
> wallabag is the thing I run, so I wanted a client for *my* server, not another
> subscription.

**"Another Flutter app."**
> Flutter was the fastest path to one codebase for both platforms with a WebView
> reader. If it helps, the part that isn't Flutter is the part that took the
> time: the offline write queue and reconciling it with server state.

**"Wallabag is dead / abandoned."**
> Maintained, just slow, and the clients are the weak link — which is the
> premise of this thing. If it dies, you still have your articles; the API is
> documented and someone else's client will work.

**"How do you handle conflicts?"**
> Writes are optimistic and idempotent: last local intent wins, and the entry is
> re-read from the server after the PATCH so the UI never claims a change the
> server didn't take. That re-read is what caught the silent-PATCH bug.

**"Self-promo."**
> Fair. I built it for myself first; posting it where people run wallabag is the
> only way the gaps get found.

## Rules that matter

- Reply to every comment for the first six hours. Stars follow replies.
- Never ask for upvotes. Never repost the same link within a week.
- Take "just use X" questions head-on — no defensiveness.
- If it flops, that's information, not an emergency. The forum post is the one
  that actually converts.

# Reddit

One subreddit per day. Disclose authorship in the title or the first line —
r/androidapps requires the `[Dev]` tag and a free/no-ads statement.

**Read the rules of each sub before posting.** r/selfhosted does not allow a
standalone post for this project at all — see below.

---

## r/selfhosted — comment in the "New Project Megathread", not a new post

Rule 6: *projects younger than 3 months (measured by first public presence, e.g.
a git commit) may only be posted inside the current "New Project Megathread".*
Folio's first commit is 29 Oct 2026, so a standalone post gets removed — and a
removal in a 542k-visitor sub is worse than no post.

Rule 2 sets the quality bar that still applies inside the thread: *promoted apps
must be production ready and have docs*, no ads for hosting/VPS. README,
`docs/`, CONTRIBUTING, CI and signed APKs in Releases already clear it.

Rule 5's Wednesday exception does **not** rescue this — it is for dashboards /
companion apps / tools, and rule 6 overrides it for anything under three months.

**Where**: the current pinned New Project Megathread. Threads roll; comment early
in a fresh one, not on page 20 of an old one.

**Comment to paste** (comment-shaped, no headers — a thread, not a pitch):

> **Folio — an offline-first wallabag reader for iOS and Android (GPL-3.0)**
>
> Self-hosted read-later client. I run wallabag myself and the client situation
> was the weak link, so I wrote one in Flutter: one codebase, iOS 16+ and
> Android 8+, public v2 API only.
>
> - offline-first: the list, opened articles and every write are local; archive/
>   star/delete queue and replay on the next sync
> - reader typography (15–30 pt, leading, serif/sans, paper/sepia/night), reading
>   position saved per article, TTS
> - OAuth password grant or pasted token; the password is used once, never stored
> - no telemetry, no server of mine — it only talks to your instance
> - demo mode, so it's explorable before you have a server
>
> APKs in Releases (split-per-ABI + universal, SHA256SUMS published each build).
> iOS builds from source; no App Store listing.
>
> Worth knowing if anyone else writes a client: `PATCH /api/entries/{id}.json`
> wants form params `archive` / `starred`. Send JSON and it returns 200 OK and
> changes nothing — silent, forever. Caught it by running against a real 2.6.15
> container after my own mock had passed everything.
>
> Gaps: no share extension yet, archive pagination, local-only search, tag
> editing is display-only. Feedback on which of those matters most decides what
> I build next.
>
> https://github.com/TheValkDokk/folio-wallabag

### The higher-value play, same sub

The megathread is where posting is *allowed*, not where it converts. Most of the
value is in comments on existing threads, which rule 2 explicitly permits when
it's relevant: people asking for a Pocket alternative, "best read-later client",
"wallabag app recommendations". Answer the question first, mention Folio once,
and only where it actually fits. Do not paste the block above into those threads.

---

## r/wallabag (small, high intent — short)

Check the sub's rules before posting; if it also restricts new projects, use its
equivalent thread rather than a standalone post.

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

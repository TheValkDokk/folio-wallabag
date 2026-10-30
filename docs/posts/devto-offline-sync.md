---
title: "An offline-first write queue in Flutter, and the day a 200 OK meant nothing"
published: false
description: "Optimistic writes, replay ordering and a server that accepts your PATCH and ignores it. How Folio's sync layer works, and what testing it against a real server changed."
tags: flutter, dart, architecture, testing
canonical_url: https://github.com/TheValkDokk/folio-wallabag
---

This is the engineering half of a launch post: how an offline-first write queue
works in a small Flutter app, and the specific bug class that makes it worth
building carefully.

Context: [Folio](https://github.com/TheValkDokk/folio-wallabag) is a client for
wallabag, a self-hosted read-later server. Users archive, star and delete
articles. The server is theirs, often on a box in a cupboard, reachable from a
phone maybe 70% of the time. So the UI cannot wait on the network, and a failed
request cannot lose intent.

## The shape

One store class (`ChangeNotifier`), one JSON snapshot in `SharedPreferences`, one
queue of pending writes. No framework. That's it — for an app this size a
state-management stack would be more code than the feature.

```dart
enum WriteOp { archive, unarchive, star, unstar, delete }

class PendingWrite {
  final int entryId;
  final WriteOp op;
  final DateTime at;
}
```

Rules that make it behave:

**1. Writes are optimistic and local-first.** Tapping archive flips the entry in
the local list, rewrites the snapshot, and enqueues. The UI never shows a spinner
for a local change.

**2. The queue is idempotent, not transactional.** `archive` twice is the same
as once, so replay after a partial failure is safe. Ops are absolute state
("set archived = true"), never deltas ("toggle").

**3. Delete wins over everything.** Before replay, collapse the queue per entry:
if any op is `delete`, drop the rest — there is no point unstarring a deleted
article.

**4. Re-read the server after each write.** This is the part people skip, and
it's the part that saved the release. After a PATCH succeeds, fetch the entry
and reconcile. A 2xx response is not evidence that anything changed.

**5. Failure degrades, never blocks.** A dead server shows a notice bar and keeps
the cached list. Losing connectivity shouldn't look like losing data.

## The 200 OK that lied

Wallabag's `PATCH /api/entries/{id}.json` expects **form-encoded** parameters
named `archive` and `starred`:

```bash
curl -X PATCH -H "Authorization: Bearer $TOKEN" \
  -d "archive=1" https://bag.example.com/api/entries/123.json
```

I was sending JSON with `is_starred`. The server returned **200 OK** and changed
nothing, forever, silently. The star button was decorative and the UI said it
worked, because the request succeeded.

Only rule 4 caught it. The test I should have written from the start asserts the
*entry on the server* changed:

```dart
await api.setArchived(entry.id, true);
final after = await api.entry(entry.id);      // re-read, don't trust the 2xx
expect(after.isArchived, isTrue);
```

Same bug class as any "successful" API call whose effect you never verified —
DNS, cache invalidation, a queue with no consumer. The response code describes
the request, not the outcome.

## Why the mock wasn't enough

The repo ships `tool/mock_wallabag.py`, a ~200-line API double with sample
articles. It's genuinely useful: UI work without PHP and MySQL, deterministic
screenshots, fast tests.

But it was written by the same person who wrote the client, from the same
misreading of the API. Against a real 2.6.15 container, four things broke:

| mock said | real server says |
| --- | --- |
| `created_at` is an epoch int | ISO-8601 string `2026-10-30T04:36:18+0000` |
| PATCH accepts JSON | PATCH wants form params (`archive`, `starred`) |
| error looks like an error | wrong params → `200 OK`, no change |
| content includes the title | `h1` stripped and stored separately |

An integration test written by the same author as the code under test is a unit
test wearing a costume. The fix was one afternoon: `docker run
wallabag/wallabag:latest`, create a user and OAuth client, save a few articles,
and run the suite against it.

## What I'd do differently

- Write the re-read-after-write assertion on day one. It costs three lines and
  catches an entire category of silent failure.
- One coercion helper for every field that could be num, string or timestamp.
  Fewer `as` casts, more `_toDate(value)`.
- Keep the mock, but label it in the README as a UI double, not a contract —
  because future-you will believe the README.

The code is GPL-3.0 and the API layer is a single file (`lib/wallabag.dart`), so
if you're building your own client for any self-hosted service, the queue and the
reconcile step are worth stealing.

Repo: https://github.com/TheValkDokk/folio-wallabag

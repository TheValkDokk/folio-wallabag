#!/usr/bin/env python3
"""Minimal wallabag API double for local development.

    python3 tool/mock_wallabag.py            # listens on :8000
    flutter run --dart-define=MOCK_CONNECT=http://127.0.0.1:8000

Implements just enough of the v2 API for Folio: token, info, entries,
single entry, patch and delete. Articles are served with real HTML so the
reader can be exercised without a server.
"""
import json
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

NOW = int(time.time())

ARTICLES = [
    {
        "id": 101,
        "title": "The case for slow software",
        "url": "https://example.org/slow-software",
        "domain_name": "example.org",
        "is_archived": 0,
        "is_starred": 1,
        "created_at": NOW - 1800,
        "updated_at": NOW - 1800,
        "reading_time": 7,
        "tags": [{"id": 1, "label": "design", "slug": "design"}],
        "preview_picture": "",
        "content": """
        <h1>The case for slow software</h1>
        <p class="standfirst">Not every tool should be optimised for the
        moment of use. Some are worth the friction.</p>
        <p class="byline">Essay</p>
        <p>We have spent twenty years removing every millisecond between a
        person and an outcome. Search suggestions, one-tap checkout, infinite
        feeds. The result is fast, and strangely hollow.</p>
        <p>A reading app is a good test case. The obvious move is to make it
        faster: faster sync, faster list, faster open. But the point of
        reading is not throughput.</p>
        <blockquote>Attention is the only resource you cannot earn back.</blockquote>
        <h2>Friction, deliberately</h2>
        <p>The tools I keep using are the ones that make the right thing easy
        and the wrong thing slightly annoying. Not blocked. Annoying.</p>
        <p>That is a design decision, not a limitation. It is also the first
        thing to get removed when a product is optimised for engagement
        metrics instead of outcomes.</p>
        <p>Slow software is not software that is badly built. It is software
        that refuses to spend your attention on its behalf.</p>
        """,
    },
    {
        "id": 102,
        "title": "What a shutdown teaches you about ownership",
        "url": "https://example.org/ownership",
        "domain_name": "example.org",
        "is_archived": 0,
        "is_starred": 0,
        "created_at": NOW - 86400,
        "updated_at": NOW - 86400,
        "reading_time": 5,
        "tags": [{"id": 2, "label": "local-first", "slug": "local-first"}],
        "preview_picture": "",
        "content": """
        <h1>What a shutdown teaches you about ownership</h1>
        <p>A reading list is a decade of attention. It should not be one
        company's line item.</p>
        <p>When a read-later service closes, the export contains links and
        titles. It does not contain the thing you actually saved: the clean
        copy of the article, the highlights, the reason you thought it
        mattered.</p>
        <p>Self-hosting is not a hobbyist affectation. It is a durability
        choice. The server can be a ten-dollar box; the point is that nobody
        else holds the delete key.</p>
        """,
    },
    {
        "id": 103,
        "title": "Reading on a phone without the feed",
        "url": "https://example.org/phone-reading",
        "domain_name": "example.org",
        "is_archived": 1,
        "is_starred": 0,
        "created_at": NOW - 86400 * 4,
        "updated_at": NOW - 86400 * 4,
        "reading_time": 4,
        "tags": [],
        "preview_picture": "",
        "content": """
        <h1>Reading on a phone without the feed</h1>
        <p>Typography does most of the work. The rest is restraint.</p>
        <p>Twenty characters per line is a ransom note. Ninety is a liability
        waiver. The usable range is boringly narrow, and most apps miss it
        because they are optimised for screenshots.</p>
        <p>A reader should let you change the size and then get out of the
        way. No progress confetti, no streaks, no recommendations.</p>
        """,
    },
]


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _json(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _authed(self):
        if self.headers.get("Authorization") != "Bearer mock-token":
            self._json(401, {"error": "invalid_grant"})
            return False
        return True

    def log_message(self, fmt, *args):
        print("mock:", fmt % args)

    def do_POST(self):
        path = urlparse(self.path).path
        if path == "/oauth/v2/token":
            length = int(self.headers.get("Content-Length", 0))
            self.rfile.read(length)
            self._json(200, {
                "access_token": "mock-token",
                "expires_in": 3600,
                "refresh_token": "mock-refresh",
                "scope": None,
                "token_type": "bearer",
            })
            return
        if path == "/api/entries.json":
            length = int(self.headers.get("Content-Length", 0))
            self.rfile.read(length)
            self._json(200, {"id": 104, "title": "Queued article"})
            return
        self._json(404, {"error": "not_found"})

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)
        if path == "/api/info.json":
            self._json(200, {"appname": "wallabag", "version": "2.6.15"})
            return
        if not self._authed():
            return
        if path == "/api/entries.json":
            archive = query.get("archive", [None])[0]
            page = int(query.get("page", ["1"])[0])
            items = ARTICLES
            if archive is not None:
                wanted = archive == "1"
                items = [a for a in ARTICLES if bool(a["is_archived"]) == wanted]
            if page > 1:
                items = []
            self._json(200, {
                "page": page,
                "limit": 30,
                "pages": 1,
                "total": len(items),
                "_embedded": {"items": items},
            })
            return
        if path.startswith("/api/entries/"):
            try:
                entry_id = int(path.split("/")[3].split(".")[0])
            except (IndexError, ValueError):
                self._json(404, {"error": "not_found"})
                return
            for a in ARTICLES:
                if a["id"] == entry_id:
                    self._json(200, a)
                    return
            self._json(404, {"error": "not_found"})
            return
        self._json(404, {"error": "not_found"})

    def do_PATCH(self):
        if not self._authed():
            return
        length = int(self.headers.get("Content-Length", 0))
        self.rfile.read(length)
        self._json(200, {"ok": True})

    def do_DELETE(self):
        if not self._authed():
            return
        self._json(200, {})


if __name__ == "__main__":
    print("mock wallabag on http://127.0.0.1:8000")
    HTTPServer(("127.0.0.1", 8000), Handler).serve_forever()

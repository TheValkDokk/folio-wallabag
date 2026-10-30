// Live integration test against a real wallabag instance.
//
//   WALLABAG_URL=http://127.0.0.1:8080 \
//   WALLABAG_CLIENT=1_abc123 WALLABAG_SECRET=secret \
//   WALLABAG_USER=valk WALLABAG_PASS=... \
//   flutter test test/live_wallabag_test.dart
//
// Skipped when WALLABAG_URL is unset, so `flutter test` stays offline-safe.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/wallabag.dart';

void main() {
  final url = Platform.environment['WALLABAG_URL'];
  final env = Platform.environment;
  final configured = url != null &&
      env['WALLABAG_CLIENT'] != null &&
      env['WALLABAG_SECRET'] != null &&
      env['WALLABAG_USER'] != null &&
      env['WALLABAG_PASS'] != null;

  group('live wallabag', () {
    late WallabagApi api;

    setUpAll(() async {
      if (!configured) return;
      api = WallabagApi(
        baseUrl: url,
        clientId: env['WALLABAG_CLIENT'],
        clientSecret: env['WALLABAG_SECRET'],
      );
      await api.passwordGrant(
        username: env['WALLABAG_USER']!,
        password: env['WALLABAG_PASS']!,
      );
    });

    test('info reports a wallabag server', () async {
      if (!configured) return;
      final info = await api.info();
      expect(info['appname'], 'wallabag');
      expect(info['version'], isNotEmpty);
    }, skip: !configured ? 'WALLABAG_URL not set' : false);

    test('lists entries and parses the real payload', () async {
      if (!configured) return;
      final entries = await api.entries(archive: 0);
      expect(entries, isNotEmpty, reason: 'add at least one article first');

      for (final e in entries) {
        expect(e.id, greaterThan(0));
        expect(e.title, isNotEmpty);
        expect(e.url, startsWith('http'));
        // The bug this test exists for: real wallabag sends ISO-8601 strings
        // for created_at/updated_at, not epoch integers.
        expect(e.createdAt, greaterThan(1500000000));
        expect(e.createdAt, lessThan(4000000000));
      }
    }, skip: !configured ? 'WALLABAG_URL not set' : false);

    test('opens one article with full content', () async {
      if (!configured) return;
      final entries = await api.entries(archive: 0);
      final target = entries.firstWhere(
        (e) => e.readingTime > 0,
        orElse: () => entries.first,
      );
      final full = await api.entry(target.id);
      expect(full.content, isNotNull);
      expect(full.content!.length, greaterThan(200));
      expect(full.domain, isNotNull);
    }, skip: !configured ? 'WALLABAG_URL not set' : false);

    test('star round-trips through the server', () async {
      if (!configured) return;
      final entries = await api.entries(archive: 0);
      final target = entries.first;
      final before = target.starred;

      await api.patch(target.id, {'starred': before ? 0 : 1});
      final after = await api.entry(target.id);
      expect(after.starred, !before);

      // restore
      await api.patch(target.id, {'starred': before ? 1 : 0});
      final restored = await api.entry(target.id);
      expect(restored.starred, before);
    }, skip: !configured ? 'WALLABAG_URL not set' : false);

    test('archive round-trips through the server', () async {
      if (!configured) return;
      final unread = await api.entries(archive: 0);
      final target = unread.first;

      await api.patch(target.id, {'archive': 1});
      final archived = await api.entries(archive: 1);
      expect(archived.any((e) => e.id == target.id), isTrue);

      await api.patch(target.id, {'archive': 0});
      final back = await api.entries(archive: 0);
      expect(back.any((e) => e.id == target.id), isTrue);
    }, skip: !configured ? 'WALLABAG_URL not set' : false);
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single wallabag entry, as returned by /api/entries.json.
/// wallabag is inconsistent across versions: timestamps come back as epoch
/// seconds on some endpoints and ISO-8601 strings on others, and booleans are
/// 0/1 ints, "0"/"1" strings, or real bools. Coerce once, here.
int _epochSeconds(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  final s = v.toString().trim();
  if (s.isEmpty) return 0;
  final asInt = int.tryParse(s);
  if (asInt != null) return asInt;
  final normalised = s.replaceFirstMapped(
    RegExp(r'([+-]\d{2})(\d{2})$'),
    (m) => '${m[1]}:${m[2]}',
  );
  final dt = DateTime.tryParse(normalised) ??
      DateTime.tryParse(normalised.replaceFirst(' ', 'T'));
  return dt == null ? 0 : dt.millisecondsSinceEpoch ~/ 1000;
}

bool _flag(Object? v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  return s == '1' || s == 'true' || s == 'yes';
}

int _int(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

double _double(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class Entry {
  Entry({
    required this.id,
    required this.title,
    required this.url,
    this.content,
    this.excerpt,
    this.domain,
    this.previewPicture,
    this.readingTime = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.archived = false,
    this.starred = false,
    this.tags = const [],
    this.language,
    this.authors,
    this.progress = 0,
    this.scrollOffset,
  });

  final int id;
  final String title;
  final String url;
  String? content;
  final String? excerpt;
  final String? domain;
  final String? previewPicture;
  final int readingTime;
  final int createdAt;
  int updatedAt;
  bool archived;
  bool starred;
  List<String> tags;
  final String? language;
  final String? authors;

  /// Local only: 0..1 reading progress and last scroll offset in px.
  double progress;
  double? scrollOffset;

  bool get hasContent => content != null && content!.trim().isNotEmpty;

  String get site {
    if (domain != null && domain!.isNotEmpty) return domain!;
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  String get readingLabel {
    final minutes = readingTime > 0
        ? readingTime
        : (content == null ? 1 : (content!.length / 1100).ceil().clamp(1, 90));
    return '$minutes min read';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'content': content,
        'excerpt': excerpt,
        'domain_name': domain,
        'preview_picture': previewPicture,
        'reading_time': readingTime,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'is_archived': archived,
        'is_starred': starred,
        'tags': tags,
        'language': language,
        'authors': authors,
        'progress': progress,
        'scroll': scrollOffset,
      };

  factory Entry.fromJson(Map<String, dynamic> j) {
    final rawTags = j['tags'];
    final tags = <String>[];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t is Map) {
          final label = t['label'] ?? t['slug'];
          if (label != null) tags.add(label.toString());
        } else if (t != null) {
          tags.add(t.toString());
        }
      }
    }
    return Entry(
      id: (j['id'] as num).toInt(),
      title: (j['title'] as String?)?.trim().isNotEmpty == true
          ? j['title'] as String
          : (j['url'] as String? ?? 'Untitled'),
      url: j['url'] as String? ?? '',
      content: j['content'] as String?,
      excerpt: j['excerpt'] as String?,
      domain: j['domain_name'] as String?,
      previewPicture: (j['preview_picture'] as String?)?.trim().isEmpty == true
          ? null
          : (j['preview_picture'] as String?),
      readingTime: _int(j['reading_time']),
      createdAt: _epochSeconds(j['created_at']),
      updatedAt: _epochSeconds(j['updated_at']),
      archived: _flag(j['is_archived']),
      starred: _flag(j['is_starred']),
      tags: tags,
      language: j['language'] as String?,
      authors: j['authors'] is List
          ? (j['authors'] as List)
              .map((a) => a.toString())
              .where((a) => a.trim().isNotEmpty)
              .join(', ')
          : j['authors']?.toString(),
      progress: _double(j['progress']),
      scrollOffset: j['scroll'] == null ? null : _double(j['scroll']),
    );
  }

  Entry copy() => Entry.fromJson(toJson());
}

class WallabagException implements Exception {
  WallabagException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

enum SyncPhase { idle, syncing, error, offline }

enum Box { unread, starred, archived, all }

enum ReaderTheme { paper, sepia, night }

class PendingOp {
  PendingOp(this.kind, this.entryId, {this.value, this.url});
  final String kind; // archive, unarchive, star, unstar, delete, add
  final int entryId;
  final Object? value;
  final String? url;

  Map<String, dynamic> toJson() =>
      {'kind': kind, 'entryId': entryId, 'value': value, 'url': url};

  factory PendingOp.fromJson(Map<String, dynamic> j) => PendingOp(
        j['kind'] as String,
        (j['entryId'] as num?)?.toInt() ?? 0,
        value: j['value'],
        url: j['url'] as String?,
      );
}

/// API client. Wallabag v2 uses OAuth2 password/refresh grants plus a bearer
/// token for every /api call.
class WallabagApi {
  WallabagApi({
    required this.baseUrl,
    this.accessToken,
    this.refreshToken,
    this.clientId,
    this.clientSecret,
    this.expiresAt,
  });

  String baseUrl;
  String? accessToken;
  String? refreshToken;
  String? clientId;
  String? clientSecret;
  DateTime? expiresAt;

  String get _root {
    var b = baseUrl.trim();
    if (!b.startsWith('http')) b = 'https://$b';
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    return b;
  }

  Uri _u(String path, [Map<String, String>? query]) =>
      Uri.parse('$_root/api/$path').replace(queryParameters: query);

  Uri get _tokenUri => Uri.parse('$_root/oauth/v2/token');

  Future<Map<String, dynamic>> _json(
    http.Response r, {
    String what = 'request',
  }) async {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (r.body.isEmpty) return {};
      final decoded = jsonDecode(utf8.decode(r.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    }
    if (r.statusCode == 401) {
      throw WallabagException(
        'Wallabag rejected the credentials (401). Check the client id, '
        'secret and password, or paste a fresh token.',
        status: 401,
      );
    }
    if (r.statusCode == 404) {
      throw WallabagException(
        'Nothing found at that address (404). Is the URL your wallabag root?',
        status: 404,
      );
    }
    throw WallabagException(
      'Wallabag $what failed (${r.statusCode}). '
      '${r.body.length > 160 ? r.body.substring(0, 160) : r.body}',
      status: r.statusCode,
    );
  }

  Map<String, String> get _auth => {
        'Authorization': 'Bearer ${accessToken ?? ''}',
        'Accept': 'application/json',
      };

  Future<void> passwordGrant({
    required String username,
    required String password,
  }) async {
    final id = (clientId ?? '').trim();
    final secret = (clientSecret ?? '').trim();
    if (id.isEmpty || secret.isEmpty) {
      throw WallabagException(
        'A client id and secret are required. In wallabag open '
        'Developer → Create a client, then paste both here.',
      );
    }
    final res = await http.post(
      _tokenUri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'password',
        'client_id': id,
        'client_secret': secret,
        'username': username.trim(),
        'password': password,
      },
    ).timeout(const Duration(seconds: 20));
    _store(_jsonSync(res));
  }

  Future<void> refresh() async {
    if (refreshToken == null || clientId == null || clientSecret == null) {
      throw WallabagException('Session expired. Connect again.');
    }
    final res = await http.post(
      _tokenUri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'client_id': clientId!,
        'client_secret': clientSecret!,
        'refresh_token': refreshToken!,
      },
    ).timeout(const Duration(seconds: 20));
    _store(_jsonSync(res));
  }

  Map<String, dynamic> _jsonSync(http.Response r) {
    final body = jsonDecode(utf8.decode(r.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw WallabagException('Unexpected token response');
    }
    if (body['access_token'] == null) {
      throw WallabagException(
        body['error_description']?.toString() ??
            body['error']?.toString() ??
            'Wallabag refused the login.',
      );
    }
    return body;
  }

  void _store(Map<String, dynamic> body) {
    accessToken = body['access_token'] as String?;
    refreshToken = (body['refresh_token'] as String?) ?? refreshToken;
    final ttl = (body['expires_in'] as num?)?.toInt() ?? 3600;
    expiresAt = DateTime.now().add(Duration(seconds: ttl - 60));
  }

  Future<void> ensureFresh() async {
    final exp = expiresAt;
    if (exp != null && DateTime.now().isAfter(exp) && refreshToken != null) {
      await refresh();
    }
  }

  Future<Map<String, dynamic>> info() async {
    final r = await http.get(_u('info.json'), headers: _auth)
        .timeout(const Duration(seconds: 15));
    return _json(r, what: 'info');
  }

  Future<List<Entry>> entries({
    int page = 1,
    int perPage = 30,
    int? archive,
    int? starred,
    int? since,
    String sort = 'created',
    String order = 'desc',
  }) async {
    await ensureFresh();
    final q = <String, String>{
      'page': '$page',
      'perPage': '$perPage',
      'sort': sort,
      'order': order,
      // Lists only need metadata; pulling full content for 30 entries means
      // megabytes per sync. The reader fetches content on open instead.
      'detail': 'metadata',
    };
    if (archive != null) q['archive'] = '$archive';
    if (starred != null) q['starred'] = '$starred';
    if (since != null) q['since'] = '$since';
    final r = await http.get(_u('entries.json', q), headers: _auth)
        .timeout(const Duration(seconds: 25));
    final body = await _json(r, what: 'sync');
    final embedded = body['_embedded'];
    final items = (embedded is Map ? embedded['items'] : null) as List? ?? [];
    return items
        .whereType<Map>()
        .map((m) => Entry.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<Entry> entry(int id) async {
    await ensureFresh();
    final r = await http.get(_u('entries/$id.json'), headers: _auth)
        .timeout(const Duration(seconds: 20));
    return Entry.fromJson(await _json(r, what: 'open article'));
  }

  Future<void> patch(int id, Map<String, dynamic> fields) async {
    await ensureFresh();
    // wallabag reads PATCH fields from the form body ($request->request->all()).
    // A JSON body returns 200 and changes nothing — which is worse than an
    // error, so always send form encoding here.
    final form = fields.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}='
            '${Uri.encodeQueryComponent('${e.value}')}')
        .join('&');
    final r = await http.patch(
      _u('entries/$id.json'),
      headers: {
        ..._auth,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: form,
    ).timeout(const Duration(seconds: 20));
    await _json(r, what: 'update');
  }

  Future<Entry?> add(String url, {List<String> tags = const []}) async {
    await ensureFresh();
    final r = await http.post(
      _u('entries.json'),
      headers: {..._auth, 'Content-Type': 'application/json'},
      body: jsonEncode({'url': url, 'tags': tags.join(',')}),
    ).timeout(const Duration(seconds: 30));
    final body = await _json(r, what: 'save link');
    if (body['id'] == null) return null;
    return entry((body['id'] as num).toInt());
  }

  Future<void> remove(int id) async {
    await ensureFresh();
    final r = await http.delete(_u('entries/$id.json'), headers: _auth)
        .timeout(const Duration(seconds: 20));
    await _json(r, what: 'delete');
  }
}

/// Local-first store: the UI always reads from here, network is a background
/// concern, and actions survive being offline.
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs);

  final SharedPreferences _prefs;

  static const _configKey = 'folio.config.v1';
  static const _readerKey = 'folio.reader.v1';

  String baseUrl = '';
  String? accessToken;
  String? refreshToken;
  String? clientId;
  String? clientSecret;
  DateTime? expiresAt;
  String userName = '';
  bool demo = false;

  final Map<int, Entry> entries = {};
  final Set<int> downloaded = {};
  final List<PendingOp> queue = [];
  DateTime? lastSync;
  SyncPhase phase = SyncPhase.idle;
  String? error;
  bool onboardingDone = false;

  Box box = Box.unread;
  String query = '';

  double fontSize = 19;
  double lineHeight = 1.6;
  ReaderTheme readerTheme = ReaderTheme.paper;
  String readerFace = 'serif';

  bool darkMode = false;

  WallabagApi? _api;
  File? _cacheFile;
  Timer? _saveDebounce;

  bool get connected => demo || accessToken != null;
  bool get isDemo => demo;

  static Future<AppStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = AppStore._(prefs);
    await s._restore();
    return s;
  }

  Future<void> _restore() async {
    final rawConfig = _prefs.getString(_configKey);
    if (rawConfig != null) {
      try {
        final c = jsonDecode(rawConfig) as Map<String, dynamic>;
        baseUrl = c['baseUrl'] as String? ?? '';
        accessToken = c['token'] as String?;
        refreshToken = c['refresh'] as String?;
        clientId = c['clientId'] as String?;
        clientSecret = c['clientSecret'] as String?;
        final exp = c['expiresAt'] as int?;
        if (exp != null) expiresAt = DateTime.fromMillisecondsSinceEpoch(exp);
        userName = c['userName'] as String? ?? '';
        demo = c['demo'] as bool? ?? false;
        onboardingDone = c['onboarded'] as bool? ?? false;
      } catch (_) {}
    }

    final rawReader = _prefs.getString(_readerKey);
    if (rawReader != null) {
      try {
        final r = jsonDecode(rawReader) as Map<String, dynamic>;
        fontSize = (r['fontSize'] as num?)?.toDouble() ?? 19;
        lineHeight = (r['lineHeight'] as num?)?.toDouble() ?? 1.6;
        readerTheme =
            ReaderTheme.values[(r['theme'] as num?)?.toInt() ?? 0];
        readerFace = r['face'] as String? ?? 'serif';
        darkMode = r['dark'] as bool? ?? false;
      } catch (_) {}
    }

    try {
      final dir = await getApplicationSupportDirectory();
      _cacheFile = File('${dir.path}/folio_cache.json');
      if (await _cacheFile!.exists()) {
        final data = jsonDecode(await _cacheFile!.readAsString())
            as Map<String, dynamic>;
        for (final e in (data['entries'] as List? ?? const [])) {
          final entry = Entry.fromJson((e as Map).cast<String, dynamic>());
          entries[entry.id] = entry;
          if (entry.hasContent) downloaded.add(entry.id);
        }
        for (final o in (data['queue'] as List? ?? const [])) {
          queue.add(PendingOp.fromJson((o as Map).cast<String, dynamic>()));
        }
        final ls = data['lastSync'] as int?;
        if (ls != null) lastSync = DateTime.fromMillisecondsSinceEpoch(ls);
      }
    } catch (_) {}

    if (demo && entries.isEmpty) {
      for (final e in demoEntries()) {
        entries[e.id] = e;
        downloaded.add(e.id);
      }
    }

    if (connected && entries.isEmpty) {
      // First launch after connecting elsewhere; sync lazily.
      unawaited(sync());
    }
  }

  // ---- persistence ---------------------------------------------------------

  Future<void> _saveConfig() async {
    await _prefs.setString(
      _configKey,
      jsonEncode({
        'baseUrl': baseUrl,
        'token': accessToken,
        'refresh': refreshToken,
        'clientId': clientId,
        'clientSecret': clientSecret,
        'expiresAt': expiresAt?.millisecondsSinceEpoch,
        'userName': userName,
        'demo': demo,
        'onboarded': onboardingDone,
      }),
    );
  }

  Future<void> _saveReader() async {
    await _prefs.setString(
      _readerKey,
      jsonEncode({
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'theme': readerTheme.index,
        'face': readerFace,
        'dark': darkMode,
      }),
    );
  }

  void _scheduleCacheSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), _saveCache);
  }

  Future<void> _saveCache() async {
    final file = _cacheFile;
    if (file == null) return;
    final payload = jsonEncode({
      'entries': entries.values.map((e) => e.toJson()).toList(),
      'queue': queue.map((o) => o.toJson()).toList(),
      'lastSync': lastSync?.millisecondsSinceEpoch,
    });
    try {
      await file.writeAsString(payload, flush: true);
    } catch (_) {}
  }

  // ---- reading preferences -------------------------------------------------

  void setFontSize(double v) {
    fontSize = v.clamp(15, 30);
    _saveReader();
    notifyListeners();
  }

  void setLineHeight(double v) {
    lineHeight = v.clamp(1.3, 2.1);
    _saveReader();
    notifyListeners();
  }

  void setReaderTheme(ReaderTheme t) {
    readerTheme = t;
    _saveReader();
    notifyListeners();
  }

  void setFace(String face) {
    readerFace = face;
    _saveReader();
    notifyListeners();
  }

  void setDark(bool v) {
    darkMode = v;
    _saveReader();
    notifyListeners();
  }

  void setBox(Box b) {
    box = b;
    notifyListeners();
  }

  void setQuery(String q) {
    query = q;
    notifyListeners();
  }

  // ---- connection ----------------------------------------------------------

  Future<void> connectWithPassword({
    required String baseUrl,
    required String clientId,
    required String clientSecret,
    required String username,
    required String password,
  }) async {
    final api = WallabagApi(
      baseUrl: baseUrl,
      clientId: clientId,
      clientSecret: clientSecret,
    );
    await api.passwordGrant(username: username, password: password);
    await api.info();

    this.baseUrl = _cleanBase(baseUrl);
    this.clientId = clientId;
    this.clientSecret = clientSecret;
    accessToken = api.accessToken;
    refreshToken = api.refreshToken;
    expiresAt = api.expiresAt;
    userName = username;
    demo = false;
    onboardingDone = true;
    _api = api;
    await _saveConfig();
    notifyListeners();
    await sync(full: true);
  }

  Future<void> connectWithToken({
    required String baseUrl,
    required String token,
  }) async {
    final api = WallabagApi(baseUrl: baseUrl, accessToken: token.trim());
    final info = await api.info();
    const probe = 1;
    await api.entries(page: probe, perPage: 1);

    this.baseUrl = _cleanBase(baseUrl);
    accessToken = token.trim();
    refreshToken = null;
    clientId = null;
    clientSecret = null;
    expiresAt = null;
    userName = info['username']?.toString() ?? 'wallabag';
    demo = false;
    onboardingDone = true;
    _api = api;
    await _saveConfig();
    notifyListeners();
    await sync(full: true);
  }

  Future<void> startDemo() async {
    demo = true;
    onboardingDone = true;
    baseUrl = 'demo';
    entries
      ..clear()
      ..addAll({for (final e in demoEntries()) e.id: e});
    downloaded.addAll(entries.keys);
    lastSync = DateTime.now();
    await _saveConfig();
    await _saveCache();
    notifyListeners();
  }

  Future<void> disconnect() async {
    demo = false;
    baseUrl = '';
    accessToken = null;
    refreshToken = null;
    clientId = null;
    clientSecret = null;
    expiresAt = null;
    userName = '';
    onboardingDone = false;
    entries.clear();
    downloaded.clear();
    queue.clear();
    lastSync = null;
    _api = null;
    await _saveConfig();
    await _saveCache();
    notifyListeners();
  }

  String _cleanBase(String v) {
    var b = v.trim();
    if (!b.startsWith('http')) b = 'https://$b';
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    return b;
  }

  // ---- derived list --------------------------------------------------------

  List<Entry> get visible {
    final q = query.trim().toLowerCase();
    final out = entries.values.where((e) {
      switch (box) {
        case Box.unread:
          if (e.archived) return false;
          break;
        case Box.starred:
          if (!e.starred) return false;
          break;
        case Box.archived:
          if (!e.archived) return false;
          break;
        case Box.all:
          break;
      }
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q) ||
          e.site.toLowerCase().contains(q) ||
          (e.excerpt ?? '').toLowerCase().contains(q) ||
          e.tags.any((t) => t.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  int get unreadCount => entries.values.where((e) => !e.archived).length;
  int get starredCount => entries.values.where((e) => e.starred).length;
  int get archivedCount => entries.values.where((e) => e.archived).length;
  int get queueCount => queue.length;

  Entry? byId(int id) => entries[id];

  // ---- sync ----------------------------------------------------------------

  Future<void> sync({bool full = false}) async {
    if (demo) {
      phase = SyncPhase.idle;
      lastSync = DateTime.now();
      notifyListeners();
      return;
    }
    _api ??= WallabagApi(
        baseUrl: baseUrl,
        accessToken: accessToken,
        refreshToken: refreshToken,
        clientId: clientId,
        clientSecret: clientSecret,
        expiresAt: expiresAt,
      );
    if (phase == SyncPhase.syncing) return;
    phase = SyncPhase.syncing;
    error = null;
    notifyListeners();

    try {
      await _flushQueue();

      if (full || entries.isEmpty) {
        for (var page = 1; page <= 4; page++) {
          final batch = await _api!.entries(page: page, archive: 0);
          if (batch.isEmpty) break;
          for (final e in batch) {
            final prior = entries[e.id];
            if (prior != null) {
              e.progress = prior.progress;
              e.scrollOffset = prior.scrollOffset;
            }
            entries[e.id] = e;
          }
          if (batch.length < 30) break;
        }
        // A first page of the archive keeps search useful without a full pull.
        final archived = await _api!.entries(page: 1, archive: 1);
        for (final e in archived) {
          final prior = entries[e.id];
          if (prior != null) {
            e.progress = prior.progress;
            e.scrollOffset = prior.scrollOffset;
          }
          entries[e.id] = e;
        }
      } else {
        final since = (lastSync?.millisecondsSinceEpoch ?? 0) ~/ 1000;
        for (var page = 1; page <= 4; page++) {
          final batch =
              await _api!.entries(page: page, since: since > 0 ? since - 120 : null);
          if (batch.isEmpty) break;
          for (final e in batch) {
            final prior = entries[e.id];
            e.progress = prior?.progress ?? 0;
            e.scrollOffset = prior?.scrollOffset;
            entries[e.id] = e;
          }
          if (batch.length < 30) break;
        }
      }

      lastSync = DateTime.now();
      phase = SyncPhase.idle;
      _scheduleCacheSave();
    } on SocketException {
      phase = SyncPhase.offline;
      error = 'Offline. Showing your downloaded reading list.';
    } on TimeoutException {
      phase = SyncPhase.offline;
      error = 'The server took too long. Reading list kept offline.';
    } on WallabagException catch (e) {
      phase = SyncPhase.error;
      error = e.message;
      if (e.status == 401) {
        accessToken = null;
        await _saveConfig();
      }
    } catch (e) {
      phase = SyncPhase.error;
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> openFull(Entry entry) async {
    if (entry.hasContent || demo) return;
    // Fill the entry the caller already holds: replacing the object in the
    // map would leave the open reader pointing at a content-less copy.
    final fresh = await _api!.entry(entry.id);
    entry.content = fresh.content;
    entry.updatedAt = fresh.updatedAt;
    downloaded.add(entry.id);
    _scheduleCacheSave();
    notifyListeners();
  }

  // ---- actions (optimistic + queued) ---------------------------------------

  Future<void> setArchived(Entry e, bool value) async {
    e.archived = value;
    notifyListeners();
    await _push(PendingOp(value ? 'archive' : 'unarchive', e.id));
  }

  Future<void> setStarred(Entry e, bool value) async {
    e.starred = value;
    notifyListeners();
    await _push(PendingOp(value ? 'star' : 'unstar', e.id));
  }

  Future<void> saveProgress(Entry e, double progress, double offset) async {
    e.progress = progress.clamp(0, 1);
    e.scrollOffset = offset;
    _scheduleCacheSave();
  }

  Future<void> delete(Entry e) async {
    entries.remove(e.id);
    downloaded.remove(e.id);
    notifyListeners();
    await _push(PendingOp('delete', e.id));
  }

  Future<Entry?> addUrl(String url, {List<String> tags = const []}) async {
    if (demo) {
      final e = Entry(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: url,
        url: url,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        tags: tags,
        archived: false,
      );
      entries[e.id] = e;
      notifyListeners();
      return e;
    }
    final created = await _api!.add(url, tags: tags);
    if (created != null) {
      entries[created.id] = created;
      _scheduleCacheSave();
      notifyListeners();
    }
    return created;
  }

  Future<void> _push(PendingOp op) async {
    if (demo) {
      _scheduleCacheSave();
      return;
    }
    queue.add(op);
    _scheduleCacheSave();
    notifyListeners();
    await _flushQueue();
  }

  Future<void> _flushQueue() async {
    if (_api == null || queue.isEmpty) return;
    final pending = List<PendingOp>.from(queue);
    for (final op in pending) {
      try {
        switch (op.kind) {
          case 'archive':
            await _api!.patch(op.entryId, {'archive': 1});
          case 'unarchive':
            await _api!.patch(op.entryId, {'archive': 0});
          case 'star':
            await _api!.patch(op.entryId, {'starred': 1});
          case 'unstar':
            await _api!.patch(op.entryId, {'starred': 0});
          case 'delete':
            await _api!.remove(op.entryId);
          case 'add':
            if (op.url != null) await _api!.add(op.url!);
        }
        queue.remove(op);
        notifyListeners();
      } on WallabagException catch (e) {
        if (e.status == 404 || e.status == 401) {
          queue.remove(op);
        }
      } catch (_) {
        break; // stay queued; next sync retries
      }
    }
    _scheduleCacheSave();
  }

  // ---- demo content --------------------------------------------------------

  static List<Entry> demoEntries() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return [
      Entry(
        id: 9001,
        title: 'The Case for Slow Software',
        url: 'https://example.com/slow-software',
        domain: 'example.com',
        readingTime: 9,
        createdAt: now - 3600,
        updatedAt: now - 3600,
        excerpt:
            'Not every tool should be optimized for the moment of use. Some '
            'are worth the friction.',
        tags: const ['design', 'reading'],
        progress: 0.34,
        content: _demoHtml(
          'The Case for Slow Software',
          'Not every tool should be optimized for the moment of use. Some are '
              'worth the friction.',
          [
            'We have spent twenty years removing every millisecond between a '
                'person and an outcome. Search suggestions, one-tap checkout, '
                'infinite feeds. The result is fast, and strangely hollow.',
            'A reading app is a good test case. The obvious move is to make it '
                'faster: faster sync, faster list, faster open. But the point '
                'of reading is not throughput.',
            'The tools I keep using are the ones that make the right thing easy '
                'and the wrong thing slightly annoying. Not blocked. Annoying. '
                'A small, honest friction.',
          ],
        ),
      ),
      Entry(
        id: 9002,
        title: 'What Pocket\'s shutdown taught us about ownership',
        url: 'https://example.com/pocket-ownership',
        domain: 'example.com',
        readingTime: 6,
        createdAt: now - 86400,
        updatedAt: now - 86400,
        excerpt:
            'A reading list is a decade of attention. It should not be one '
            'company\'s line item.',
        tags: const ['reading', 'local-first'],
        starred: true,
        content: _demoHtml(
          'What Pocket\'s shutdown taught us about ownership',
          'A reading list is a decade of attention.',
          [
            'When a read-later service closes, the export contains links and '
                'titles. It does not contain the thing you actually saved: the '
                'clean copy of the article, the highlights, the reason you '
                'thought it mattered.',
            'Self-hosting is not a hobbyist affectation. It is a durability '
                'choice. The server can be a ten-dollar box; the point is that '
                'nobody else holds the delete key.',
            'This client exists for that reason. Your wallabag, your articles, '
                'your phone. If this app disappears tomorrow, the server and '
                'the export do not.',
          ],
        ),
      ),
      Entry(
        id: 9003,
        title: 'Reading on a phone without the feed',
        url: 'https://example.com/phone-reading',
        domain: 'example.com',
        readingTime: 4,
        createdAt: now - 86400 * 3,
        updatedAt: now - 86400 * 3,
        excerpt:
            'Typography, line length and the absence of a next-up carousel.',
        tags: const ['design'],
        content: _demoHtml(
          'Reading on a phone without the feed',
          'Typography does most of the work. The rest is restraint.',
          [
            'Twenty characters per line is a ransom note. Ninety is a '
                'liability waiver. The usable range is boringly narrow, and '
                'most apps miss it because they are optimized for screenshots.',
            'A reader should let you change size and then get out of the way. '
                'No progress confetti. No streaks. The reward is the article.',
          ],
        ),
      ),
      Entry(
        id: 9004,
        title: 'Notes on maintaining a personal library',
        url: 'https://example.com/personal-library',
        domain: 'example.com',
        readingTime: 7,
        createdAt: now - 86400 * 6,
        updatedAt: now - 86400 * 6,
        excerpt: 'Ten years of bookmarks, and the four rules that kept them useful.',
        tags: const ['reading'],
        archived: true,
        progress: 1,
        content: _demoHtml(
          'Notes on maintaining a personal library',
          'Ten years of bookmarks, four rules.',
          [
            'Delete without guilt. A saved article you have not opened in a year '
                'is not an asset, it is a debt with interest.',
            'Tag for retrieval, not for taxonomy. Three words you would actually '
                'type beat a hierarchy.',
          ],
        ),
      ),
    ];
  }

  static String _demoHtml(String title, String standfirst, List<String> paras) {
    final body = paras.map((p) => '<p>$p</p>').join();
    return '<div><h1>$title</h1>'
        '<p class="standfirst">$standfirst</p>'
        '<p class="byline">Essay · Demo article</p>'
        '$body'
        '<h2>A closing thought</h2>'
        '<p>Friction is not the enemy of a good tool. Undifferentiated speed '
        'is. The useful question is not "how fast can this be" but "what should '
        'this make easier".</p>'
        '<blockquote>Attention is the only resource you cannot earn back.</blockquote>'
        '</div>';
  }
}

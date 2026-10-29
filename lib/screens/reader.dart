import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme.dart';
import '../wallabag.dart';
import '../widgets.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.store, required this.entry});

  final AppStore store;
  final Entry entry;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final WebViewController _web = WebViewController();
  late final FlutterTts _tts = FlutterTts();

  double _progress = 0;
  double _scroll = 0;
  bool _loadingContent = false;
  String? _loadError;
  bool _speaking = false;
  Timer? _saveTimer;
  bool _restored = false;

  AppStore get s => widget.store;
  Entry get e => widget.entry;

  @override
  void initState() {
    super.initState();
    _progress = e.progress;
    _scroll = e.scrollOffset ?? 0;
    _setupWeb();
    _load();
    unawaited(_tts.setSpeechRate(0.45));
    unawaited(_tts.setVolume(1.0));
    unawaited(_tts.setPitch(1.0));
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _persist();
    _tts.stop();
    super.dispose();
  }

  void _setupWeb() {
    _web
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_bg)
      ..addJavaScriptChannel('Folio', onMessageReceived: (msg) {
        try {
          final data = jsonDecode(msg.message) as Map<String, dynamic>;
          final link = data['link']?.toString();
          if (link != null && link.isNotEmpty) {
            if (link.startsWith('http')) {
              launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
            }
            return;
          }
          final y = (data['y'] as num?)?.toDouble() ?? 0;
          final p = (data['p'] as num?)?.toDouble() ?? 0;
          if (!mounted) return;
          setState(() {
            _scroll = y;
            _progress = p.clamp(0.0, 1.0);
          });
          _queueSave();
        } catch (_) {}
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (!_restored) {
            _restored = true;
            _restoreScroll();
          }
        },
        onNavigationRequest: (request) {
          final url = request.url;
          if (url.startsWith('data:') ||
              url.startsWith('about:') ||
              url == e.url) {
            return NavigationDecision.navigate;
          }
          // A real outbound link: hand it to the system browser instead of
          // losing the article inside the reader.
          if (url.startsWith('http')) {
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          }
          return NavigationDecision.prevent;
        },
      ));
  }

  Future<void> _load() async {
    if (!e.hasContent) {
      setState(() => _loadingContent = true);
      try {
        await s.openFull(e);
      } catch (err) {
        if (mounted) {
          setState(() {
            _loadingContent = false;
            _loadError = err is WallabagException
                ? err.message
                : 'Could not download this article.';
          });
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _loadingContent = false;
        _restored = false;
      });
    }
    await _render();
  }

  Future<void> _render() async {
    await _web.loadHtmlString(_html(), baseUrl: e.url);
  }

  void _restoreScroll() {
    final y = _scroll;
    if (y <= 0) return;
    _web.runJavaScript('''
      setTimeout(function(){
        window.scrollTo(0, $y);
      }, 120);
    ''');
  }

  void _queueSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _persist);
  }

  void _persist() {
    s.saveProgress(e, _progress, _scroll);
  }

  // ---- theme ---------------------------------------------------------------

  FolioColors get _chromeColors =>
      s.readerTheme == ReaderTheme.night ? FolioColors.dark : context.c;

  Color get _bg {
    switch (s.readerTheme) {
      case ReaderTheme.paper:
        return const Color(0xFFFBF8F0);
      case ReaderTheme.sepia:
        return const Color(0xFFF2E7D3);
      case ReaderTheme.night:
        return const Color(0xFF121212);
    }
  }

  Color get _fg {
    switch (s.readerTheme) {
      case ReaderTheme.paper:
        return const Color(0xFF1A1713);
      case ReaderTheme.sepia:
        return const Color(0xFF3A2E22);
      case ReaderTheme.night:
        return const Color(0xFFD9D3C7);
    }
  }

  Color get _mutedInk {
    switch (s.readerTheme) {
      case ReaderTheme.paper:
        return const Color(0xFF6B6357);
      case ReaderTheme.sepia:
        return const Color(0xFF7A6A55);
      case ReaderTheme.night:
        return const Color(0xFF8F887C);
    }
  }

  String get _accentInk {
    switch (s.readerTheme) {
      case ReaderTheme.paper:
        return '#1F4B43';
      case ReaderTheme.sepia:
        return '#7A4B1F';
      case ReaderTheme.night:
        return '#C7A46B';
    }
  }

  String _html() {
    final body = e.content ?? '<p>${e.excerpt ?? ''}</p>';
    final font = s.readerFace == 'sans'
        ? '-apple-system, "Segoe UI", Roboto, sans-serif'
        : 'Georgia, "Iowan Old Style", "Times New Roman", serif';
    return '''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<style>
  :root {
    --bg: ${_hex(_bg)};
    --fg: ${_hex(_fg)};
    --muted: ${_hex(_mutedInk)};
    --accent: $_accentInk;
  }
  * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
  html, body { margin: 0; padding: 0; background: var(--bg); color: var(--fg); }
  body {
    font-family: $font;
    font-size: ${s.fontSize}px;
    line-height: ${s.lineHeight};
    padding: 14px 22px 32px;
    max-width: 720px;
    margin: 0 auto;
    -webkit-text-size-adjust: 100%;
    overflow-wrap: break-word;
  }
  h1, h2, h3, h4 { line-height: 1.24; margin: 1.6em 0 0.5em; font-weight: 600; letter-spacing: -0.01em; }
  h1 { font-size: 1.5em; margin-top: 0.2em; }
  h2 { font-size: 1.24em; }
  h3 { font-size: 1.1em; }
  p { margin: 0 0 1.05em; }
  a { color: var(--accent); text-decoration: underline; text-underline-offset: 2px; text-decoration-thickness: 1px; }
  img, video, iframe { max-width: 100%; height: auto; border-radius: 6px; display: block; margin: 1.4em auto; }
  figure { margin: 1.6em 0; }
  figcaption { font-size: 0.78em; color: var(--muted); text-align: center; margin-top: 0.6em; }
  blockquote {
    margin: 1.5em 0; padding: 0.1em 0 0.1em 1em;
    border-left: 2px solid var(--accent);
    color: var(--muted); font-style: italic;
  }
  pre { overflow-x: auto; padding: 12px; background: rgba(127,127,127,0.10); border-radius: 8px; font-size: 0.82em; line-height: 1.45; }
  code { font-size: 0.88em; }
  hr { border: 0; border-top: 1px solid rgba(127,127,127,0.25); margin: 2em 0; }
  ul, ol { padding-left: 1.3em; margin: 0 0 1.05em; }
  li { margin-bottom: 0.4em; }
  table { width: 100%; border-collapse: collapse; font-size: 0.85em; }
  td, th { border-bottom: 1px solid rgba(127,127,127,0.25); padding: 6px 4px; text-align: left; }
  .standfirst { color: var(--muted); font-size: 1.08em; }
  .byline { color: var(--muted); font-size: 0.76em; letter-spacing: 0.06em; text-transform: uppercase; margin-bottom: 2em; }
  .folio-end { color: var(--muted); text-align: center; font-size: 0.72em; letter-spacing: 0.14em; text-transform: uppercase; margin-top: 3em; }
</style>
</head>
<body>
$body
<div class="folio-end">End</div>
<script>
  (function () {
    var last = 0;
    function report() {
      var now = Date.now();
      if (now - last < 250) return;
      last = now;
      var max = Math.max(1, document.documentElement.scrollHeight - window.innerHeight);
      var p = Math.min(1, Math.max(0, window.scrollY / max));
      if (window.Folio) {
        window.Folio.postMessage(JSON.stringify({ y: window.scrollY, p: p }));
      }
    }
    window.addEventListener('scroll', report, { passive: true });
    document.addEventListener('click', function (ev) {
      var a = ev.target;
      while (a && a.tagName !== 'A') { a = a.parentElement; }
      if (!a || !a.getAttribute('href')) return;
      var href = a.getAttribute('href');
      if (href.charAt(0) === '#') return;
      ev.preventDefault();
      try { a.href = new URL(href, document.baseURI).toString(); } catch (e) {}
      window.Folio.postMessage(JSON.stringify({ link: a.href }));
    }, true);
  })();
</script>
</body>
</html>
''';
  }

  String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  // ---- actions -------------------------------------------------------------

  Future<void> _toggleSpeak() async {
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
      return;
    }
    final text = _plainText();
    if (text.isEmpty) return;
    setState(() => _speaking = true);
    final chunks = _chunk(text);
    await _tts.awaitSpeakCompletion(true);
    for (final chunk in chunks) {
      if (!_speaking || !mounted) break;
      await _tts.speak(chunk);
    }
    if (mounted) setState(() => _speaking = false);
  }

  String _plainText() {
    final parsed = html_parser.parse(e.content ?? '');
    final title = e.title;
    final body = parsed.body?.text ?? '';
    return body.replaceAll(RegExp(r'\s+'), ' ').trim().isEmpty
        ? title
        : '$title. $body';
  }

  List<String> _chunk(String text) {
    final words = text.split(' ');
    final out = <String>[];
    var buf = StringBuffer();
    for (final w in words) {
      if (buf.length + w.length > 550) {
        out.add(buf.toString());
        buf = StringBuffer();
      }
      buf.write('$w ');
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }

  void _typographySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.c.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => AnimatedBuilder(
        animation: s,
        builder: (ctx, _) => Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetGrip(),
              Text('Reading', style: ctx.headline.copyWith(fontSize: 20)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text('Text size', style: ctx.small),
                  const Spacer(),
                  _step(ctx, Icons.remove_rounded, () => s.setFontSize(s.fontSize - 1)),
                  SizedBox(
                    width: 44,
                    child: Text('${s.fontSize.round()}',
                        textAlign: TextAlign.center,
                        style: ctx.mono.copyWith(fontSize: 14, color: ctx.c.ink)),
                  ),
                  _step(ctx, Icons.add_rounded, () => s.setFontSize(s.fontSize + 1)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('Line spacing', style: ctx.small),
                  Expanded(
                    child: Slider(
                      value: s.lineHeight,
                      min: 1.3,
                      max: 2.0,
                      divisions: 7,
                      activeColor: ctx.c.accent,
                      onChanged: s.setLineHeight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('TYPE FACE', style: ctx.label),
              const SizedBox(height: 8),
              Row(
                children: [
                  _choice(ctx, 'Serif', s.readerFace == 'serif',
                      () => s.setFace('serif')),
                  const SizedBox(width: 8),
                  _choice(ctx, 'Sans', s.readerFace == 'sans',
                      () => s.setFace('sans')),
                ],
              ),
              const SizedBox(height: 18),
              Text('PAGE', style: ctx.label),
              const SizedBox(height: 8),
              Row(
                children: [
                  _themeSwatch(ctx, ReaderTheme.paper, 'Paper',
                      const Color(0xFFFBF8F0)),
                  const SizedBox(width: 8),
                  _themeSwatch(ctx, ReaderTheme.sepia, 'Sepia',
                      const Color(0xFFF2E7D3)),
                  const SizedBox(width: 8),
                  _themeSwatch(ctx, ReaderTheme.night, 'Night',
                      const Color(0xFF121212)),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (mounted) {
        _restored = false;
        _render();
      }
    });
  }

  Widget _step(BuildContext ctx, IconData icon, VoidCallback onTap) {
    final c = ctx.c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 17, color: c.ink),
      ),
    );
  }

  Widget _choice(
      BuildContext ctx, String label, bool active, VoidCallback onTap) {
    final c = ctx.c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? c.accent : Colors.transparent,
          border: Border.all(color: active ? c.accent : c.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: active ? c.accentInk : c.muted,
            fontFamily: label == 'Serif' ? 'Georgia' : null,
          ),
        ),
      ),
    );
  }

  Widget _themeSwatch(
      BuildContext ctx, ReaderTheme t, String label, Color bg) {
    final c = ctx.c;
    final active = s.readerTheme == t;
    return Expanded(
      child: GestureDetector(
        onTap: () => s.setReaderTheme(t),
        child: Container(
          height: 54,
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active ? c.accent : c.line,
              width: active ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: t == ReaderTheme.night
                  ? const Color(0xFFD9D3C7)
                  : const Color(0xFF4A4137),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _more() async {
    final c = context.c;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.only(top: 18), child: SheetGrip()),
            ListTile(
              leading: Icon(Icons.open_in_new_rounded, size: 20, color: ctx.c.ink),
              title: Text('Open original', style: ctx.body),
              onTap: () {
                Navigator.of(ctx).pop();
                launchUrl(Uri.parse(e.url), mode: LaunchMode.externalApplication);
              },
            ),
            ListTile(
              leading: Icon(Icons.text_fields_rounded,
                  size: 20, color: ctx.c.ink),
              title: Text('Reading settings', style: ctx.body),
              onTap: () {
                Navigator.of(ctx).pop();
                _typographySheet();
              },
            ),
            ListTile(
              leading: Icon(Icons.copy_rounded, size: 20, color: ctx.c.ink),
              title: Text('Copy link', style: ctx.body),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: e.url));
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Link copied'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: c.ink,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  size: 20, color: ctx.c.danger),
              title: Text('Delete from wallabag',
                  style: ctx.body.copyWith(color: ctx.c.danger)),
              onTap: () async {
                Navigator.of(ctx).pop();
                await s.delete(e);
                if (mounted) Navigator.of(context).maybePop();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _chromeColors;
    return PopScope(
      onPopInvokedWithResult: (_, _) => _persist(),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _topBar(c),
              Expanded(
                child: (_loadingContent || _loadError != null)
                    ? Center(
                        child: _loadError != null
                            ? Padding(
                                padding: const EdgeInsets.all(30),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.cloud_off_rounded,
                                        size: 30, color: c.muted),
                                    const SizedBox(height: 14),
                                    Text(_loadError!,
                                        textAlign: TextAlign.center,
                                        style: context.small),
                                    const SizedBox(height: 18),
                                    GhostButton(
                                      label: 'Open original',
                                      height: 44,
                                      onPressed: () => launchUrl(
                                          Uri.parse(e.url),
                                          mode: LaunchMode.externalApplication),
                                    ),
                                  ],
                                ),
                              )
                            : const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : WebViewWidget(controller: _web),
              ),
              _bottomBar(c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(FolioColors c) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: Row(
        children: [
          IconAction(
            icon: Icons.arrow_back_rounded,
            color: c.ink,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  e.site.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.label.copyWith(
                    fontSize: 9,
                    color: c.muted,
                    letterSpacing: 1.2,
                  ),
                ),
                if (_progress > 0.01) ...[
                  const SizedBox(height: 3),
                  Text('${(_progress * 100).round()}%',
                      style:
                          context.mono.copyWith(fontSize: 10, color: c.faint)),
                ],
              ],
            ),
          ),
          IconAction(
            icon: e.starred ? Icons.star_rounded : Icons.star_border_rounded,
            color: e.starred ? c.accent : c.ink,
            onTap: () {
              HapticFeedback.selectionClick();
              s.setStarred(e, !e.starred);
              setState(() {});
            },
          ),
          IconAction(
            icon: e.archived
                ? Icons.unarchive_outlined
                : Icons.archive_outlined,
            color: c.ink,
            onTap: () async {
              HapticFeedback.selectionClick();
              await s.setArchived(e, !e.archived);
              if (!mounted) return;
              setState(() {});
              if (e.archived) Navigator.of(context).maybePop();
            },
          ),
          IconAction(
            icon: Icons.more_horiz_rounded,
            color: c.ink,
            onTap: _more,
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(FolioColors c) {
    final remaining = ((1 - _progress) * (e.readingTime > 0 ? e.readingTime : 5))
        .ceil()
        .clamp(0, 90);
    return Container(
      color: _bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 2,
              backgroundColor: c.line.withValues(alpha: 0.7),
              valueColor: AlwaysStoppedAnimation(c.accent),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 10, 2),
              child: Row(
                children: [
                  Text(
                    remaining == 0 ? 'Finished' : '$remaining min left',
                    style: context.small.copyWith(fontSize: 11.5, color: c.muted),
                  ),
                  const Spacer(),
                  IconAction(
                    icon: _speaking
                        ? Icons.stop_circle_outlined
                        : Icons.headphones_rounded,
                    color: _speaking ? c.accent : c.ink,
                    onTap: _toggleSpeak,
                  ),
                  GestureDetector(
                    onTap: _typographySheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: c.line),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text('Aa',
                          style: context.body.copyWith(
                              fontFamily: 'Georgia', fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

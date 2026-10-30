import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../wallabag.dart';
import '../widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = store;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: c.line),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back_rounded,
                        size: 17, color: c.ink),
                  ),
                ),
                const Spacer(),
                Text('SETTINGS', style: context.label),
                const Spacer(),
                const SizedBox(width: 36),
              ],
            ),
            const SizedBox(height: 24),
            Text('Your library', style: context.display.copyWith(fontSize: 30)),
            const SizedBox(height: 22),
            _Panel(
              children: [
                _Row(
                  label: 'Server',
                  value: s.isDemo ? 'Sample articles' : s.baseUrl,
                ),
                _divider(c),
                _Row(
                  label: 'Account',
                  value: s.isDemo ? 'Demo mode' : s.userName.isEmpty ? '—' : s.userName,
                ),
                _divider(c),
                _Row(
                  label: 'Last sync',
                  value: s.lastSync == null
                      ? 'never'
                      : _ago(s.lastSync!),
                ),
                _divider(c),
                _Row(
                  label: 'Articles cached',
                  value: '${s.entries.length} · ${s.downloaded.length} offline',
                ),
                if (s.queue.isNotEmpty) ...[
                  _divider(c),
                  _Row(label: 'Pending changes', value: '${s.queue.length}'),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (s.isDemo)
              GhostButton(
                label: 'Leave demo and connect a server',
                onPressed: () async {
                  await s.disconnect();
                  if (context.mounted) Navigator.of(context).pop();
                },
              )
            else ...[
              GhostButton(
                label: 'Sync now',
                icon: Icons.sync_rounded,
                onPressed: () => s.sync(full: true),
              ),
              const SizedBox(height: 8),
              GhostButton(
                label: 'Disconnect',
                danger: true,
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: c.bg,
                      title: Text('Disconnect?', style: ctx.headline),
                      content: Text(
                        'The cached articles on this phone will be removed. '
                        'Nothing on your wallabag server is touched.',
                        style: ctx.body,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text('Cancel',
                              style: TextStyle(color: c.muted)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text('Disconnect',
                              style: TextStyle(color: c.danger)),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await s.disconnect();
                    if (context.mounted) Navigator.of(context).pop();
                  }
                },
              ),
            ],
            const SizedBox(height: 28),
            Text('Reading', style: context.headline.copyWith(fontSize: 20)),
            const SizedBox(height: 12),
            _Panel(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(
                    children: [
                      Text('Text size', style: context.small),
                      const Spacer(),
                      Text('${s.fontSize.round()}',
                          style: context.mono.copyWith(color: c.ink)),
                      SizedBox(
                        width: 150,
                        child: Slider(
                          value: s.fontSize,
                          min: 15,
                          max: 30,
                          divisions: 15,
                          activeColor: c.accent,
                          onChanged: s.setFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
                _divider(c),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      Text('Page', style: context.small),
                      const Spacer(),
                      for (final t in ReaderTheme.values) ...[
                        GestureDetector(
                          onTap: () => s.setReaderTheme(t),
                          child: Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: s.readerTheme == t
                                  ? c.accent
                                  : Colors.transparent,
                              border: Border.all(
                                color: s.readerTheme == t ? c.accent : c.line,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              switch (t) {
                                ReaderTheme.paper => 'Paper',
                                ReaderTheme.sepia => 'Sepia',
                                ReaderTheme.night => 'Night',
                              },
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: s.readerTheme == t ? c.accentInk : c.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Panel(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
                  child: Row(
                    children: [
                      Icon(Icons.dark_mode_outlined, size: 18, color: c.muted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dark interface', style: context.body),
                            Text('The reader page follows the setting above.',
                                style: context.small.copyWith(fontSize: 11.5)),
                          ],
                        ),
                      ),
                      Transform.scale(
                        scale: 0.82,
                        child: Switch(
                          value: s.darkMode,
                          activeThumbColor: c.accentInk,
                          activeTrackColor: c.accent,
                          inactiveThumbColor: c.faint,
                          inactiveTrackColor: c.surfaceAlt,
                          trackOutlineColor:
                              WidgetStateProperty.all(Colors.transparent),
                          onChanged: s.setDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text('About', style: context.headline.copyWith(fontSize: 20)),
            const SizedBox(height: 12),
            _Panel(
              children: [
                _Row(label: 'Folio', value: '1.0.1'),
                _divider(c),
                _Row(label: 'API', value: 'wallabag v2'),
                _divider(c),
                InkWell(
                  onTap: () => launchUrl(
                    Uri.parse('https://doc.wallabag.org/api/'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: _Row(label: 'wallabag API docs', value: '↗'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Folio has no servers of its own. Your articles, progress and '
              'stars live on your wallabag instance and in this phone\'s '
              'storage. There is no account, no telemetry, and nothing to '
              'shut down that would take your library with it.',
              style: context.small.copyWith(fontSize: 11.5, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(FolioColors c) => Divider(height: 1, color: c.line);

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(label, style: context.small.copyWith(fontSize: 13, color: c.muted)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.small.copyWith(fontSize: 13, color: c.ink),
            ),
          ),
        ],
      ),
    );
  }
}

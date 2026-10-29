import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../wallabag.dart';
import '../widgets.dart';
import 'reader.dart';
import 'settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _searching = false;
  final _search = TextEditingController();

  AppStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    if (s.entries.isEmpty && !s.isDemo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => s.sync(full: true));
    }
    if (const bool.fromEnvironment('OPEN_SETTINGS')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SettingsScreen(store: s)),
        );
      });
    }
    const debugEntry = int.fromEnvironment('OPEN_ENTRY', defaultValue: 0);
    if (debugEntry != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final e = s.byId(debugEntry);
        if (e != null) _open(e);
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _title {
    switch (s.box) {
      case Box.unread:
        return 'Unread';
      case Box.starred:
        return 'Starred';
      case Box.archived:
        return 'Archive';
      case Box.all:
        return 'Library';
    }
  }

  int get _count {
    switch (s.box) {
      case Box.unread:
        return s.unreadCount;
      case Box.starred:
        return s.starredCount;
      case Box.archived:
        return s.archivedCount;
      case Box.all:
        return s.entries.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final items = s.visible;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.menu_book_rounded,
                        size: 14, color: c.accentInk),
                  ),
                  const SizedBox(width: 9),
                  Text('FOLIO',
                      style: context.label.copyWith(letterSpacing: 2.4)),
                  if (s.isDemo) ...[
                    const SizedBox(width: 8),
                    const Tag('DEMO', tone: TagTone.accent),
                  ],
                  const Spacer(),
                  IconAction(
                    icon: _searching ? Icons.close_rounded : Icons.search_rounded,
                    onTap: () {
                      setState(() {
                        _searching = !_searching;
                        if (!_searching) {
                          _search.clear();
                          s.setQuery('');
                        }
                      });
                    },
                  ),
                  if (s.phase == SyncPhase.syncing)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 1.6),
                      ),
                    )
                  else
                    IconAction(
                      icon: Icons.sync_rounded,
                      onTap: () => s.sync(full: s.entries.isEmpty),
                    ),
                  IconAction(
                    icon: Icons.tune_rounded,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(store: s),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(_title, style: context.display.copyWith(fontSize: 34)),
                  const SizedBox(width: 10),
                  Text('$_count',
                      style: context.display.copyWith(
                        fontSize: 34,
                        color: c.faint,
                        fontWeight: FontWeight.w400,
                      )),
                  const Spacer(),
                  if (s.lastSync != null)
                    Text(
                      s.phase == SyncPhase.syncing
                          ? 'syncing…'
                          : 'synced ${_ago(s.lastSync!)}',
                      style: context.small.copyWith(fontSize: 11),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: _searching
                  ? _SearchField(controller: _search, onChanged: s.setQuery)
                  : _Filters(store: s),
            ),
            if (s.error != null)
              NoticeBar(
                text: s.error!,
                warn: s.phase == SyncPhase.error,
              ),
            if (s.phase == SyncPhase.syncing && s.entries.isEmpty)
              const Expanded(
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => s.sync(full: s.entries.isEmpty),
                  color: c.accent,
                  backgroundColor: c.surface,
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.45,
                              child: _empty(),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 120),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            thickness: 1,
                            color: c.line,
                            indent: 20,
                            endIndent: 20,
                          ),
                          itemBuilder: (_, i) {
                            final e = items[i];
                            return _Swipeable(
                              entry: e,
                              store: s,
                              child: EntryTile(
                                entry: e,
                                store: s,
                                onTap: () => _open(e),
                                onLongPress: () => _actions(e),
                              ),
                            );
                          },
                        ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: s.isDemo
          ? null
          : FloatingActionButton(
              onPressed: _addSheet,
              backgroundColor: c.accent,
              foregroundColor: c.accentInk,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.add_rounded),
            ),
    );
  }

  Widget _empty() {
    switch (s.box) {
      case Box.unread:
        return EmptyState(
          icon: Icons.check_rounded,
          title: 'Caught up',
          body: 'Nothing waiting. Save something worth reading, not everything '
              'you might.',
          action: s.isDemo
              ? null
              : GhostButton(
                  label: 'Save a link',
                  icon: Icons.add_link_rounded,
                  height: 44,
                  onPressed: _addSheet,
                ),
        );
      case Box.starred:
        return const EmptyState(
          icon: Icons.star_border_rounded,
          title: 'No stars',
          body: 'Star the pieces you want to come back to. They stay here, '
              'offline included.',
        );
      case Box.archived:
        return const EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Archive is empty',
          body: 'Finished articles land here. Nothing is deleted unless you '
              'delete it.',
        );
      case Box.all:
        return EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'Your library is empty',
          body: s.isDemo
              ? 'Sample articles should be here. Try reconnecting.'
              : 'Add a link, or save one from your browser with the wallabag '
                  'extension.',
          action: s.isDemo
              ? null
              : GhostButton(
                  label: 'Sync now',
                  icon: Icons.sync_rounded,
                  height: 44,
                  onPressed: () => s.sync(full: true),
                ),
        );
    }
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  Future<void> _open(Entry e) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(store: s, entry: e)),
    );
    if (mounted) setState(() {});
  }

  Future<void> _addSheet() async {
    final controller = TextEditingController();
    final tags = TextEditingController();
    String? error;
    var busy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final c = ctx.c;
          return Padding(
            padding: EdgeInsets.only(
              left: 22,
              right: 22,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetGrip(),
                Text('Save a link', style: ctx.headline),
                const SizedBox(height: 4),
                Text(
                  'wallabag fetches the article. You can read it here even '
                  'without a connection afterwards.',
                  style: ctx.small.copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  style: TextStyle(fontSize: 14.5, color: c.ink),
                  cursorColor: c.accent,
                  decoration: InputDecoration(
                    hintText: 'https://…',
                    hintStyle: TextStyle(color: c.faint, fontSize: 14),
                    filled: true,
                    fillColor: c.surface,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tags,
                  style: TextStyle(fontSize: 13.5, color: c.ink),
                  cursorColor: c.accent,
                  decoration: InputDecoration(
                    hintText: 'tags, optional (comma separated)',
                    hintStyle: TextStyle(color: c.faint, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: c.line),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: c.accent),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!,
                      style: ctx.small.copyWith(color: c.danger, fontSize: 12)),
                ],
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Save to wallabag',
                  busy: busy,
                  onPressed: busy
                      ? null
                      : () async {
                          final url = controller.text.trim();
                          if (!url.startsWith('http')) {
                            setSheet(() => error = 'Use a full http(s) URL.');
                            return;
                          }
                          setSheet(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            final e = await s.addUrl(
                              url,
                              tags: tags.text
                                  .split(',')
                                  .map((t) => t.trim())
                                  .where((t) => t.isNotEmpty)
                                  .toList(),
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (e != null) _open(e);
                          } catch (err) {
                            setSheet(() {
                              busy = false;
                              error = err is WallabagException
                                  ? err.message
                                  : 'Could not save that link.';
                            });
                          }
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _actions(Entry e) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.c.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final c = ctx.c;
        Widget row(IconData icon, String label, VoidCallback onTap,
            {bool danger = false}) {
          return InkWell(
            onTap: () {
              Navigator.of(ctx).pop();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: danger ? c.danger : c.ink),
                  const SizedBox(width: 14),
                  Text(label,
                      style: ctx.body.copyWith(
                        fontSize: 15,
                        color: danger ? c.danger : c.ink,
                      )),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: SheetGrip(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 6),
                child: Text(e.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ctx.headline.copyWith(fontSize: 18)),
              ),
              const SizedBox(height: 6),
              row(
                e.starred ? Icons.star_rounded : Icons.star_border_rounded,
                e.starred ? 'Remove star' : 'Star',
                () => s.setStarred(e, !e.starred),
              ),
              row(
                e.archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                e.archived ? 'Move to unread' : 'Archive',
                () => s.setArchived(e, !e.archived),
              ),
              row(Icons.open_in_new_rounded, 'Open original', () {
                launchUrl(Uri.parse(e.url), mode: LaunchMode.externalApplication);
              }),
              row(Icons.delete_outline_rounded, 'Delete from wallabag',
                  () => s.delete(e),
                  danger: true),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 17, color: c.faint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: onChanged,
              style: TextStyle(fontSize: 14, color: c.ink),
              cursorColor: c.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search titles, sources, tags',
                hintStyle: TextStyle(color: c.faint, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const labels = ['Unread', 'Starred', 'Archive', 'All'];
    const boxes = [Box.unread, Box.starred, Box.archived, Box.all];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = store.box == boxes[i];
          return GestureDetector(
            onTap: () => store.setBox(boxes[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? c.ink : Colors.transparent,
                border: Border.all(color: active ? c.ink : c.line),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: active ? c.bg : c.muted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Swipeable extends StatelessWidget {
  const _Swipeable({
    required this.entry,
    required this.store,
    required this.child,
  });

  final Entry entry;
  final AppStore store;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Dismissible(
      key: ValueKey('swipe-${entry.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        // Archive without waiting for the network; the queue handles the rest.
        await store.setArchived(entry, !entry.archived);
        return false;
      },
      background: Container(
        color: c.accentSoft,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              entry.archived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              size: 18,
              color: c.accent,
            ),
            const SizedBox(width: 8),
            Text(entry.archived ? 'Unarchive' : 'Archive',
                style: TextStyle(fontSize: 12, color: c.accent)),
          ],
        ),
      ),
      child: child,
    );
  }
}

class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.store,
    required this.onTap,
    required this.onLongPress,
  });

  final Entry entry;
  final AppStore store;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  String get _age {
    if (entry.createdAt == 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(entry.createdAt * 1000);
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final raw = entry.previewPicture?.trim();
    final picture = (raw == null || raw.isEmpty) ? null : _resolve(raw);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (entry.starred) ...[
                        Icon(Icons.star_rounded, size: 12, color: c.accent),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        entry.site.toUpperCase(),
                        style: context.label.copyWith(
                          fontSize: 9.5,
                          color: c.faint,
                          letterSpacing: 0.9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.title,
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text(entry.readingLabel,
                          style: context.small.copyWith(fontSize: 11.5)),
                      const SizedBox(width: 8),
                      Text('·', style: TextStyle(color: c.faint, fontSize: 11)),
                      const SizedBox(width: 8),
                      Text(_age,
                          style: context.mono.copyWith(fontSize: 10.5)),
                      if (entry.tags.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text('·', style: TextStyle(color: c.faint, fontSize: 11)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            entry.tags.first,
                            style: context.small.copyWith(
                              fontSize: 10.5,
                              color: c.accent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (entry.progress > 0 && entry.progress < 0.98) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: entry.progress,
                        minHeight: 2,
                        backgroundColor: c.line,
                        valueColor: AlwaysStoppedAnimation(c.accent),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (picture != null) ...[
              const SizedBox(width: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 62,
                  height: 62,
                  child: Image.network(
                    picture,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    loadingBuilder: (ctx, child, progress) => progress == null
                        ? child
                        : Container(color: c.surfaceAlt),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _resolve(String url) {
    if (url.startsWith('http')) return url;
    final base = store.baseUrl;
    if (base.isEmpty) return url;
    return '$base${url.startsWith('/') ? '' : '/'}$url';
  }
}

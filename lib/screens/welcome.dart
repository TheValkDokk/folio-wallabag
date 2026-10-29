import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../wallabag.dart';
import '../widgets.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _form = false;
  bool _tokenMode = false;
  bool _busy = false;
  bool _showHelp = false;
  String? _error;

  final _server = TextEditingController();
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _token = TextEditingController();

  @override
  void dispose() {
    for (final c in [_server, _clientId, _clientSecret, _user, _pass, _token]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_server.text.trim().isEmpty) {
        throw WallabagException('Enter your wallabag address first.');
      }
      if (_tokenMode) {
        if (_token.text.trim().isEmpty) {
          throw WallabagException('Paste an access token.');
        }
        await widget.store.connectWithToken(
          baseUrl: _server.text,
          token: _token.text,
        );
      } else {
        await widget.store.connectWithPassword(
          baseUrl: _server.text,
          clientId: _clientId.text,
          clientSecret: _clientSecret.text,
          username: _user.text,
          password: _pass.text,
        );
      }
      if (mounted) Navigator.of(context).maybePop();
    } on WallabagException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not reach that server. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: _form ? _buildForm(c) : _buildIntro(c),
        ),
      ),
    );
  }

  Widget _buildIntro(FolioColors c) {
    return Padding(
      key: const ValueKey('intro'),
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _mark(c),
              const SizedBox(width: 9),
              Text('FOLIO', style: context.label.copyWith(letterSpacing: 2.6)),
              const Spacer(),
              Text('a wallabag reader', style: context.small.copyWith(fontSize: 11)),
            ],
          ),
          const Spacer(flex: 2),
          Text('Your reading,\noff the feed.', style: context.display.copyWith(fontSize: 42, height: 1.08)),
          const SizedBox(height: 16),
          Text(
            'A calm, offline-first reader for your own wallabag. '
            'No account with us, no recommendations, no next-up carousel.',
            style: context.body.copyWith(color: c.muted, fontSize: 15, height: 1.55),
          ),
          const SizedBox(height: 28),
          _previewStrip(c),
          const Spacer(flex: 3),
          PrimaryButton(
            label: 'Connect my wallabag',
            icon: Icons.lock_outline_rounded,
            onPressed: () => setState(() => _form = true),
          ),
          const SizedBox(height: 10),
          GhostButton(
            label: 'Look around with sample articles',
            height: 50,
            onPressed: () => widget.store.startDemo(),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'Works with wallabag 2.4 and newer',
              style: context.small.copyWith(fontSize: 11, color: c.faint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mark(FolioColors c) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(Icons.menu_book_rounded, size: 15, color: c.accentInk),
    );
  }

  Widget _previewStrip(FolioColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TODAY', style: context.label.copyWith(fontSize: 9.5)),
          const SizedBox(height: 10),
          Text('The Case for Slow Software',
              style: context.title.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text('example.com · 9 min read', style: context.small.copyWith(fontSize: 11.5)),
          const SizedBox(height: 12),
          Divider(color: c.line, height: 1),
          const SizedBox(height: 12),
          Text('What Pocket\'s shutdown taught us about ownership',
              style: context.title.copyWith(fontSize: 14, color: c.muted)),
          const SizedBox(height: 4),
          Text('example.com · 6 min read',
              style: context.small.copyWith(fontSize: 11, color: c.faint)),
          const SizedBox(height: 14),
          Row(
            children: [
              _pill(c, Icons.cloud_off_rounded, 'Offline'),
              const SizedBox(width: 8),
              _pill(c, Icons.text_fields_rounded, 'Your type'),
              const SizedBox(width: 8),
              _pill(c, Icons.headphones_rounded, 'Read aloud'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(FolioColors c, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: c.muted),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(fontSize: 10, color: c.muted, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildForm(FolioColors c) {
    return ListView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.fromLTRB(28, 6, 28, 40),
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _form = false),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: c.line),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back_rounded, size: 17, color: c.ink),
              ),
            ),
            const Spacer(),
            Text('CONNECT', style: context.label),
            const Spacer(),
            const SizedBox(width: 36),
          ],
        ),
        const SizedBox(height: 26),
        Text('Where is your\nlibrary?', style: context.display.copyWith(fontSize: 30)),
        const SizedBox(height: 10),
        Text(
          'Folio talks straight to your server over the wallabag API. '
          'Nothing passes through anyone else.',
          style: context.small.copyWith(height: 1.55),
        ),
        const SizedBox(height: 22),
        Field(
          label: 'Wallabag address',
          controller: _server,
          hint: 'https://bag.example.com',
          keyboard: TextInputType.url,
          helper: 'The root of your install, no /api at the end.',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _ModeTab(
              label: 'Password',
              active: !_tokenMode,
              onTap: () => setState(() => _tokenMode = false),
            ),
            const SizedBox(width: 8),
            _ModeTab(
              label: 'Access token',
              active: _tokenMode,
              onTap: () => setState(() => _tokenMode = true),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_tokenMode)
          Field(
            label: 'Token',
            controller: _token,
            hint: 'Paste the access_token',
            obscure: true,
            helper: 'Useful when your instance already gave you a long-lived token.',
          )
        else ...[
          Field(
            label: 'Client ID',
            controller: _clientId,
            hint: '1_3abc...',
          ),
          const SizedBox(height: 12),
          Field(
            label: 'Client secret',
            controller: _clientSecret,
            hint: 'secret',
            obscure: true,
          ),
          const SizedBox(height: 12),
          Field(
            label: 'Username',
            controller: _user,
            hint: 'you',
          ),
          const SizedBox(height: 12),
          Field(
            label: 'Password',
            controller: _pass,
            hint: '••••••••',
            obscure: true,
          ),
        ],
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => setState(() => _showHelp = !_showHelp),
          child: Row(
            children: [
              Icon(Icons.help_outline_rounded, size: 15, color: c.muted),
              const SizedBox(width: 6),
              Text('Where do I find the client id and secret?',
                  style: context.small.copyWith(
                    fontSize: 12,
                    color: c.ink,
                    decoration: TextDecoration.underline,
                    decorationColor: c.line,
                  )),
            ],
          ),
        ),
        if (_showHelp) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _helpStep(c, '1', 'Open wallabag in a browser and sign in.'),
                _helpStep(c, '2', 'Go to Developer (or /developer) and create a client.'),
                _helpStep(c, '3', 'Copy the client id and secret into the fields above.'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse('https://doc.wallabag.org/api/client/'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(
                    'Open the wallabag API docs →',
                    style: context.small.copyWith(
                      fontSize: 12,
                      color: c.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.danger.withValues(alpha: 0.25)),
            ),
            child: Text(_error!,
                style: context.small.copyWith(color: c.danger, fontSize: 12.5)),
          ),
        ],
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Connect',
          busy: _busy,
          onPressed: _connect,
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Your password is used once to get a token and never stored.',
            textAlign: TextAlign.center,
            style: context.small.copyWith(fontSize: 10.5, color: c.faint),
          ),
        ),
      ],
    );
  }

  Widget _helpStep(FolioColors c, String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n, style: context.mono.copyWith(color: c.faint)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: context.small.copyWith(fontSize: 12, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.accent : Colors.transparent,
          border: Border.all(color: active ? c.accent : c.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? c.accentInk : c.muted,
          ),
        ),
      ),
    );
  }
}

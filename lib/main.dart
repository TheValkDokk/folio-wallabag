import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home.dart';
import 'screens/welcome.dart';
import 'theme.dart';
import 'wallabag.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();

  // Development hook: point the app at tool/mock_wallabag.py without tapping
  // through the connect form.
  const mock = String.fromEnvironment('MOCK_CONNECT');
  if (mock.isNotEmpty) {
    try {
      if (store.isDemo) await store.disconnect();
      await store.connectWithToken(baseUrl: mock, token: 'mock-token');
    } catch (e) {
      debugPrint('mock connect failed: $e');
    }
  }

  // Development hook: run the real OAuth password grant against a live
  // server without tapping through the connect form.
  //   --dart-define=CONNECT_URL=... --dart-define=CONNECT_CLIENT=...
  //   --dart-define=CONNECT_SECRET=... --dart-define=CONNECT_USER=...
  //   --dart-define=CONNECT_PASS=...
  const connectUrl = String.fromEnvironment('CONNECT_URL');
  if (connectUrl.isNotEmpty) {
    try {
      if (store.connected) await store.disconnect();
      await store.connectWithPassword(
        baseUrl: connectUrl,
        clientId: const String.fromEnvironment('CONNECT_CLIENT'),
        clientSecret: const String.fromEnvironment('CONNECT_SECRET'),
        username: const String.fromEnvironment('CONNECT_USER'),
        password: const String.fromEnvironment('CONNECT_PASS'),
      );
      debugPrint('CONNECT ok: ${store.entries.length} entries, '
          'user=${store.userName}, token=${store.accessToken != null}');
    } catch (e) {
      debugPrint('CONNECT failed: $e');
    }
  }

  runApp(FolioApp(store: store));
}

class FolioApp extends StatelessWidget {
  const FolioApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final dark = store.darkMode;
        return MaterialApp(
          title: 'Folio',
          debugShowCheckedModeBanner: false,
          theme: folioTheme(Brightness.light),
          darkTheme: folioTheme(Brightness.dark),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            final c = context.c;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    dark ? Brightness.light : Brightness.dark,
                statusBarBrightness:
                    dark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: c.bg,
                systemNavigationBarIconBrightness:
                    dark ? Brightness.light : Brightness.dark,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: store.connected
              ? HomeScreen(store: store)
              : WelcomeScreen(store: store),
        );
      },
    );
  }
}

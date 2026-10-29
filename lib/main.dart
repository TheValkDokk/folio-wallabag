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

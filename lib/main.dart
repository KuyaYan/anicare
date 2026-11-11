import 'package:flutter/material.dart';
import 'auth.dart';
import 'data.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.init(); // opens the SQLite database (theme + login session are saved in it)
  runApp(const AniCareApp());
}

class AniCareApp extends StatelessWidget {
  const AniCareApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (c, _) => Stamp(
          dark: app.dark,
          child: MaterialApp(
          title: 'AniCare',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          themeAnimationDuration: Duration.zero, // text / shapes change instantly
          home: const SplashPage(),
        )),
      );
}

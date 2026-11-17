import 'package:flutter/material.dart';
import 'auth.dart';
import 'data.dart';
import 'notify.dart';
import 'repo.dart';
import 'vet.dart';
import 'notifications.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // opens the local database (and Supabase, if config.dart has keys)
  await notifier.init();
  await app.init();
  onRepoError = (m) => messengerKey.currentState
      ?.showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
  // an account that the admin switched off is sent back to the login screen
  // tapping a phone notification (or its "Extend plan" button) opens the right screen
  notifier.onTap = (payload) {
    final nav = navKey.currentState;
    if (nav == null || app.user == null) return;
    if (payload == 'plan' && app.role == Role.store) {
      nav.push(MaterialPageRoute(builder: (_) => const StorePlanPage()));
    } else {
      nav.push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
    }
  };
  onForceLogout = () {
    navKey.currentState?.pushAndRemoveUntil(instantRoute(const LoginPage()), (r) => false);
    messengerKey.currentState?.showSnackBar(const SnackBar(
        content: Text('This account was deactivated. Contact the admin.'), behavior: SnackBarBehavior.floating));
  };
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
            navigatorKey: navKey,
            scaffoldMessengerKey: messengerKey,
            theme: buildTheme(),
            builder: (context, child) => ColoredBox(color: C.surface, child: child),
            themeAnimationDuration: Duration.zero, // text / shapes change instantly
            home: const SplashPage(),
          ),
        ),
      );
}

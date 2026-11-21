import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'data.dart';
import 'auth.dart';
import 'notifications.dart';
import 'settings.dart';

/// Colors: light = from the PPT, dark = from the dark logo.
class C {
  static bool get d => app.dark;
  static Color get green => d ? const Color(0xFF189818) : const Color(0xFF075215);
  static Color get navy => d ? const Color(0xFF283888) : const Color(0xFF1F3B57);
  static Color get amber => d ? const Color(0xFFC88838) : const Color(0xFFF2A73B);
  static Color get brown => d ? const Color(0xFFE0A860) : const Color(0xFF664230);
  static Color get ink => d ? const Color(0xFFF2F5F8) : const Color(0xFF111418);
  static Color get surface => d ? const Color(0xFF1B2733) : Colors.white;
  static Color get pill => surface.withAlpha(204); // 80% solid
  static Color get bar => d ? const Color(0xFF0F1822) : const Color(0xFF075215);
  static Color get ring => d ? const Color(0xFF189818) : const Color(0xFF2E8B2E);
  static Color get logoBg => d ? Colors.black : Colors.white;
  static Color get brandNavy => d ? const Color(0xFFE6EEF7) : const Color(0xFF1F3B57);
  static const onAmber = Color(0xFF1B2733);
}

/// App version (keep in sync with pubspec.yaml)
const String kVersion = '1.3.2';

const double kHero = 138; // clear (un-blurred) part of the background
const double kAd = 56;
const double rSq = 4; // "square" corners
const double rPill = 16; // squarish pill corners

TextStyle h(double s, [Color? c]) => TextStyle(
    fontFamily: 'ZillaSlab', fontWeight: FontWeight.w700, fontSize: s, color: c ?? C.ink);
TextStyle hi(double s, [Color? c]) => TextStyle(
    fontFamily: 'ZillaSlab',
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.italic,
    fontSize: s,
    color: c ?? C.brown);

ThemeData buildTheme() {
  final base = ThemeData(brightness: C.d ? Brightness.dark : Brightness.light, useMaterial3: true);
  final cs = ColorScheme.fromSeed(
          seedColor: C.green, brightness: C.d ? Brightness.dark : Brightness.light)
      .copyWith(
          primary: C.green,
          secondary: C.amber,
          onSecondary: C.onAmber,
          surface: C.surface,
          onSurface: C.ink,
          surfaceContainerHigh: C.surface);
  return base.copyWith(
    colorScheme: cs,
    scaffoldBackgroundColor: C.surface,
    canvasColor: C.surface,
    textTheme: base.textTheme.apply(fontFamily: 'DMSans', bodyColor: C.ink, displayColor: C.ink),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'DMSans'),
    appBarTheme: AppBarTheme(
        backgroundColor: C.bar,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleTextStyle: h(22, Colors.white)),
    navigationBarTheme: NavigationBarThemeData(
        backgroundColor: C.surface,
        indicatorColor: C.amber.withAlpha(140),
        labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontFamily: 'DMSans', fontSize: 12, fontWeight: FontWeight.w600, color: C.ink)),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: C.ink))),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: C.surface),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: C.green,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            textStyle: const TextStyle(fontFamily: 'DMSans', fontWeight: FontWeight.w700, fontSize: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rPill)))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            foregroundColor: C.ink,
            backgroundColor: C.pill,
            side: BorderSide(color: C.green, width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rPill)))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: C.green)),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: C.surface,
        labelStyle: TextStyle(color: C.ink),
        hintStyle: TextStyle(color: C.ink.withAlpha(170)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(rPill), borderSide: BorderSide.none)),
    snackBarTheme: SnackBarThemeData(
        backgroundColor: C.d ? const Color(0xFFF2F5F8) : const Color(0xFF1B2733),
        contentTextStyle: TextStyle(color: C.d ? const Color(0xFF111418) : Colors.white)),
  );
}

final messengerKey = GlobalKey<ScaffoldMessengerState>();
final navKey = GlobalKey<NavigatorState>();

/// A list you can pull down at the top to refresh (re-syncs with Supabase).
class RList extends StatelessWidget {
  final EdgeInsetsGeometry? padding;
  final List<Widget> children;
  const RList({super.key, this.padding, required this.children});
  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: app.refresh,
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(), padding: padding, children: children),
      );
}

/// Live password rules shown while typing.
Widget pwChecklist(String pw) {
  final k = PwCheck(pw);
  Widget row(bool ok, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 17, color: ok ? C.green : C.ink.withAlpha(150)),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: ok ? FontWeight.w700 : FontWeight.w400))),
        ]),
      );
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(rPill)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      row(k.len, '8 to 32 characters'),
      row(k.letter, 'At least one letter'),
      row(k.digit, 'At least one number'),
      row(k.symbol, 'At least one symbol, for example ! @ # %'),
      row(k.noSpace, 'No spaces'),
    ]),
  );
}

/// Rebuilds a screen whenever app state OR the light/dark mode changes.
Widget rx(Widget Function(BuildContext) b) =>
    ListenableBuilder(listenable: app, builder: (c, _) => b(c));


/// Tells every themed widget to rebuild when light/dark changes
/// (needed because `const` widgets are otherwise never rebuilt).
class Stamp extends InheritedWidget {
  final bool dark;
  const Stamp({super.key, required this.dark, required super.child});
  static void watch(BuildContext c) => c.dependOnInheritedWidgetOfExactType<Stamp>();
  @override
  bool updateShouldNotify(Stamp old) => old.dark != dark;
}

String money(num v) => '₱${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}';
const _m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String fmt(DateTime d) => '${_m[d.month - 1]} ${d.day}, ${d.year}';
void toast(BuildContext c, String m) => ScaffoldMessenger.of(c)
    .showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

// ---------------------------------------------------------------- background
/// Rice field background. Cross-fades (900 ms) between morning/night; blurred (σ 3)
/// below [clearH]. Pass clearH null for a fully sharp background.
class Backdrop extends StatelessWidget {
  final double? clearH;
  final bool golden; // golden-hour photo (light mode) for the pre-login screens
  const Backdrop({super.key, this.clearH, this.golden = false});
  @override
  Widget build(BuildContext context) {
    Stamp.watch(context);
    return Stack(fit: StackFit.expand, children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 900),
          layoutBuilder: (cur, prev) =>
              Stack(fit: StackFit.expand, children: [...prev, if (cur != null) cur]),
          child: Image.asset(
            C.d ? 'assets/img/bg_night.jpg' : (golden ? 'assets/img/bg_golden.jpg' : 'assets/img/bg_morning.jpg'),
            key: ValueKey('${C.d}$golden'),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        if (clearH != null)
          Positioned(
            top: clearH,
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
                child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                    child: const SizedBox.expand())),
          ),
      ]);
  }
}

/// Scaffold with the background behind its body.
class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? bar;
  final Widget? nav, fab;
  final double? clearH;
  final bool golden;
  const AppScaffold(
      {super.key, required this.body, this.bar, this.nav, this.fab, this.clearH = 0, this.golden = false});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.surface,
        appBar: bar,
        bottomNavigationBar: nav,
        floatingActionButton: fab,
        body: Stack(children: [Positioned.fill(child: Backdrop(clearH: clearH, golden: golden)), Positioned.fill(child: body)]),
      );
}

// ---------------------------------------------------------------- top bars
class LogoBadge extends StatelessWidget {
  final double size;
  const LogoBadge(this.size, {super.key});
  @override
  Widget build(BuildContext context) {
    Stamp.watch(context);
    final ring = size >= 90; // big logos get the green ring (as in the Figma design)
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * (ring ? .165 : .07)),
        decoration: BoxDecoration(
            color: C.logoBg,
            shape: BoxShape.circle,
            border: ring ? Border.all(color: C.ring, width: size * .055) : null),
        child: Image.asset(C.d ? 'assets/img/logo_dark.png' : 'assets/img/logo_light.png',
            fit: BoxFit.contain),
      ),
    );
  }
}

class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});
  @override
  Widget build(BuildContext context) {
    Stamp.watch(context);
    return IconButton(
        tooltip: C.d ? 'Switch to light mode' : 'Switch to dark mode',
        icon: Icon(C.d ? Icons.light_mode : Icons.dark_mode, color: C.d ? C.amber : Colors.white),
        onPressed: () => app.setDark(!app.dark),
      );
  }
}

/// Bell with unread count (opens the notification list).
class BellButton extends StatelessWidget {
  const BellButton({super.key});
  @override
  Widget build(BuildContext context) {
    Stamp.watch(context);
    final n = app.unread;
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
      icon: Stack(clipBehavior: Clip.none, children: [
        const Icon(Icons.notifications_outlined, color: Colors.white),
        if (n > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(10)),
              child: Text(n > 9 ? '9+' : '$n',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
  }
}

/// Cog next to the name (farmer / vet / store): opens Settings.
Widget cogButton(BuildContext c) => Container(
      decoration: BoxDecoration(color: C.pill, shape: BoxShape.circle),
      child: IconButton(
        tooltip: 'Settings',
        icon: Icon(Icons.settings, color: C.ink),
        onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const SettingsPage())),
      ),
    );

PreferredSizeWidget mainBar(BuildContext c) {
  // admin only: tapping the logo 5 times unlocks the hidden Debug tab; a counter shows beside the logo
  final admin = app.role == Role.admin;
  final counting = admin && app.debugTaps > 0 && !app.debugUnlocked;
  return AppBar(
    toolbarHeight: 72,
    titleSpacing: 14,
    backgroundColor: C.bar,
    title: Row(children: [
      GestureDetector(onTap: admin ? app.logoTap : null, child: const LogoBadge(46)),
      const SizedBox(width: 12),
      if (counting)
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: C.amber, borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${app.tapsLeft}', style: h(20, C.onAmber)),
              const SizedBox(width: 6),
              Flexible(
                  child: Text(app.tapsLeft == 1 ? 'tap to Debug' : 'taps to Debug',
                      style: const TextStyle(color: C.onAmber, fontWeight: FontWeight.w700, fontSize: 12))),
            ]),
          ),
        )
      else
        Text('AniCare', style: h(24, Colors.white)),
    ]),
    actions: [
      const BellButton(),
      const ThemeToggle(),
      IconButton(
          tooltip: 'Log out',
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () => signOut(c)),
      const SizedBox(width: 2),
    ],
  );
}

PreferredSizeWidget subBar(String t, {PreferredSizeWidget? bottom, List<Widget> extra = const []}) => AppBar(
      title: Text(t),
      backgroundColor: C.bar,
      foregroundColor: Colors.white,
      actions: [...extra, const ThemeToggle(), const SizedBox(width: 4)],
      bottom: bottom,
    );

// ---------------------------------------------------------------- widgets
/// Card: 80% solid white/dark, text stays readable.
class Box extends StatelessWidget {
  final Widget child;
  final EdgeInsets pad;
  final VoidCallback? onTap;
  final double radius;
  const Box(
      {super.key,
      required this.child,
      this.pad = const EdgeInsets.all(14),
      this.onTap,
      this.radius = 18});
  @override
  Widget build(BuildContext context) {
    Stamp.watch(context);
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: C.pill,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: onTap,
              child: Padding(padding: pad, child: child)),
        ),
      );
  }
}

/// Wide flat box used for section titles.
class Wide extends StatelessWidget {
  final String t;
  const Wide(this.t, {super.key});
  @override
  Widget build(BuildContext context) {
    Stamp.watch(context);
    return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 6, bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: C.pill, borderRadius: BorderRadius.circular(rSq)),
        child: Text(t, style: h(20)),
      );
  }
}

/// Section title as text pill (for sub pages).
Widget sec(String t) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: C.pill, borderRadius: BorderRadius.circular(rPill)),
        child: Text(t, style: h(19))));

/// Text on its own white/dark squarish pill.
class TPill extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const TPill(this.text, {super.key, this.style});
  @override
  Widget build(BuildContext context) {
    Stamp.watch(context);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: C.pill, borderRadius: BorderRadius.circular(rPill)),
        child: Text(text, style: style ?? TextStyle(color: C.ink, fontSize: 14)),
      );
  }
}

/// Clear hero area (no blur) with text pills.
class TopHero extends StatelessWidget {
  final String title, sub;
  final Widget? trailing; // e.g. the settings cog
  const TopHero(this.title, this.sub, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    Stamp.watch(context);
    return SizedBox(
      height: kHero,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(child: TPill(title, style: h(25))),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ]),
              const SizedBox(height: 8),
              TPill(sub),
            ]),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) {
    Stamp.watch(context);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration:
            BoxDecoration(color: color.withAlpha(45), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      );
  }
}

Pill statusPill(BStatus s) => switch (s) {
      BStatus.unpaid => Pill('Awaiting payment', C.brown),
      BStatus.pending => Pill('Pending', C.d ? C.amber : const Color(0xFFB87400)),
      BStatus.accepted => Pill('Accepted', C.d ? const Color(0xFF8FB0F0) : C.navy),
      BStatus.completed => Pill('Completed', C.green),
      BStatus.declined => Pill('Declined', C.brown),
      BStatus.cancelled => Pill('Cancelled', C.brown),
    };

/// Photo with fallback icon.
class Pic extends StatelessWidget {
  final String? path;
  final double w, h, r;
  final IconData fallback;
  const Pic(this.path,
      {super.key, this.w = 64, this.h = 64, this.r = 14, this.fallback = Icons.pets});
  @override
  Widget build(BuildContext context) {
    Stamp.watch(context);
    final ph = Container(
        width: w,
        height: h,
        color: C.green.withAlpha(40),
        child: Icon(fallback, color: C.green, size: h * .5));
    return ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: path == null
            ? ph
            : path!.startsWith('http')
                ? Image.network(path!,
                    width: w,
                    height: h,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ph,
                    loadingBuilder: (_, child, prog) => prog == null ? child : ph)
                : path!.startsWith('/')
                    ? Image.file(File(path!),
                        width: w, height: h, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ph)
                    : Image.asset(path!,
                        width: w, height: h, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ph));
  }
}

/// Solid colored number tile (keeps its color in both modes).
class Stat extends StatelessWidget {
  final String value, label;
  final Color color;
  final Color fg;
  const Stat(this.value, this.label, this.color, {super.key, this.fg = Colors.white});
  @override
  Widget build(BuildContext context) {
    Stamp.watch(context);
    return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            FittedBox(child: Text(value, style: h(24, fg))),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(color: fg.withAlpha(220), fontSize: 12)),
          ]),
        ),
      );
  }
}

/// Small text form dialog. Returns the entered values or null.
Future<List<String>?> form(BuildContext c, String title, List<String> labels,
    {Set<int> numeric = const {}, List<String>? initial}) {
  final ctrls = [
    for (var i = 0; i < labels.length; i++)
      TextEditingController(text: initial != null && i < initial.length ? initial[i] : '')
  ];
  return showDialog<List<String>>(
    context: c,
    builder: (d) => AlertDialog(
      title: Text(title, style: h(20)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                  controller: ctrls[i],
                  keyboardType: numeric.contains(i) ? TextInputType.number : TextInputType.text,
                  decoration: InputDecoration(
                      labelText: labels[i],
                      fillColor: C.d ? const Color(0xFF263544) : const Color(0xFFF1F3F5))),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(90, 42)),
            onPressed: () => Navigator.pop(d, ctrls.map((e) => e.text.trim()).toList()),
            child: const Text('Save')),
      ],
    ),
  );
}

/// Asks "are you sure?" before a delete. Returns true only when the user taps the red button.
Future<bool> confirmDelete(BuildContext c, String title, String message, {String yes = 'Delete'}) async {
  final ok = await showDialog<bool>(
    context: c,
    builder: (d) => AlertDialog(
      title: Text(title, style: h(20)),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 42), backgroundColor: const Color(0xFFB3261E)),
            onPressed: () => Navigator.pop(d, true),
            child: Text(yes)),
      ],
    ),
  );
  return ok == true;
}
/// Back-button handling for the 3 main menus.
/// - not on Home tab: back goes to Home tab
/// - on Home tab: shows "log out or quit?" message (stays until a button is pressed)
class ShellBack extends StatefulWidget {
  final bool atHome;
  final VoidCallback toHome;
  final Widget child;
  const ShellBack({super.key, required this.atHome, required this.toHome, required this.child});
  @override
  State<ShellBack> createState() => _ShellBackState();
}

class _ShellBackState extends State<ShellBack> {
  bool ask = false;
  @override
  Widget build(BuildContext context) {
    Stamp.watch(context);
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || ask) return;
          if (!widget.atHome) {
            widget.toHome();
          } else {
            setState(() => ask = true);
          }
        },
        child: Stack(fit: StackFit.expand, children: [
          widget.child,
          if (ask)
            Positioned(
              left: 14,
              right: 14,
              bottom: 96,
              child: Material(
                color: C.surface,
                elevation: 8,
                borderRadius: BorderRadius.circular(rPill),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Should you log out or quit the app?', style: h(19), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: () => setState(() => ask = false),
                              child: const Text("I'll stay"))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: FilledButton(
                              style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                              onPressed: () => signOut(context),
                              child: const Text('Log out'))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: C.brown,
                                  foregroundColor: C.d ? Colors.black : Colors.white,
                                  minimumSize: const Size(0, 46)),
                              onPressed: quitApp,
                              child: const Text('Quit'))),
                    ]),
                  ]),
                ),
              ),
            ),
        ]),
      );
  }
}

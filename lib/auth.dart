import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'ui.dart';
import 'raiser.dart';
import 'vet.dart';
import 'admin.dart';

const tagline = 'Connecting Farmers to Animal Care.';

void quitApp() => SystemNavigator.pop();

Widget shellFor(Role r) => switch (r) {
      Role.raiser => const RaiserShell(),
      Role.vet => const VetShell(),
      Role.store => const StoreShell(),
      Role.admin => const AdminShell(),
    };

/// Instant route to the login screen (no fade = no white flash), then clear the session.
Route<void> instantRoute(Widget page) => PageRouteBuilder<void>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero);

void signOut(BuildContext c) {
  Navigator.pushAndRemoveUntil(c, instantRoute(const LoginPage()), (r) => false);
  // clear the data only after the login screen is on screen (otherwise the old menus rebuild with empty data)
  WidgetsBinding.instance.addPostFrameCallback((_) => app.signOut());
}

Widget brandTitle(double size) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(rPill)),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: 'Ani', style: h(size, C.green)),
        TextSpan(text: 'Care', style: h(size, C.brandNavy)),
      ])),
    );

Widget _toggleBtn() => Container(
      decoration: BoxDecoration(color: C.surface, shape: BoxShape.circle),
      child: IconButton(
        tooltip: C.d ? 'Light mode' : 'Dark mode',
        icon: Icon(C.d ? Icons.light_mode : Icons.dark_mode, color: C.ink),
        onPressed: () => app.setDark(!app.dark),
      ),
    );

// ---------------------------------------------------------------- splash
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashState();
}

class _SplashState extends State<SplashPage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // load the images now so the 900 ms fade never stutters
    for (final p in [
      'assets/img/bg_morning.jpg',
      'assets/img/bg_night.jpg',
      'assets/img/bg_golden.jpg',
      'assets/img/logo_light.png',
      'assets/img/logo_dark.png'
    ]) {
      precacheImage(AssetImage(p), context);
    }
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      // stay logged in: go straight to the user's menu if a session is saved
      final Widget next = app.role != null ? shellFor(app.role!) : const WelcomePage();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
    });
  }

  @override
  Widget build(BuildContext context) => rx((c) => Scaffold(
        backgroundColor: C.surface,
        body: Stack(children: [
          const Positioned.fill(child: Backdrop(golden: true)),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const LogoBadge(170),
              const SizedBox(height: 16),
              brandTitle(44),
              const SizedBox(height: 10),
              TPill(tagline, style: hi(17, C.d ? C.amber : C.brown)),
              const SizedBox(height: 34),
              SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3, color: C.amber)),
            ]),
          ),
        ]),
      ));
}

// ---------------------------------------------------------------- welcome
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) => rx((c) => Scaffold(
        backgroundColor: C.surface,
        body: Stack(children: [
          const Positioned.fill(child: Backdrop(golden: true)),
          SafeArea(
            child: Column(children: [
              Align(
                  alignment: Alignment.centerRight,
                  child: Padding(padding: const EdgeInsets.fromLTRB(0, 6, 12, 0), child: _toggleBtn())),
              const Spacer(flex: 3),
              const LogoBadge(116),
              const SizedBox(height: 12),
              brandTitle(34),
              const SizedBox(height: 8),
              const Text(tagline,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black87)])),
              const Spacer(flex: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(color: C.pill, borderRadius: BorderRadius.circular(rPill)),
                child: Text('Welcome to AniCare!', style: h(27)),
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: 230,
                child: Column(children: [
                  FilledButton(
                      onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const LoginPage())),
                      child: const Text('GET STARTED')),
                  const SizedBox(height: 14),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: C.surface.withAlpha(224), foregroundColor: C.green),
                      onPressed: () => Navigator.push(
                          c, MaterialPageRoute(builder: (_) => const AboutPage())),
                      child: const Text('ABOUT')),
                ]),
              ),
              const Spacer(flex: 2),
            ]),
          ),
        ]),
      ));
}

// ---------------------------------------------------------------- login
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginState();
}

class _LoginState extends State<LoginPage> {
  final user = TextEditingController(), pass = TextEditingController();
  bool hide = true, busy = false;
  String? err;

  Future<void> _login() async {
    setState(() => busy = true);
    final e = await app.login(user.text, pass.text);
    if (!mounted) return;
    if (e != null) {
      setState(() {
        busy = false;
        err = e;
      });
      return;
    }
    Navigator.pushAndRemoveUntil(
        context, MaterialPageRoute(builder: (_) => shellFor(app.role!)), (r) => false);
  }

  void _back() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomePage()));
    }
  }

  @override
  Widget build(BuildContext context) => rx((c) => Scaffold(
        backgroundColor: C.surface,
        body: Stack(children: [
          const Positioned.fill(child: Backdrop(golden: true)),
          SafeArea(
            child: Stack(children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 56, 22, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(children: [
                      const LogoBadge(116),
                      const SizedBox(height: 12),
                      brandTitle(36),
                      const SizedBox(height: 8),
                      TPill(tagline, style: hi(15, C.d ? C.amber : C.brown)),
                      const SizedBox(height: 22),
                      TextField(
                        controller: user,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        style: TextStyle(color: C.ink),
                        decoration: InputDecoration(
                            hintText: 'Username',
                            prefixIcon: Icon(Icons.person_outline, color: C.ink)),
                      ),

                      const SizedBox(height: 10),
                      TextField(
                        controller: pass,
                        obscureText: hide,
                        style: TextStyle(color: C.ink),
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                            hintText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline, color: C.ink),
                            suffixIcon: IconButton(
                                icon: Icon(hide ? Icons.visibility : Icons.visibility_off, color: C.ink),
                                onPressed: () => setState(() => hide = !hide))),
                      ),
                      if (err != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(rPill)),
                          child: Text(err!,
                              style: TextStyle(
                                  color: C.d ? const Color(0xFFFF8A80) : const Color(0xFFB3261E),
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton(
                          onPressed: busy ? null : _login,
                          child: busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : const Text('Log in')),
                      const SizedBox(height: 10),
                      FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: C.surface.withAlpha(224), foregroundColor: C.green),
                          onPressed: _back,
                          child: const Text('Back')),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: C.pill, borderRadius: BorderRadius.circular(rPill)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text("Don't have an account? "),
                          GestureDetector(
                            onTap: () => Navigator.push(
                                context, MaterialPageRoute(builder: (_) => const CreateAccountPage())),
                            child: Text('Create Account',
                                style: TextStyle(color: C.green, fontWeight: FontWeight.w800)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48), backgroundColor: C.surface),
                        onPressed: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const AboutPage())),
                        icon: Icon(Icons.info_outline, color: C.ink),
                        label: Text('About AniCare',
                            style: TextStyle(color: C.ink, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                ),
              ),
              Positioned(top: 8, right: 10, child: _toggleBtn()),
            ]),
          ),
        ]),
      ));
}

// ---------------------------------------------------------------- create account
class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});
  @override
  State<CreateAccountPage> createState() => _CreateState();
}

class _CreateState extends State<CreateAccountPage> {
  Role role = Role.raiser;
  final name = TextEditingController(),
      phone = TextEditingController(),
      uname = TextEditingController(),
      pw = TextEditingController(),
      pw2 = TextEditingController(),
      place = TextEditingController(),
      license = TextEditingController(),
      fee = TextEditingController(text: '350'),
      storeName = TextEditingController(),
      storeAddr = TextEditingController();
  final pwFocus = FocusNode();
  String kind = 'Veterinarian';
  bool h1 = true, h2 = true, busy = false;
  String? err;

  @override
  void initState() {
    super.initState();
    pwFocus.addListener(() => setState(() {}));
    pw.addListener(() => setState(() {}));
  }

  String? _validate() {
    if (name.text.trim().length < 3) return 'Please enter your full name.';
    if (!RegExp(r'^9\d{9}$').hasMatch(phone.text.trim())) {
      return 'Enter a valid mobile number: 10 digits starting with 9.';
    }
    if (!RegExp(r'^[a-z0-9._]{4,20}$').hasMatch(uname.text.trim().toLowerCase())) {
      return 'Username: 4–20 letters, numbers, dot or underscore.';
    }
    if (!PwCheck(pw.text).ok) return pwRuleText;
    if (pw.text != pw2.text) return 'Passwords do not match.';
    if (role == Role.raiser && place.text.trim().isEmpty) return 'Please enter your barangay / farm location.';
    if (role == Role.vet) {
      if (license.text.trim().isEmpty) return 'Please enter your license number.';
      final f = double.tryParse(fee.text.trim());
      if (f == null || f < 50 || f > 5000) return 'Consultation fee must be between ₱50 and ₱5,000.';
    }
    if (role == Role.store && (storeName.text.trim().isEmpty || storeAddr.text.trim().isEmpty)) {
      return 'Please enter the store name and address.';
    }
    return null;
  }

  Future<void> _create() async {
    final v = _validate();
    if (v != null) {
      setState(() => err = v);
      return;
    }
    setState(() {
      busy = true;
      err = null;
    });
    final e = await app.register(
      role: role,
      fullName: name.text,
      phone: phone.text.trim(),
      username: uname.text,
      password: pw.text,
      place: place.text,
      kind: kind,
      license: license.text,
      fee: double.tryParse(fee.text.trim()) ?? 350,
      storeName: storeName.text,
      storeAddress: storeAddr.text,
    );
    if (!mounted) return;
    if (e != null) {
      setState(() {
        busy = false;
        err = e;
      });
      return;
    }
    // straight into the app
    Navigator.pushAndRemoveUntil(
        context, MaterialPageRoute(builder: (_) => shellFor(app.role!)), (r) => false);
  }

  Widget _roleCard(Role r, IconData ic, String t, String s) {
    final sel = role == r;
    final fg = sel ? Colors.white : C.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: sel ? C.green : C.surface.withAlpha(235),
        borderRadius: BorderRadius.circular(rPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(rPill),
          onTap: () => setState(() => role = r),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: sel ? Colors.white24 : C.green.withAlpha(35), borderRadius: BorderRadius.circular(12)),
                  child: Icon(ic, color: sel ? Colors.white : C.green)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 15)),
                Text(s, style: TextStyle(color: fg, fontSize: 12.5)),
              ])),
              if (sel) const Icon(Icons.check_circle, color: Colors.white),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) =>
      Padding(padding: const EdgeInsets.only(top: 10, bottom: 4), child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)));

  InputDecoration _dec(String hint, IconData ic, {Widget? suffix, String? prefix}) => InputDecoration(
      hintText: hint,
      prefixIcon: Icon(ic, size: 20, color: C.ink),
      prefixText: prefix,
      suffixIcon: suffix,
      fillColor: C.d ? const Color(0xFF263544) : const Color(0xFFF1F3F5));

  @override
  Widget build(BuildContext context) => rx((c) => AppScaffold(
        golden: true,
        bar: subBar('Create Account'),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          sec('Register as'),
          _roleCard(Role.raiser, Icons.agriculture, 'Farmer / Raiser', 'Manage animals and track health records.'),
          _roleCard(Role.vet, Icons.medical_services_outlined, 'Veterinarian', 'Provide animal care and manage appointments.'),
          _roleCard(Role.store, Icons.storefront_outlined, 'Agri-Vet Store', 'Manage veterinary products and reservations.'),
          const SizedBox(height: 4),
          Box(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Personal Information', style: h(18)),
            _label('Full Name (First, Middle, Surname)'),
            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: _dec('e.g. Juan dela Cruz', Icons.person_outline)),
            _label('Mobile Phone Number'),
            TextField(
                controller: phone,
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('917 123 4567', Icons.phone_outlined, prefix: '+63  ').copyWith(counterText: '')),
            _label('AniCare Username'),
            TextField(controller: uname, autocorrect: false, decoration: _dec('e.g. juan.farmer', Icons.alternate_email)),
            _label('Password'),
            TextField(
                controller: pw,
                focusNode: pwFocus,
                obscureText: h1,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s')), LengthLimitingTextInputFormatter(32)],
                decoration: _dec('8–32 characters', Icons.lock_outline,
                    suffix: IconButton(icon: Icon(h1 ? Icons.visibility : Icons.visibility_off, color: C.ink), onPressed: () => setState(() => h1 = !h1)))),
            if (pwFocus.hasFocus || pw.text.isNotEmpty) pwChecklist(pw.text),
            _label('Confirm Password'),
            TextField(
                controller: pw2,
                obscureText: h2,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s')), LengthLimitingTextInputFormatter(32)],
                decoration: _dec('Repeat the password', Icons.lock_reset,
                    suffix: IconButton(icon: Icon(h2 ? Icons.visibility : Icons.visibility_off, color: C.ink), onPressed: () => setState(() => h2 = !h2)))),
          ])),
          Box(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (role == Role.raiser) ...[
              Text('Farm details', style: h(18)),
              _label('Barangay / farm location'),
              TextField(controller: place, decoration: _dec('e.g. Poblacion, Bunawan', Icons.place_outlined)),
            ],
            if (role == Role.vet) ...[
              Text('Professional details', style: h(18)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                    foregroundColor: C.ink, selectedForegroundColor: Colors.white, selectedBackgroundColor: C.green),
                segments: const [
                  ButtonSegment(value: 'Veterinarian', label: Text('Veterinarian')),
                  ButtonSegment(value: 'Animal Technician', label: Text('Technician')),
                ],
                selected: {kind},
                onSelectionChanged: (v) => setState(() => kind = v.first),
              ),
              _label('License number'),
              TextField(controller: license, decoration: _dec('e.g. PRC 0123456', Icons.badge_outlined)),
              _label('Consultation fee per visit (₱)'),
              TextField(controller: fee, keyboardType: TextInputType.number, decoration: _dec('350', Icons.payments_outlined)),
            ],
            if (role == Role.store) ...[
              Text('Store details', style: h(18)),
              _label('Store name'),
              TextField(controller: storeName, textCapitalization: TextCapitalization.words, decoration: _dec('e.g. Bunawan Agri-Vet', Icons.storefront_outlined)),
              _label('Store address'),
              TextField(controller: storeAddr, decoration: _dec('e.g. Poblacion, Bunawan', Icons.place_outlined)),
            ],
          ])),
          if (err != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(rPill)),
              child: Text(err!, style: TextStyle(color: C.d ? const Color(0xFFFF8A80) : const Color(0xFFB3261E), fontWeight: FontWeight.w700)),
            ),
          FilledButton(
              onPressed: busy ? null : _create,
              child: busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Create Account'), SizedBox(width: 8), Icon(Icons.arrow_forward, size: 18)])),
          const SizedBox(height: 12),
          Center(
              child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: C.pill, borderRadius: BorderRadius.circular(rPill)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Already have an account? '),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text('Log in', style: TextStyle(color: C.green, fontWeight: FontWeight.w800)),
              ),
            ]),
          )),
        ]),
      ));
}

// ---------------------------------------------------------------- about
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) => rx((c) => AppScaffold(
        golden: true,
        bar: subBar('About AniCare'),
        body: const _AboutBody(),
      ));
}

class _AboutBody extends StatelessWidget {
  const _AboutBody();
  @override
  Widget build(BuildContext context) {
    Stamp.watch(context);
    Widget card(String title, List<String> paras) => Box(
        radius: 22,
        pad: const EdgeInsets.all(18),
        child: SizedBox(
          width: double.infinity,
          child: Column(children: [
            Text(title, style: h(18)),
            const SizedBox(height: 10),
            for (final p in paras)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(p, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, height: 1.4))),
          ]),
        ));
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SizedBox(height: 4),
      const Center(child: LogoBadge(116)),
      const SizedBox(height: 10),
      Center(child: brandTitle(32)),
      const SizedBox(height: 16),
      card('About AniCare', const [
        'AniCare is a livestock animal-care application designed to connect farmers and livestock raisers with veterinarians and animal-care providers. It helps users manage livestock records, book veterinary appointments, monitor vaccination schedules, and access animal-care products.',
        'Our goal is to make animal healthcare more accessible, convenient, and organized, helping farmers maintain healthier livestock and support better farming practices.',
      ]),
      card('Our Mission', const [
        'To connect livestock raisers with reliable animal-care services and promote healthier livestock through accessible veterinary care and technology.',
      ]),
      card('Built with', const [
        'Flutter for Android. All accounts and records are kept on this phone in a SQLite database, so the app works without internet. Passwords are stored as salted hashes.',
      ]),
      Center(child: TPill('Version $kVersion', style: const TextStyle(fontWeight: FontWeight.w700))),
      const SizedBox(height: 12),
    ]);
  }
}

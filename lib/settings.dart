import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'help.dart';
import 'photos.dart';
import 'ui.dart';

/// Settings (the cog beside the name): profile, username, password. No photo, no GCash number.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsPage> {
  late final name = TextEditingController(text: app.user!.fullName);
  late final username = TextEditingController(text: app.user!.username);
  late final phone = TextEditingController(text: app.user!.phone);
  late final place = TextEditingController(text: app.user!.place);
  late final fee = TextEditingController(text: app.role == Role.vet ? app.me.fee.toStringAsFixed(0) : '');
  late final license = TextEditingController(text: app.role == Role.vet ? app.me.license : '');
  late final storeName = TextEditingController(text: app.role == Role.store ? app.myStore.name : '');
  late final storeAddr = TextEditingController(text: app.role == Role.store ? app.myStore.address : '');
  final oldPw = TextEditingController(), newPw = TextEditingController(), newPw2 = TextEditingController();
  late String kind = app.role == Role.vet ? app.me.kind : 'Veterinarian';
  bool h0 = true, h1 = true, h2 = true, busy = false;
  String? pMsg, uMsg, wMsg;
  bool pOk = false, uOk = false, wOk = false;

  @override
  void initState() {
    super.initState();
    newPw.addListener(() => setState(() {}));
    oldPw.addListener(() => setState(() {}));
  }

  InputDecoration _dec(String label, {Widget? suffix}) => InputDecoration(
      labelText: label,
      suffixIcon: suffix,
      fillColor: C.d ? const Color(0xFF263544) : const Color(0xFFF1F3F5));

  Future<void> _pickMine() async {
    final p = await pickPhoto(context);
    if (p != null) app.setMyPhoto(p);
  }
  Widget _msg(String? m, bool ok) => m == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(m,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: ok ? C.green : (C.d ? const Color(0xFFFF8A80) : const Color(0xFFB3261E)))));

  Future<void> _saveProfile() async {
    setState(() => busy = true);
    final e = await app.updateProfile(
      fullName: name.text,
      phone: phone.text,
      place: place.text,
      vetFee: double.tryParse(fee.text.trim()),
      vetKind: kind,
      license: license.text,
      storeName: storeName.text,
      storeAddress: storeAddr.text,
    );
    if (!mounted) return;
    setState(() {
      busy = false;
      pOk = e == null;
      pMsg = e ?? 'Saved.';
    });
  }

  Future<void> _saveUsername() async {
    setState(() => busy = true);
    final e = await app.changeUsername(username.text);
    if (!mounted) return;
    setState(() {
      busy = false;
      uOk = e == null;
      uMsg = e ?? 'Username changed. Use it the next time you log in.';
    });
  }

  Future<void> _savePassword() async {
    if (newPw.text != newPw2.text) {
      setState(() {
        wOk = false;
        wMsg = 'The new passwords do not match.';
      });
      return;
    }
    setState(() => busy = true);
    final e = await app.changePassword(oldPw.text, newPw.text);
    if (!mounted) return;
    setState(() {
      busy = false;
      wOk = e == null;
      wMsg = e ?? 'Password changed.';
      if (e == null) {
        oldPw.clear();
        newPw.clear();
        newPw2.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) => rx((c) => AppScaffold(
        bar: subBar('Settings', extra: [
          IconButton(
              tooltip: 'Help & Support',
              icon: const Icon(Icons.help_outline, color: Colors.white),
              onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const HelpPage()))),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (app.role == Role.vet || app.role == Role.store)
            Box(
                child: Row(children: [
              Pic(app.role == Role.vet ? app.me.photo : app.myStore.photo,
                  w: 72, h: 72, r: app.role == Role.vet ? 36 : 14, fallback: app.role == Role.vet ? Icons.person : Icons.store),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(app.role == Role.vet ? 'Profile photo' : 'Shop photo', style: h(18)),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                    onPressed: _pickMine,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choose from gallery')),
              ])),
            ])),
          Box(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Profile', style: h(20)),
            const SizedBox(height: 10),
            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: _dec('Full name')),
            const SizedBox(height: 10),
            TextField(
                controller: phone,
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('Mobile number (10 digits, starts with 9)').copyWith(prefixText: '+63  ', counterText: '')),
            if (app.role == Role.raiser) ...[
              const SizedBox(height: 10),
              TextField(controller: place, decoration: _dec('Barangay / farm location')),
            ],
            if (app.role == Role.vet) ...[
              const SizedBox(height: 10),
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
              const SizedBox(height: 10),
              TextField(controller: license, decoration: _dec('License number')),
              const SizedBox(height: 10),
              TextField(controller: fee, keyboardType: TextInputType.number, decoration: _dec('Consultation fee per visit (₱)')),
            ],
            if (app.role == Role.store) ...[
              const SizedBox(height: 10),
              TextField(controller: storeName, textCapitalization: TextCapitalization.words, decoration: _dec('Store name')),
              const SizedBox(height: 10),
              TextField(controller: storeAddr, decoration: _dec('Store address')),
            ],
            const SizedBox(height: 12),
            FilledButton(onPressed: busy ? null : _saveProfile, child: const Text('Save profile')),
            _msg(pMsg, pOk),
          ])),
          Box(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Username', style: h(20)),
            const SizedBox(height: 6),
            const Text('You log in with this name. Changing it changes your login.', style: TextStyle(fontSize: 12.5)),
            const SizedBox(height: 10),
            TextField(controller: username, autocorrect: false, decoration: _dec('Username')),
            const SizedBox(height: 12),
            FilledButton(onPressed: busy ? null : _saveUsername, child: const Text('Change username')),
            _msg(uMsg, uOk),
          ])),
          Box(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Password', style: h(20)),
            const SizedBox(height: 10),
            TextField(
                controller: oldPw,
                obscureText: h0,
                decoration: _dec('Old password',
                    suffix: IconButton(icon: Icon(h0 ? Icons.visibility : Icons.visibility_off, color: C.ink), onPressed: () => setState(() => h0 = !h0)))),
            const SizedBox(height: 10),
            TextField(
                controller: newPw,
                obscureText: h1,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s')), LengthLimitingTextInputFormatter(32)],
                decoration: _dec('New password',
                    suffix: IconButton(icon: Icon(h1 ? Icons.visibility : Icons.visibility_off, color: C.ink), onPressed: () => setState(() => h1 = !h1)))),
            if (newPw.text.isNotEmpty) pwChecklist(newPw.text),
            const SizedBox(height: 10),
            TextField(
                controller: newPw2,
                obscureText: h2,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s')), LengthLimitingTextInputFormatter(32)],
                decoration: _dec('Repeat the new password',
                    suffix: IconButton(icon: Icon(h2 ? Icons.visibility : Icons.visibility_off, color: C.ink), onPressed: () => setState(() => h2 = !h2)))),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: busy || oldPw.text.isEmpty || !PwCheck(newPw.text).ok ? null : _savePassword,
                child: const Text('Change password')),
            _msg(wMsg, wOk),
          ])),
        ]),
      ));
}

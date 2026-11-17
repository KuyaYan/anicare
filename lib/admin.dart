import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'data.dart';
import 'notifications.dart';
import 'ui.dart';

// ---------------------------------------------------------------- shell
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminState();
}

class _AdminState extends State<AdminShell> {
  int i = 0;
  void go(int n) => setState(() => i = n);
  @override
  Widget build(BuildContext context) => rx((c) {
        // the Debug tab only exists after the logo was tapped 5 times (and hides again at logout)
        final debug = app.debugUnlocked;
        final tabs = <Widget>[
          const AdminOverview(),
          const AdminPurchases(),
          const AdminVaccines(),
          const AdminAccounts(),
          if (debug) const AdminDebug(),
        ];
        final idx = i >= tabs.length ? 0 : i;
        return ShellBack(
          atHome: idx == 0,
          toHome: () => go(0),
          child: AppScaffold(
            bar: mainBar(c),
            clearH: kHero,
            body: IndexedStack(index: idx, children: tabs),
            nav: NavigationBar(
              selectedIndex: idx,
              onDestinationSelected: go,
              destinations: [
                const NavigationDestination(icon: Icon(Icons.insights_outlined), label: 'LGU'),
                const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Purchases'),
                const NavigationDestination(icon: Icon(Icons.medication_outlined), label: 'Vaccines'),
                const NavigationDestination(icon: Icon(Icons.manage_accounts_outlined), label: 'Accounts'),
                if (debug) const NavigationDestination(icon: Icon(Icons.bug_report_outlined), label: 'Debug'),
              ],
            ),
          ),
        );
      });
}

String _brgy(String place) {
  final t = place.split(',').first.trim();
  return t.isEmpty ? 'Unknown' : t;
}

Widget _hbar(String label, double frac, Color color, String trailing, {double w = 96}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: w, child: Text(label, overflow: TextOverflow.ellipsis)),
        Expanded(
            child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    value: frac.clamp(0.0, 1.0), minHeight: 12, color: color, backgroundColor: color.withAlpha(50)))),
        SizedBox(
            width: 52,
            child: Text(trailing, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]),
    );

// ---------------------------------------------------------------- LGU (animals tracked)
class AdminOverview extends StatelessWidget {
  const AdminOverview({super.key});
  @override
  Widget build(BuildContext context) => rx((c) {
        final animals = app.allAnimals;
        final heads = animals.fold<int>(0, (s, a) => s + a.count);
        final bySp = <Species, int>{};
        final byB = <String, int>{};
        final vTot = <String, int>{}, vDone = <String, int>{};
        var sTot = 0, sDone = 0;
        for (final a in animals) {
          bySp[a.sp] = (bySp[a.sp] ?? 0) + a.count;
          final b = _brgy(app.placeOf(a.ownerId));
          byB[b] = (byB[b] ?? 0) + a.count;
          for (final s in a.sched) {
            sTot++;
            if (s.done) sDone++;
            if (s.label.toLowerCase().contains('vaccin')) {
              vTot[b] = (vTot[b] ?? 0) + 1;
              if (s.done) vDone[b] = (vDone[b] ?? 0) + 1;
            }
          }
        }
        final pct = sTot == 0 ? 0 : (sDone * 100 / sTot).round();
        final spList = bySp.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
        final bList = byB.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
        final maxSp = spList.isEmpty ? 1 : spList.first.value;
        final maxB = bList.isEmpty ? 1 : bList.first.value;
        final comp = vTot.keys.toList()
          ..sort((x, y) => ((vDone[y] ?? 0) / vTot[y]!).compareTo((vDone[x] ?? 0) / vTot[x]!));
        return Column(children: [
          const TopHero('LGU Bunawan & MAO', 'Animals tracked • live data'),
          Expanded(
            child: RList(padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), children: [
              Row(children: [
                Stat('$heads', 'Animals tracked', C.green),
                Stat('${animals.length}', 'Animal records', C.navy),
                Stat('$pct%', 'Reminders done', C.amber, fg: C.onAmber),
              ]),
              sec('Animals by species'),
              Box(
                  child: Column(children: [
                if (spList.isEmpty) const Text('No animals recorded yet.'),
                for (final e in spList)
                  _hbar(e.key.label, e.value / maxSp, e.key == Species.poultry ? C.amber : (e.key == Species.hog ? C.green : C.navy), '${e.value}'),
              ])),
              sec('Animals by barangay'),
              Box(
                  child: Column(children: [
                if (bList.isEmpty) const Text('No data yet.'),
                for (final e in bList) _hbar(e.key, e.value / maxB, C.navy, '${e.value}'),
              ])),
              sec('Vaccination compliance by barangay'),
              Box(
                  child: Column(children: [
                if (comp.isEmpty) const Text('No vaccine reminders yet.'),
                for (final b in comp)
                  _hbar(b, (vDone[b] ?? 0) / vTot[b]!, C.green, '${((vDone[b] ?? 0) * 100 / vTot[b]!).round()}%'),
              ])),
              Box(child: const Text('Pull down to refresh the numbers.', style: TextStyle(fontSize: 12.5))),
            ]),
          ),
        ]);
      });
}

// ---------------------------------------------------------------- purchases
const _kindLabel = {
  'reservation': 'Reservation',
  'booking': 'Booking',
  'subscription': 'Subscription',
  'fee': 'AniCare fee',
  'payout': 'Vet share (owed)',
};

class AdminPurchases extends StatefulWidget {
  const AdminPurchases({super.key});
  @override
  State<AdminPurchases> createState() => _PurchasesState();
}

class _PurchasesState extends State<AdminPurchases> {
  String kind = 'all';

  String _payer(Payment p) => (p.kind == 'reservation' || p.kind == 'booking') ? maskName(p.payer) : p.payer;

  String _csvCell(String s) => '"${s.replaceAll('"', '""')}"';

  Future<void> _export(BuildContext c, List<Payment> rows) async {
    final b = StringBuffer('Date,Type,Payer,Payee,Item,Amount (PHP),Method,Status,GCash reference\n');
    for (final p in rows) {
      b.writeln([
        fmt(p.at),
        _kindLabel[p.kind] ?? p.kind,
        _payer(p),
        p.payee,
        p.item,
        p.amount.toStringAsFixed(2),
        p.method,
        p.status,
        p.ref,
      ].map(_csvCell).join(','));
    }
    try {
      final dir = await getTemporaryDirectory();
      final n = DateTime.now();
      final name =
          'anicare_purchases_${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}.csv';
      final f = File('${dir.path}/$name');
      await f.writeAsString(b.toString());
      await Share.shareXFiles([XFile(f.path)], text: 'AniCare purchases – last 30 days');
    } catch (e) {
      if (c.mounted) toast(c, 'Could not export the CSV: $e');
    }
  }

  @override
  Widget build(BuildContext context) => rx((c) {
        final p30 = app.payments30;
        double sum(String k) => p30.where((p) => p.kind == k).fold(0.0, (s, p) => s + p.amount);
        final res = sum('reservation'), book = sum('booking'), subs = sum('subscription'), fee = sum('fee');
        final total = res + book + subs; // payouts are not purchases
        final days = List<double>.filled(30, 0);
        final t = DateTime.now();
        final d0 = DateTime(t.year, t.month, t.day);
        for (final p in p30) {
          if (p.kind == 'fee') continue;
          final di = d0.difference(DateTime(p.at.year, p.at.month, p.at.day)).inDays;
          if (di >= 0 && di < 30) days[29 - di] += p.amount;
        }
        final rows = (kind == 'all' ? p30 : p30.where((p) => p.kind == kind).toList());
        return Column(children: [
          const TopHero('Purchases', 'Last 30 days • real transactions'),
          Expanded(
            child: RList(padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), children: [
              Row(children: [Stat(money(res), 'Reservations', C.green), Stat(money(book), 'Vet bookings', C.navy)]),
              const SizedBox(height: 8),
              Row(children: [
                Stat(money(subs), 'Subscriptions', C.amber, fg: C.onAmber),
                Stat(money(fee), 'AniCare fees', const Color(0xFF7A4A2B)),
              ]),
              const SizedBox(height: 10),
              Box(
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Flexible(child: Text('Total purchases', style: h(18))),
                Text(money(total), style: h(22, C.green)),
              ])),
              Box(child: const Text('Only real transactions are listed (vet bookings, store plans and reservations paid with GCash). Total = reservations + vet bookings + subscriptions. AniCare fees are part of the booking payments; "Vet share (owed)" is only recorded, nothing is paid out.', style: TextStyle(fontSize: 12))),
              sec('Daily purchases (30 days)'),
              Box(
                  child: Column(children: [
                _Bars(days),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(fmt(d0.subtract(const Duration(days: 29))), style: const TextStyle(fontSize: 11)),
                  Text('Today', style: const TextStyle(fontSize: 11)),
                ]),
              ])),
              sec('All purchases'),
              Wrap(spacing: 8, children: [
                for (final k in ['all', 'reservation', 'booking', 'subscription', 'fee', 'payout'])
                  ChoiceChip(
                    label: Text(k == 'all' ? 'All' : _kindLabel[k]!),
                    selected: kind == k,
                    backgroundColor: C.pill,
                    selectedColor: C.amber,
                    labelStyle: TextStyle(color: kind == k ? C.onAmber : C.ink),
                    onSelected: (_) => setState(() => kind = k),
                  ),
              ]),
              const SizedBox(height: 8),
              FilledButton.icon(
                  onPressed: rows.isEmpty ? null : () => _export(c, rows),
                  icon: const Icon(Icons.download),
                  label: Text('Export CSV (${rows.length} rows)')),
              const SizedBox(height: 10),
              Box(
                pad: const EdgeInsets.all(6),
                child: rows.isEmpty
                    ? const Padding(padding: EdgeInsets.all(8), child: Text('No purchases in the last 30 days.'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 14,
                          headingRowHeight: 38,
                          dataRowMinHeight: 38,
                          dataRowMaxHeight: 56,
                          columns: const [
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Payer')),
                            DataColumn(label: Text('Payee')),
                            DataColumn(label: Text('Item')),
                            DataColumn(label: Text('Amount'), numeric: true),
                            DataColumn(label: Text('Method')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Reference')),
                          ],
                          rows: [
                            for (final p in rows.take(150))
                              DataRow(cells: [
                                DataCell(Text(fmt(p.at))),
                                DataCell(Text(_kindLabel[p.kind] ?? p.kind)),
                                DataCell(Text(_payer(p))),
                                DataCell(Text(p.payee)),
                                DataCell(Text(p.item)),
                                DataCell(Text(money(p.amount), style: const TextStyle(fontWeight: FontWeight.w700))),
                                DataCell(Text(p.method)),
                                DataCell(Text(p.status)),
                                DataCell(Text(p.ref.isEmpty ? '-' : p.ref)),
                              ]),
                          ],
                        ),
                      ),
              ),
              if (rows.length > 150)
                const Padding(
                    padding: EdgeInsets.all(8), child: Text('Showing the latest 150 rows. The CSV has all rows.')),
            ]),
          ),
        ]);
      });
}

class _Bars extends StatelessWidget {
  final List<double> v;
  const _Bars(this.v);
  @override
  Widget build(BuildContext context) {
    Stamp.watch(context);
    final m = v.fold<double>(0, math.max);
    return SizedBox(
      height: 110,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final x in v)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                height: m == 0 ? 2 : (x / m * 104).clamp(2, 104).toDouble(),
                decoration: BoxDecoration(
                    color: C.green, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
              ),
            ),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- vaccine stock
class AdminVaccines extends StatelessWidget {
  const AdminVaccines({super.key});
  @override
  Widget build(BuildContext context) => rx((c) {
        final list = app.vaccines;
        final today = DateTime.now();
        int? daysLeft(Product p) => p.expiry?.difference(today).inDays;
        final units = list.fold<int>(0, (s, e) => s + e.p.stock);
        final low = list.where((e) => e.p.stock < AppState.lowStock).length;
        final exp = list.where((e) => (daysLeft(e.p) ?? 999) <= 30).length;
        final totals = <String, int>{};
        for (final e in list) {
          totals[e.p.name] = (totals[e.p.name] ?? 0) + e.p.stock;
        }
        final withVax = app.stores.where((s) => s.listed.any((p) => p.cat == 'Vaccine')).toList();
        return Column(children: [
          const TopHero('Vaccine stock', 'All stores • low stock and expiry'),
          Expanded(
            child: RList(padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), children: [
              Row(children: [
                Stat('$units', 'Units in stock', C.green),
                Stat('$low', 'Low stock (<${AppState.lowStock})', C.amber, fg: C.onAmber),
                Stat('$exp', 'Expired / ≤30 days', const Color(0xFFB3261E)),
              ]),
              sec('Total per vaccine'),
              Box(
                  child: Column(children: [
                if (totals.isEmpty) const Text('No vaccines listed yet.'),
                for (final e in totals.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Flexible(child: Text(e.key)),
                      Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
              ])),
              for (final s in withVax) ...[
                Wide(s.name),
                for (final p in s.listed.where((p) => p.cat == 'Vaccine'))
                  Box(
                    child: Row(children: [
                      Pic(p.img, w: 48, h: 48, r: 8, fallback: Icons.medication),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, style: h(16)),
                        Text(p.expiry == null ? 'No expiry date' : 'Expires ${fmt(p.expiry!)}',
                            style: const TextStyle(fontSize: 12.5)),
                        const SizedBox(height: 4),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          if (p.stock == 0) Pill('Out of stock', const Color(0xFFB3261E))
                          else if (p.stock < AppState.lowStock) Pill('Low stock', C.d ? C.amber : const Color(0xFFB87400)),
                          if (daysLeft(p) != null && daysLeft(p)! < 0) Pill('Expired', const Color(0xFFB3261E))
                          else if (daysLeft(p) != null && daysLeft(p)! <= 30) Pill('Expires in ${daysLeft(p)} days', C.d ? C.amber : const Color(0xFFB87400)),
                        ]),
                      ])),
                      Text('${p.stock}', style: h(24, p.stock < AppState.lowStock ? const Color(0xFFB3261E) : C.green)),
                    ]),
                  ),
              ],
            ]),
          ),
        ]);
      });
}

// ---------------------------------------------------------------- accounts
class AdminAccounts extends StatefulWidget {
  const AdminAccounts({super.key});
  @override
  State<AdminAccounts> createState() => _AccountsState();
}

class _AccountsState extends State<AdminAccounts> {
  Role? filter;

  IconData _ic(Role r) => switch (r) {
        Role.raiser => Icons.agriculture,
        Role.vet => Icons.medical_services_outlined,
        Role.store => Icons.storefront_outlined,
        Role.admin => Icons.admin_panel_settings_outlined,
      };

  String _roleName(Role r) => switch (r) {
        Role.raiser => 'Farmer',
        Role.vet => 'Vet / Tech',
        Role.store => 'Store owner',
        Role.admin => 'Admin',
      };

  @override
  Widget build(BuildContext context) => rx((c) {
        final users = app.managedUsers.where((u) => filter == null || u.role == filter).toList()
          ..sort((a, b) => a.role.index != b.role.index ? a.role.index - b.role.index : a.fullName.compareTo(b.fullName));
        return Column(children: [
          TopHero('Accounts', '${app.managedUsers.length} accounts • names and numbers are masked'),
          Expanded(
            child: RList(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: [
              Wrap(spacing: 8, children: [
                for (final e in <Role?, String>{null: 'All', Role.raiser: 'Farmers', Role.vet: 'Vets', Role.store: 'Stores'}.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: filter == e.key,
                    backgroundColor: C.pill,
                    selectedColor: C.amber,
                    labelStyle: TextStyle(color: filter == e.key ? C.onAmber : C.ink),
                    onSelected: (_) => setState(() => filter = e.key),
                  ),
              ]),
              const SizedBox(height: 10),
              if (users.isEmpty) const Box(child: Text('No accounts found.')),
              for (final u in users)
                Box(
                  onTap: () => showModalBottomSheet(
                      context: c, isScrollControlled: true, builder: (_) => AccountSheet(u)),
                  child: Row(children: [
                    CircleAvatar(
                        radius: 24,
                        backgroundColor: C.green.withAlpha(40),
                        child: Icon(_ic(u.role), color: C.green)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(maskName(u.fullName), style: h(17)),
                      Text('@${u.username} • ${maskPhone(u.phone)}', style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, children: [
                        Pill(_roleName(u.role), C.d ? const Color(0xFF8FB0F0) : C.navy),
                        u.active ? Pill('Active', C.green) : Pill('Deactivated', const Color(0xFFB3261E)),
                      ]),
                    ])),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
            ]),
          ),
        ]);
      });
}

/// Edit one account: profile fields, deactivate / reactivate, reset password.
class AccountSheet extends StatefulWidget {
  final User u;
  const AccountSheet(this.u, {super.key});
  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  final name = TextEditingController(), phone = TextEditingController(), place = TextEditingController(), pw = TextEditingController();
  bool busy = false;
  String? msg;

  @override
  void initState() {
    super.initState();
    pw.addListener(() => setState(() {}));
  }

  Future<void> _save() async {
    setState(() => busy = true);
    await app.adminSaveProfile(widget.u, fullName: name.text, phone: phone.text, place: place.text);
    if (!mounted) return;
    name.clear();
    phone.clear();
    place.clear();
    setState(() {
      busy = false;
      msg = 'Saved.';
    });
  }

  Future<void> _toggle() async {
    setState(() => busy = true);
    try {
      await app.adminSetActive(widget.u, !widget.u.active);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      busy = false;
      msg = widget.u.active ? 'Account is active again.' : 'Account deactivated. The user can no longer log in.';
    });
  }

  Future<void> _reset() async {
    setState(() => busy = true);
    String? e;
    try {
      e = await app.adminResetPassword(widget.u, pw.text);
    } catch (_) {
      e = 'Could not reset the password.';
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      msg = e ?? 'Password reset. Give the new password to the user.';
      if (e == null) pw.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    return rx((c) => Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(context).viewInsets.bottom + 18),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Edit account', style: h(22)),
              Text('@${u.username} • ${u.role == Role.raiser ? 'Farmer' : u.role == Role.vet ? 'Vet / Tech' : 'Store owner'}'),
              const SizedBox(height: 4),
              Text('Name ${maskName(u.fullName)} • Phone ${maskPhone(u.phone)}', style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 12),
              Text('Leave a field empty to keep it as it is.', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'New full name')),
              const SizedBox(height: 8),
              TextField(controller: phone, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'New mobile number (10 digits)')),
              const SizedBox(height: 8),
              TextField(controller: place, decoration: InputDecoration(labelText: 'Barangay / location', hintText: u.place)),
              const SizedBox(height: 10),
              FilledButton(onPressed: busy ? null : _save, child: const Text('Save changes')),
              const Divider(height: 28),
              Text('Reset password', style: h(18)),
              const SizedBox(height: 6),
              TextField(
                controller: pw,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New temporary password'),
              ),
              if (pw.text.isNotEmpty) pwChecklist(pw.text),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: busy || !PwCheck(pw.text).ok ? null : _reset, child: const Text('Reset password')),
              const Divider(height: 28),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: u.active ? const Color(0xFFB3261E) : C.green),
                onPressed: busy ? null : _toggle,
                child: Text(u.active ? 'Deactivate account' : 'Reactivate account'),
              ),
              if (msg != null)
                Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(msg!, style: TextStyle(fontWeight: FontWeight.w700, color: C.green))),
            ]),
          ),
        ));
  }
}

// ---------------------------------------------------------------- Debug (hidden)
/// Buttons that send a test notification of each kind to this admin account (bell list + phone).
class AdminDebug extends StatelessWidget {
  const AdminDebug({super.key});

  @override
  Widget build(BuildContext context) => rx((c) {
        const kinds = [
          ('sub_bought', 'Subscription bought', Icons.workspace_premium),
          ('sub_ending', 'Subscription ending in 7 days (with Extend)', Icons.hourglass_bottom),
          ('new_product', 'New product available', Icons.new_releases_outlined),
          ('booking_paid', 'New paid booking', Icons.event_available),
          ('reservation', 'New reservation', Icons.shopping_bag_outlined),
          ('pay_ok', 'Payment successful (payer)', Icons.check_circle_outline),
          ('pay_in', 'GCash payment received (admin)', Icons.account_balance_wallet_outlined),
          ('product_removed', 'Product not available', Icons.remove_shopping_cart_outlined),
          ('fee', 'AniCare 5% fee recorded', Icons.payments_outlined),
        ];
        return Column(children: [
          const TopHero('Debug', 'Test notifications • admin only'),
          Expanded(
            child: RList(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: [
              Box(
                  child: const Text(
                      'Each button sends a test notification to this account: a phone notification and an entry in the bell list. This tab hides again when you log out or restart the app.',
                      style: TextStyle(fontSize: 13))),
              for (final k in kinds)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FilledButton.icon(
                    onPressed: () async {
                      await app.debugNotify(k.$1);
                      if (c.mounted) toast(c, 'Sent: ${k.$2}');
                    },
                    icon: Icon(k.$3),
                    label: Text(k.$2),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const NotificationsPage())),
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Open the notification list'),
              ),
            ]),
          ),
        ]);
      });
}

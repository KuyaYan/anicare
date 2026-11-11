import 'package:flutter/material.dart';
import 'data.dart';
import 'ui.dart';
import 'auth.dart';

// ---------------------------------------------------------------- vet shell
class VetShell extends StatefulWidget {
  const VetShell({super.key});
  @override
  State<VetShell> createState() => _VetState();
}

class _VetState extends State<VetShell> {
  int i = 0;
  void go(int n) => setState(() => i = n);
  @override
  Widget build(BuildContext context) => rx((c) => ShellBack(
        atHome: i == 0,
        toHome: () => go(0),
        child: AppScaffold(
          bar: mainBar(c),
          clearH: kHero,
          body: IndexedStack(index: i, children: const [VetHome(), VetBookings()]),
          nav: NavigationBar(
            selectedIndex: i,
            onDestinationSelected: go,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
              NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'Bookings'),
            ],
          ),
        ),
      ));
}

class VetHome extends StatelessWidget {
  const VetHome({super.key});
  @override
  Widget build(BuildContext context) => rx((c) {
        final bs = app.vetBookings;
        final pending = bs.where((b) => b.status == BStatus.pending).length;
        return Column(children: [
          TopHero(app.me.name, '${app.me.kind} • Bunawan'),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), children: [
              Row(children: [
                Stat('$pending', 'New requests', C.amber, fg: C.onAmber),
                Stat('${bs.where((b) => b.status == BStatus.accepted).length}', 'Upcoming', C.navy),
                Stat(money(app.vetEarnings), 'Earned (after 2.5%)', C.green),
              ]),
              const SizedBox(height: 8),
              const Wide('Next requests'),
              if (bs.isEmpty) const Box(child: Text('No bookings yet.')),
              for (final b in bs.where((b) => b.status == BStatus.pending || b.status == BStatus.accepted).take(3))
                _card(c, b),
            ]),
          ),
        ]);
      });
}

class VetBookings extends StatelessWidget {
  const VetBookings({super.key});
  @override
  Widget build(BuildContext context) => rx((c) => Column(children: [
        TopHero('Bookings', '${app.vetBookings.length} total • accept, confirm, record'),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: [
            if (app.vetBookings.isEmpty) const Box(child: Text('No bookings yet.')),
            for (final b in app.vetBookings) _card(c, b),
          ]),
        ),
      ]));
}

Widget _card(BuildContext c, Booking b) => Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(b.raiser, style: h(18))),
          statusPill(b.status),
        ]),
        const SizedBox(height: 4),
        Text('${b.urgent ? '🚨 EMERGENCY • ' : ''}${b.animalName} • ${b.reason}'),
        Text('${fmt(b.date)}, ${b.time}', style: TextStyle(color: C.brown, fontWeight: FontWeight.w700)),
        Text('You receive ${money(b.vetGets)} (after 2.5% fee)', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        if (b.status == BStatus.pending)
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: () => app.setStatus(b, BStatus.declined), child: const Text('Decline'))),
            const SizedBox(width: 10),
            Expanded(
                child: FilledButton(
                    onPressed: () => app.setStatus(b, BStatus.accepted), child: const Text('Accept'))),
          ]),
        if (b.status == BStatus.accepted)
          Wrap(spacing: 8, children: [
            if (!b.vConfirm)
              FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(160, 40)),
                  onPressed: () => app.confirm(b, byRaiser: false),
                  child: const Text('Confirm completed')),
            if (b.vConfirm && !b.rConfirm)
              const Text('Waiting for raiser to confirm…',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        if ((b.status == BStatus.accepted || b.status == BStatus.completed) && b.animal != null)
          TextButton.icon(
              onPressed: () async {
                final v = await form(c, 'Record visit – ${b.animalName}', ['Diagnosis / treatment', 'Notes']);
                if (v != null && v[0].isNotEmpty) {
                  app.addRecord(b.animal!, Rec(0, app.now, v[0], v[1], app.me.name));
                  if (c.mounted) toast(c, 'Saved to ${b.animalName}\'s health record');
                }
              },
              icon: const Icon(Icons.edit_note),
              label: const Text('Record visit')),
        if (b.rating != null)
          Row(children: [
            const Text('Rating: '),
            for (var i = 0; i < b.rating!; i++) Icon(Icons.star, color: C.amber, size: 18),
          ]),
      ]),
    );

// ---------------------------------------------------------------- store
class StoreShell extends StatefulWidget {
  const StoreShell({super.key});
  @override
  State<StoreShell> createState() => _StoreState();
}

class _StoreState extends State<StoreShell> {
  int i = 0;
  void go(int n) => setState(() => i = n);
  @override
  Widget build(BuildContext context) => rx((c) => ShellBack(
        atHome: i == 0,
        toHome: () => go(0),
        child: AppScaffold(
          bar: mainBar(c),
          clearH: kHero,
          body: IndexedStack(index: i, children: const [Inventory(), Reservations(), StorePlan()]),
          nav: NavigationBar(
            selectedIndex: i,
            onDestinationSelected: go,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
              NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), label: 'Reservations'),
              NavigationDestination(icon: Icon(Icons.workspace_premium_outlined), label: 'Plan'),
            ],
          ),
        ),
      ));
}

class Inventory extends StatelessWidget {
  const Inventory({super.key});
  @override
  Widget build(BuildContext context) => rx((c) {
        final s = app.myStore;
        return Column(children: [
          TopHero(s.name, s.address),
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              floatingActionButton: FloatingActionButton.extended(
                  backgroundColor: C.amber,
                  foregroundColor: C.onAmber,
                  icon: const Icon(Icons.add),
                  label: const Text('Add product'),
                  onPressed: () async {
                    final v = await form(c, 'Add product', ['Product name', 'Price (₱)', 'Stock'],
                        numeric: {1, 2});
                    if (v == null || v[0].isEmpty) return;
                    app.addProduct(s, v[0], double.tryParse(v[1]) ?? 0, int.tryParse(v[2]) ?? 0);
                  }),
              body: ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: [
                Box(
                    child: Row(children: [
                  Pic(s.photo, w: 64, h: 64, r: 12, fallback: Icons.store),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${s.products.length} products listed', style: h(18))),
                ])),
                if (s.products.isEmpty)
                  const Box(child: Text('No products yet. Tap "Add product" to list your first item.')),
                for (final p in s.products)
                  Box(
                      child: Row(children: [
                    Pic(p.img, w: 50, h: 50, r: 8, fallback: Icons.medication),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: h(16)),
                      Text(money(p.price), style: h(16, C.green)),
                    ])),
                    IconButton(onPressed: () => app.stock(p, -1), icon: const Icon(Icons.remove_circle_outline)),
                    SizedBox(
                        width: 34,
                        child: Text('${p.stock}',
                            textAlign: TextAlign.center,
                            style: h(18, p.stock == 0 ? C.brown : C.ink))),
                    IconButton(onPressed: () => app.stock(p, 1), icon: const Icon(Icons.add_circle_outline)),
                  ])),
                const SizedBox(height: 70),
              ]),
            ),
          ),
        ]);
      });
}

class Reservations extends StatelessWidget {
  const Reservations({super.key});
  @override
  Widget build(BuildContext context) => rx((c) {
        final rs = app.storeReservations;
        return Column(children: [
          TopHero('Reservations', '${rs.length} from raisers'),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: [
              if (rs.isEmpty)
                const Box(
                    child: Text(
                        'No reservations yet. They appear here when farmers reserve your products.')),
              for (final r in rs)
                Box(
                    child: Row(children: [
                  Pic(r.product.img, w: 50, h: 50, r: 8, fallback: Icons.medication),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r.product.name} × ${r.qty}', style: h(16)),
                    Text('${r.raiserName} • Paid ${money(r.total)} via ${r.method}',
                        style: const TextStyle(fontSize: 13)),
                  ])),
                  r.pickedUp
                      ? Pill('Picked up', C.green)
                      : FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(110, 40)),
                          onPressed: () => app.pickedUp(r),
                          child: const Text('Picked up')),
                ])),
            ]),
          ),
        ]);
      });
}

/// Store subscription (Figma: ₱39 / month, text-only auto-renew note).
class StorePlan extends StatelessWidget {
  const StorePlan({super.key});
  @override
  Widget build(BuildContext context) => rx((c) => Column(children: [
        const TopHero('My Plan', 'AniCare Store subscription'),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 16), children: [
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AniCare Store', style: h(22, Colors.white)),
                const SizedBox(height: 6),
                Text('${money(AppState.planPrice)} / month', style: h(34, Colors.white)),
                const SizedBox(height: 12),
                for (final t in [
                  'List store location and available products.',
                  'Help raisers find nearby animal-health supplies.'
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Image.asset('assets/img/check_amber.png', width: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 15))),
                    ]),
                  ),
              ]),
            ),
            Box(
                child: Row(children: [
              Icon(app.planActive ? Icons.check_circle : Icons.error, color: app.planActive ? C.green : C.brown),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(app.planActive ? 'Active until ${fmt(app.planUntil)}' : 'Plan expired',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const Text('Auto-renews at standard agricultural tier', style: TextStyle(fontSize: 12.5)),
              ])),
            ])),
            FilledButton.icon(
                onPressed: () async {
                  final m = await pay(c, 'AniCare Store – 1 month',
                      [MapEntry('Monthly subscription', AppState.planPrice)]);
                  if (m == null || !c.mounted) return;
                  app.payPlan();
                  toast(c, 'Plan renewed via $m');
                },
                icon: const Icon(Icons.autorenew),
                label: const Text('Renew early')),
          ]),
        ),
      ]));
}

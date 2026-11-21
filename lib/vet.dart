import 'package:flutter/material.dart';
import 'data.dart';
import 'ui.dart';
import 'gcash.dart';
import 'photos.dart';

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
          TopHero(app.me.name, '${app.me.kind} • Bunawan', trailing: cogButton(c)),
          Expanded(
            child: RList(padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), children: [
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
          child: RList(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: [
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
                if (v == null || v[0].isEmpty || !c.mounted) return;
                try {
                  await app.addRecord(b.animal!, Rec(0, app.now, v[0], v[1], app.me.name));
                  if (c.mounted) toast(c, 'Saved to ${b.animalName}\'s health record');
                } catch (_) {
                  if (c.mounted) {
                    toast(c, 'Could not save the record. Check your connection or Supabase permissions.');
                  }
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

  void _askExtend() {
    if (!app.planPrompt) return;
    app.planPrompt = false;
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Your plan ends soon', style: h(20)),
        content: Text('Your store plan ends on ${fmt(app.planUntil)}. Do you want to extend it for ₱39?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Later')),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(120, 42)),
              onPressed: () {
                Navigator.pop(d);
                go(2);
              },
              child: const Text('Extend plan')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => rx((c) {
        if (app.planPrompt) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _askExtend();
          });
        }
        return ShellBack(
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
      );
      });
}

class Inventory extends StatelessWidget {
  const Inventory({super.key});
  @override
  Widget build(BuildContext context) => rx((c) {
        final s = app.myStore;
        return Column(children: [
          TopHero(s.name, s.address, trailing: cogButton(c)),
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              floatingActionButton: FloatingActionButton.extended(
                  backgroundColor: C.amber,
                  foregroundColor: C.onAmber,
                  icon: const Icon(Icons.add),
                  label: const Text('Add product'),
                  onPressed: () => addProductDialog(c, s)),
              body: RList(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: [
                Box(
                    child: Row(children: [
                  Pic(s.photo, w: 64, h: 64, r: 12, fallback: Icons.store),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${s.listed.length} products listed', style: h(18))),
                ])),
                if (s.listed.isEmpty)
                  const Box(child: Text('No products yet. Tap "Add product" to list your first item.')),
                for (final p in s.listed)
                  Box(
                      child: Row(children: [
                    Pic(p.img, w: 50, h: 50, r: 8, fallback: Icons.medication),
                    const SizedBox(width: 10),
                    Expanded(
                        child: InkWell(
                      onTap: () => addProductDialog(c, s, edit: p),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: Text(p.name, style: h(16))),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_outlined, size: 14, color: C.brown),
                        ]),
                        Text('${money(p.price)} • ${p.cat}', style: h(14, C.green)),
                        if (p.expiry != null) Text('Expires ${fmt(p.expiry!)}', style: const TextStyle(fontSize: 12)),
                      ]),
                    )),
                    IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => app.stock(p, -1),
                        icon: const Icon(Icons.remove_circle_outline)),
                    SizedBox(
                        width: 30,
                        child: Text('${p.stock}',
                            textAlign: TextAlign.center,
                            style: h(18, p.stock == 0 ? C.brown : C.ink))),
                    IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => app.stock(p, 1),
                        icon: const Icon(Icons.add_circle_outline)),
                    IconButton(
                        tooltip: 'Remove product',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => removeProductDialog(c, s, p),
                        icon: Icon(Icons.delete_outline, color: C.brown)),
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
            child: RList(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: [
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
                    if (!r.product.available)
                      Padding(padding: const EdgeInsets.only(top: 4), child: Pill('Not available', C.brown)),
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
          child: RList(padding: const EdgeInsets.fromLTRB(14, 0, 14, 16), children: [
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
                  final gref = await pay(c, 'AniCare Store – 1 month',
                      [MapEntry('Monthly subscription', AppState.planPrice)],
                      per: 'per month');
                  if (gref == null || !c.mounted) return;
                  await app.payPlan('GCash', ref: gref);
                  if (c.mounted) toast(c, 'Plan renewed. Paid with GCash.');
                },
                icon: const Icon(Icons.autorenew),
                label: const Text('Renew early')),
          ]),
        ),
      ]));
}

/// Trash button: asks first, then hides the product (history stays, farmers see "Not available").
Future<void> removeProductDialog(BuildContext c, Store s, Product p) async {
  final ok = await showDialog<bool>(
    context: c,
    builder: (d) => AlertDialog(
      title: Text('Remove product?', style: h(20)),
      content: Text(
          '${p.name} will be removed from your list. Farmers will see it as "Not available" and get a notification. Past reservations stay in the history.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 42)),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Remove')),
      ],
    ),
  );
  if (ok != true) return;
  await app.removeProduct(s, p);
  if (c.mounted) toast(c, '${p.name} removed');
}

/// Add a product: name, category, price, stock and (optional) expiry date.
Future<void> addProductDialog(BuildContext c, Store s, {Product? edit}) async {
  const cats = ['Vaccine', 'Dewormer', 'Supplement', 'Antibiotic', 'Other'];
  final name = TextEditingController(text: edit?.name ?? ''),
      price = TextEditingController(text: edit == null ? '' : edit.price.toString()),
      stock = TextEditingController(text: edit == null ? '' : '${edit.stock}');
  var cat = edit != null && cats.contains(edit.cat) ? edit.cat : (edit == null ? 'Vaccine' : 'Other');
  DateTime? expiry = edit?.expiry;
  String? photo; // optional picture from the gallery
  var up = false;
  final ok = await showDialog<bool>(
    context: c,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: Text(edit == null ? 'Add product' : 'Edit product', style: h(20)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Product name')),
            const SizedBox(height: 10),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: cat,
                dropdownColor: C.surface,
                items: [
                  for (final k in cats)
                    DropdownMenuItem(value: k, child: Text(k))
                ],
                onChanged: (x) => set(() => cat = x ?? cat),
              ),
            ),
            TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price (₱)')),
            const SizedBox(height: 10),
            TextField(
                controller: stock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock')),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () async {
                final x = await showDatePicker(
                    context: d,
                    initialDate: DateTime.now().add(const Duration(days: 180)),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)));
                if (x != null) set(() => expiry = x);
              },
              icon: const Icon(Icons.event),
              label: Text(expiry == null ? 'Expiry date (optional)' : 'Expires ${fmt(expiry!)}'),
            ),
            TextButton.icon(
              onPressed: up
                  ? null
                  : () async {
                      set(() => up = true);
                      final p = await pickPhoto(d);
                      if (!d.mounted) return;
                      set(() {
                        up = false;
                        if (p != null) photo = p;
                      });
                    },
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(up
                  ? 'Uploading…'
                  : photo != null
                      ? 'Photo added, tap to change'
                      : edit == null
                          ? 'Photo (optional)'
                          : 'Change photo'),
            ),
            if (photo != null || edit?.img != null) Pic(photo ?? edit?.img, w: 80, h: 80, r: 12),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(90, 42)),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Save')),
        ],
      ),
    ),
  );
  if (ok != true || name.text.trim().isEmpty) return;
  if (edit != null) {
    app.editProduct(edit,
        name: name.text.trim(),
        price: double.tryParse(price.text.trim()) ?? edit.price,
        stock: int.tryParse(stock.text.trim()) ?? edit.stock,
        cat: cat,
        expiry: expiry,
        photo: photo);
    if (c.mounted) toast(c, 'Product updated');
    return;
  }
  app.addProduct(s, name.text.trim(), double.tryParse(price.text.trim()) ?? 0, int.tryParse(stock.text.trim()) ?? 0,
      cat: cat, expiry: expiry, photo: photo);
}

/// The store plan as its own screen (opened from the notification or the "extend?" question).
class StorePlanPage extends StatelessWidget {
  const StorePlanPage({super.key});
  @override
  Widget build(BuildContext context) =>
      rx((c) => AppScaffold(bar: subBar('My Plan'), clearH: kHero, body: const StorePlan()));
}

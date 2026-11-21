import 'package:flutter/material.dart';
import 'data.dart';
import 'ui.dart';
import 'gcash.dart';
import 'photos.dart';

// ---------------------------------------------------------------- shell
class RaiserShell extends StatefulWidget {
  const RaiserShell({super.key});
  @override
  State<RaiserShell> createState() => _RaiserState();
}

class _RaiserState extends State<RaiserShell> {
  int i = 0;
  void go(int n) => setState(() => i = n);

  @override
  Widget build(BuildContext context) => rx((c) {
        final tabs = [
          HomeTab(go: go),
          const AnimalsTab(),
          FindTab(go: go),
          const BookingsTab(),
        ];
        return ShellBack(
          atHome: i == 0,
          toHome: () => go(0),
          child: AppScaffold(
            bar: mainBar(c),
            clearH: kHero,
            body: IndexedStack(index: i, children: tabs),
            nav: NavigationBar(
              selectedIndex: i,
              onDestinationSelected: go,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.pets_outlined), label: 'Animals'),
                NavigationDestination(icon: Icon(Icons.search), label: 'Find'),
                NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'Bookings'),
              ],
            ),
          ),
        );
      });
}

// ---------------------------------------------------------------- home
class HomeTab extends StatelessWidget {
  final void Function(int) go;
  const HomeTab({super.key, required this.go});

  @override
  Widget build(BuildContext context) => rx((c) {
        final due = app.upcoming;
        final soon = due.where((d) => d.s.date.difference(app.now).inDays <= 7).length;
        return Column(children: [
          TopHero('Good day, ${app.user?.greet ?? ''}',
              '$soon reminder${soon == 1 ? '' : 's'} due this week',
              trailing: cogButton(c)),
          Expanded(
            child: RList(padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), children: [
              Row(children: [
                Stat('${app.totalHeads}', 'Animals', C.green),
                Stat('$soon', 'Due soon', C.amber, fg: C.onAmber),
                Stat(money(app.totalSpent), 'Total spent', C.navy),
              ]),
              const SizedBox(height: 14),
              FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: C.amber, foregroundColor: C.onAmber),
                  onPressed: () => emergency(c, go),
                  icon: const Icon(Icons.local_hospital),
                  label: const Text('Need a vet now?  Emergency')),
              const SizedBox(height: 8),
              const Wide('Upcoming reminders'),
              if (due.isEmpty)
                const Box(
                    radius: rSq,
                    child: Text('No reminders yet. Add an animal and its vaccine and deworming schedule will show up here.')),
              for (final d in due.take(5))
                Box(
                  radius: rSq,
                  child: Row(children: [
                    Pic(remImg(d.s.label) ?? d.a.photo, w: 50, h: 50, r: 6, fallback: d.a.sp.icon),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.s.label, style: h(17)),
                      Text('${d.a.name} • ${fmt(d.s.date)}', style: const TextStyle(fontSize: 13)),
                    ])),
                    IconButton(
                        tooltip: 'Mark done',
                        icon: Icon(Icons.check_circle_outline, color: C.green, size: 28),
                        onPressed: () {
                          app.markDone(d.a, d.s);
                          toast(c, '${d.s.label} saved to ${d.a.name}\'s records');
                        }),
                  ]),
                ),
            ]),
          ),
        ]);
      });
}

/// Emergency request: free for everyone (no visit fee), goes to the nearest vet.
void emergency(BuildContext c, void Function(int) go) {
  final v = ([...app.vets]..sort((a, b) => a.km.compareTo(b.km))).first;
  Navigator.push(c, MaterialPageRoute(builder: (_) => BookPage(v, urgent: true)));
}

// ---------------------------------------------------------------- animals
class AnimalsTab extends StatelessWidget {
  const AnimalsTab({super.key});
  @override
  Widget build(BuildContext context) => rx((c) => Column(children: [
        TopHero('My Animals', '${app.totalHeads} heads • ${app.animals.length} records'),
        Expanded(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: FloatingActionButton.extended(
                backgroundColor: C.amber,
                foregroundColor: C.onAmber,
                onPressed: () => showModalBottomSheet(
                    context: c, isScrollControlled: true, builder: (_) => const AddAnimalSheet()),
                icon: const Icon(Icons.add),
                label: const Text('Add animal')),
            body: RList(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: [
              if (app.animals.isEmpty)
                const Box(child: Text('No animals yet. Tap "Add animal" to start your first record, and a vaccine schedule is created for you.')),
              for (final a in app.animals)
                Box(
                  onTap: () =>
                      Navigator.push(c, MaterialPageRoute(builder: (_) => AnimalPage(a))),
                  child: Row(children: [
                    Pic(a.photo, w: 72, h: 72, fallback: a.sp.icon),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.name, style: h(19)),
                      Text(a.sub),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, children: [
                        Pill('${a.sched.where((s) => !s.done).length} upcoming', C.green),
                        Pill(money(a.spent), C.d ? const Color(0xFF8FB0F0) : C.navy),
                      ]),
                    ])),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              const SizedBox(height: 70),
            ]),
          ),
        ),
      ]));
}

class AddAnimalSheet extends StatefulWidget {
  const AddAnimalSheet({super.key});
  @override
  State<AddAnimalSheet> createState() => _AddState();
}

class _AddState extends State<AddAnimalSheet> {
  final name = TextEditingController(),
      breed = TextEditingController(),
      count = TextEditingController(text: '10');
  Species sp = Species.hog;
  bool flock = false;
  String? photo; // optional picture from the gallery
  bool uploading = false;

  @override
  Widget build(BuildContext context) => rx((c) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(context).viewInsets.bottom + 18),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add animal', style: h(22)),
            const SizedBox(height: 12),
            SegmentedButton<Species>(
              segments: [
                for (final s in Species.values)
                  ButtonSegment(value: s, label: Text(s.label), icon: Icon(s.icon))
              ],
              selected: {sp},
              onSelectionChanged: (v) => setState(() => sp = v.first),
            ),
            const SizedBox(height: 10),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name / tag')),
            const SizedBox(height: 10),
            TextField(controller: breed, decoration: const InputDecoration(labelText: 'Breed')),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Track as a flock / group'),
                value: flock,
                onChanged: (v) => setState(() => flock = v)),
            if (flock)
              TextField(
                  controller: count,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Number of heads')),
            const SizedBox(height: 6),
            Row(children: [
              if (photo != null) ...[Pic(photo, w: 56, h: 56, r: 10, fallback: sp.icon), const SizedBox(width: 10)],
              Expanded(
                child: OutlinedButton.icon(
                    onPressed: uploading
                        ? null
                        : () async {
                            setState(() => uploading = true);
                            final p = await pickPhoto(context);
                            if (!mounted) return;
                            setState(() {
                              uploading = false;
                              if (p != null) photo = p;
                            });
                          },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(uploading ? 'Uploading…' : photo == null ? 'Add photo (optional)' : 'Change photo')),
              ),
            ]),
            const SizedBox(height: 10),
            FilledButton(
                onPressed: () {
                  if (name.text.trim().isEmpty) return toast(context, 'Please enter a name');
                  app.addAnimal(name.text.trim(), sp, breed.text.trim(), flock,
                      int.tryParse(count.text) ?? 1, picked: photo);
                  Navigator.pop(context);
                },
                child: const Text('Save & create schedule')),
          ]),
        ),
      ));
}

class AnimalPage extends StatelessWidget {
  final Animal a;
  const AnimalPage(this.a, {super.key});

  @override
  Widget build(BuildContext context) => rx((c) => DefaultTabController(
        length: 3,
        child: AppScaffold(
          bar: subBar(a.name,
              bottom: const TabBar(
                  indicatorColor: Color(0xFFF2A73B),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [Tab(text: 'Schedule'), Tab(text: 'Records'), Tab(text: 'Expenses')]),
              extra: [
                PopupMenuButton<String>(
                  tooltip: 'Edit or delete',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (v) => v == 'edit' ? _edit(c) : _delete(c),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit animal')),
                    PopupMenuItem(value: 'delete', child: Text('Delete animal')),
                  ],
                ),
              ]),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Box(
                  child: Row(children: [
                GestureDetector(
                  onTap: () async {
                    final p = await pickPhoto(c);
                    if (p != null) app.setAnimalPhoto(a, p);
                  },
                  child: Stack(children: [
                    Pic(a.photo, w: 80, h: 80, fallback: a.sp.icon),
                    Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: C.green, shape: BoxShape.circle),
                            child: const Icon(Icons.photo_library_outlined, size: 14, color: Colors.white))),
                  ]),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.name, style: h(20)),
                  Text(a.sub),
                  const SizedBox(height: 4),
                  Text('Total spent: ${money(a.spent)}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: C.green)),
                ])),
              ])),
            ),
            Expanded(
              child: TabBarView(children: [
                RList(padding: const EdgeInsets.symmetric(horizontal: 14), children: [
                  for (final s in a.sched)
                    Box(
                        radius: rSq,
                        child: Row(children: [
                          Pic(remImg(s.label) ?? a.photo, w: 44, h: 44, r: 6, fallback: a.sp.icon),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.label, style: h(17)),
                            Text(s.done ? 'Done' : 'Due ${fmt(s.date)}'),
                          ])),
                          if (s.done)
                            IconButton(
                                tooltip: 'Tap to mark as not done',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                onPressed: () {
                                  app.unmarkDone(a, s);
                                  toast(c, '${s.label} marked as not done');
                                },
                                icon: Image.asset('assets/img/check_blue.png', width: 26))
                          else
                            TextButton(onPressed: () => app.markDone(a, s), child: const Text('Mark done')),
                        ])),
                ]),
                _list('Add note', [
                  for (final r in a.recs)
                    Box(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(r.title, style: h(17))),
                        Text(fmt(r.date), style: const TextStyle(fontSize: 12)),
                        if (app.canEditRec(r))
                          IconButton(
                              tooltip: 'Edit note',
                              visualDensity: VisualDensity.compact,
                              onPressed: () async {
                                final v = await form(c, 'Edit note', ['Title', 'Note'], initial: [r.title, r.note]);
                                if (v != null && v[0].isNotEmpty) app.editRecord(r, v[0], v[1]);
                              },
                              icon: Icon(Icons.edit_outlined, size: 20, color: C.brown)),
                      ]),
                      const SizedBox(height: 4),
                      Text(r.note),
                      const SizedBox(height: 4),
                      Text('By ${r.by}',
                          style: TextStyle(color: C.brown, fontSize: 12, fontWeight: FontWeight.w600)),
                    ])),
                ], () async {
                  final v = await form(c, 'Add note', ['Title', 'Note']);
                  if (v != null && v[0].isNotEmpty) app.addRecord(a, Rec(0, app.now, v[0], v[1], 'Raiser'));
                }),
                _list('Add expense', [
                  for (final e in a.exps)
                    Box(
                        child: Row(children: [
                      Icon(Icons.receipt_long, color: C.brown),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.item, style: h(17)),
                        Text(fmt(e.date), style: const TextStyle(fontSize: 12)),
                      ])),
                      Text(money(e.amount), style: h(17, C.green)),
                      IconButton(
                          tooltip: 'Edit expense',
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            final v = await form(c, 'Edit expense', ['Item', 'Amount (₱)'],
                                numeric: {1}, initial: [e.item, e.amount.toStringAsFixed(2)]);
                            final amt = v == null ? null : double.tryParse(v[1]);
                            if (v != null && v[0].isNotEmpty && amt != null) app.editExpense(e, v[0], amt);
                          },
                          icon: Icon(Icons.edit_outlined, size: 20, color: C.brown)),
                      IconButton(
                          tooltip: 'Delete expense',
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            if (await confirmDelete(c, 'Delete expense?', '${e.item} (${money(e.amount)}) will be removed.')) {
                              app.deleteExpense(a, e);
                            }
                          },
                          icon: Icon(Icons.delete_outline, size: 20, color: C.brown)),
                    ])),
                ], () async {
                  final v = await form(c, 'Add expense', ['Item', 'Amount (₱)'], numeric: {1});
                  final amt = v == null ? null : double.tryParse(v[1]);
                  if (v != null && v[0].isNotEmpty && amt != null) {
                    app.addExpense(a, Exp(0, app.now, v[0], amt));
                  }
                }),
              ]),
            ),
          ]),
        ),
      ));

  Future<void> _edit(BuildContext c) async {
    final v = await form(c, 'Edit animal', ['Name / tag', 'Breed', if (a.flock) 'Number of heads'],
        numeric: {2}, initial: [a.name, a.breed, if (a.flock) '${a.count}']);
    if (v == null || !c.mounted) return;
    if (v[0].isEmpty) return toast(c, 'Please enter a name');
    app.editAnimal(a, v[0], v[1], a.flock ? (int.tryParse(v[2]) ?? a.count) : 1);
    if (c.mounted) toast(c, 'Animal updated');
  }

  Future<void> _delete(BuildContext c) async {
    final yes = await confirmDelete(c, 'Delete ${a.name}?',
        'Its schedule, health records and expenses are deleted too. This cannot be undone.');
    if (!yes || !c.mounted) return;
    final ok = await app.deleteAnimal(a);
    if (!c.mounted) return;
    toast(c, ok ? '${a.name} deleted' : 'Could not delete. Please check your connection.');
    if (ok) Navigator.pop(c);
  }
  Widget _list(String btn, List<Widget> items, VoidCallback add) => ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
        children: [
          ...items,
          OutlinedButton.icon(onPressed: add, icon: const Icon(Icons.add), label: Text(btn)),
        ],
      );
}

// ---------------------------------------------------------------- find
class FindTab extends StatefulWidget {
  final void Function(int) go;
  const FindTab({super.key, required this.go});
  @override
  State<FindTab> createState() => _FindState();
}

class _FindState extends State<FindTab> {
  int seg = 0;
  String q = '';

  @override
  Widget build(BuildContext context) => rx((c) {
        final vets = [...app.vets]..sort((a, b) => a.km.compareTo(b.km));
        final stores = [...app.stores]..sort((a, b) => a.km.compareTo(b.km));
        final meds = [
          for (final s in stores)
            for (final p in s.products)
              if (p.available && (q.isEmpty || p.name.toLowerCase().contains(q.toLowerCase()))) (s, p)
        ];
        return Column(children: [
          const TopHero('Find Care', 'Sorted by distance • Bunawan only'),
          Expanded(
            child: RList(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: [
              Container(
                decoration: BoxDecoration(color: C.pill, borderRadius: BorderRadius.circular(rPill)),
                padding: const EdgeInsets.all(4),
                child: SegmentedButton<int>(
                  style: SegmentedButton.styleFrom(
                      foregroundColor: C.ink,
                      selectedForegroundColor: Colors.white,
                      selectedBackgroundColor: C.green,
                      backgroundColor: Colors.transparent),
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Vets'), icon: Icon(Icons.medical_services_outlined)),
                    ButtonSegment(value: 1, label: Text('Stores'), icon: Icon(Icons.storefront_outlined)),
                    ButtonSegment(value: 2, label: Text('Medicine'), icon: Icon(Icons.medication_outlined)),
                  ],
                  selected: {seg},
                  onSelectionChanged: (v) => setState(() => seg = v.first),
                ),
              ),
              const SizedBox(height: 10),
              if (seg == 0)
                for (final v in vets)
                  Box(
                    onTap: () =>
                        Navigator.push(c, MaterialPageRoute(builder: (_) => VetProfile(v))),
                    child: Row(children: [
                      Pic(v.photo, w: 66, h: 66, r: 33, fallback: Icons.person),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: Text(v.name, style: h(17))),
                          const SizedBox(width: 4),
                          Image.asset('assets/img/check_blue.png', width: 16),
                        ]),
                        Text('${v.kind} • ${v.km} km', style: const TextStyle(fontSize: 13)),
                        Text('★ ${v.ratingText}  •  ${money(v.fee)} / visit',
                            style: TextStyle(color: C.brown, fontWeight: FontWeight.w700)),
                      ])),
                    ]),
                  ),
              if (seg == 1)
                for (final s in stores)
                  Box(
                    onTap: () =>
                        Navigator.push(c, MaterialPageRoute(builder: (_) => StorePage(s))),
                    child: Row(children: [
                      Pic(s.photo, w: 66, h: 66, r: 12, fallback: Icons.store),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.name, style: h(17)),
                        Text('${s.address} • ${s.km} km', style: const TextStyle(fontSize: 13)),
                        Text('${s.listed.length} products listed',
                            style: TextStyle(color: C.brown, fontWeight: FontWeight.w700)),
                      ])),
                    ]),
                  ),
              if (seg == 2) ...[
                TextField(
                    onChanged: (v) => setState(() => q = v),
                    decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search, color: C.ink),
                        hintText: 'Search e.g. Ivermectin')),
                const SizedBox(height: 10),
                if (meds.isEmpty) const Box(child: Text('No products found.')),
                for (final m in meds)
                  Box(
                    onTap: () =>
                        m.$2.stock == 0 ? toast(c, 'Out of stock') : reserveDialog(c, m.$1, m.$2),
                    child: Row(children: [
                      Pic(m.$2.img, w: 54, h: 54, r: 8, fallback: Icons.medication),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.$2.name, style: h(16)),
                        Text('${m.$1.name} • ${m.$1.km} km', style: const TextStyle(fontSize: 13)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(money(m.$2.price), style: h(17, C.green)),
                        m.$2.stock == 0
                            ? Pill('Out of stock', C.brown)
                            : Pill('${m.$2.stock} in stock', C.green),
                      ]),
                    ]),
                  ),
              ],
            ]),
          ),
        ]);
      });
}

class VetProfile extends StatelessWidget {
  final Vet v;
  const VetProfile(this.v, {super.key});
  @override
  Widget build(BuildContext context) => rx((c) => AppScaffold(
        bar: subBar('Provider profile'),
        body: RList(padding: const EdgeInsets.all(16), children: [
          Center(child: Pic(v.photo, w: 130, h: 130, r: 65, fallback: Icons.person)),
          const SizedBox(height: 10),
          Center(child: TPill(v.name, style: h(22))),
          const SizedBox(height: 8),
          Center(child: TPill('${v.kind} • ★ ${v.ratingText} • ${v.km} km away')),
          const SizedBox(height: 8),
          Center(
              child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: C.pill, borderRadius: BorderRadius.circular(rPill)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/img/check_blue.png', width: 18),
              const SizedBox(width: 6),
              const Text('Verified (mock)', style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
          )),
          const SizedBox(height: 14),
          Box(child: Text(v.about)),
          sec('Services'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in v.services)
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: C.pill, borderRadius: BorderRadius.circular(rPill)),
                  child: Text(s, style: const TextStyle(fontWeight: FontWeight.w600)))
          ]),
          sec('Fee'),
          Box(child: Text('${money(v.fee)} per visit', style: h(20, C.green))),
          const SizedBox(height: 10),
          FilledButton(
              onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => BookPage(v))),
              child: const Text('Book this provider')),
        ]),
      ));
}

class BookPage extends StatefulWidget {
  final Vet v;
  final bool urgent;
  const BookPage(this.v, {super.key, this.urgent = false});
  @override
  State<BookPage> createState() => _BookState();
}

class _BookState extends State<BookPage> {
  Animal? a = app.animals.isEmpty ? null : app.animals.first;
  late DateTime date = widget.urgent ? app.now : app.now.add(const Duration(days: 1));
  late String time = widget.urgent ? 'ASAP' : '9:00 AM';
  late final reason = TextEditingController(text: widget.urgent ? 'EMERGENCY' : '');
  bool useFree = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    return rx((c) {
      final prem = app.premium;
      final urgent = widget.urgent;
      final visit = urgent ? 0.0 : v.fee * (prem ? 1 - AppState.premDiscount : 1);
      final svc = (prem || urgent) ? 0.0 : visit * AppState.commissionRate / 2;
      final canFree = prem && app.freeChecks > 0 && !urgent;
      return AppScaffold(
        bar: subBar(widget.urgent ? 'Emergency request' : 'Book ${v.kind == 'Veterinarian' ? 'vet' : 'technician'}'),
        body: RList(padding: const EdgeInsets.all(16), children: [
          TPill(v.name, style: h(21)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(rPill)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Animal>(
                isExpanded: true,
                value: a,
                dropdownColor: C.surface,
                hint: const Text('Which animal / flock?'),
                style: TextStyle(color: C.ink, fontSize: 16, fontFamily: 'DMSans'),
                items: [for (final x in app.animals) DropdownMenuItem(value: x, child: Text(x.name))],
                onChanged: (x) => setState(() => a = x),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (!widget.urgent) ...[
            Box(
              onTap: () async {
                final d = await showDatePicker(
                    context: c,
                    initialDate: date,
                    firstDate: app.now,
                    lastDate: app.now.add(const Duration(days: 90)));
                if (d != null) setState(() => date = d);
              },
              child: Row(children: [
                Icon(Icons.calendar_month, color: C.green),
                const SizedBox(width: 12),
                Expanded(child: Text(fmt(date))),
                const Text('Change'),
              ]),
            ),
            Wrap(spacing: 8, children: [
              for (final t in ['8:00 AM', '9:00 AM', '10:00 AM', '1:00 PM', '2:00 PM', '4:00 PM'])
                ChoiceChip(
                    label: Text(t),
                    selected: time == t,
                    backgroundColor: C.pill,
                    selectedColor: C.amber,
                    labelStyle: TextStyle(color: time == t ? C.onAmber : C.ink),
                    onSelected: (_) => setState(() => time = t)),
            ]),
            const SizedBox(height: 10),
          ],
          TextField(
              controller: reason,
              decoration: const InputDecoration(hintText: 'Reason (e.g. vaccination)')),
          const SizedBox(height: 10),
          if (canFree)
            Box(
                child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Use a free Premium check-up (${app.freeChecks} left)'),
                    value: useFree,
                    onChanged: (x) => setState(() => useFree = x))),
          Box(
              child: Column(children: [
            _row(urgent ? 'Emergency visit fee (free)' : 'Visit fee${prem ? ' (Premium −10%)' : ''}', useFree ? 0 : visit),
            _row('AniCare fee (2.5%)${(prem || urgent) ? ' – waived' : ''}', useFree ? 0 : svc),
            const Divider(),
            _row('Total', useFree ? 0 : visit + svc, bold: true),
          ])),
          FilledButton(
              onPressed: a == null
                  ? null
                  : () async {
                      final total = useFree ? 0.0 : visit + svc;
                      var m = urgent ? 'Free' : 'Demo';
                      String? gref;
                      if (total > 0) {
                        gref = await pay(c, 'Booking with ${v.name}', [
                          MapEntry('Visit fee', visit),
                          if (svc > 0) MapEntry('AniCare fee (2.5%, other 2.5% paid by vet)', svc),
                        ], note: 'Payment is held and released when both you and the vet confirm the visit is completed.');
                        if (gref == null || !c.mounted) return;
                        m = 'GCash';
                      }
                      await app.book(v, a!, date, time, reason.text.trim(), m,
                          fee: visit, free: useFree, urgent: widget.urgent, ref: gref);
                      if (!c.mounted) return;
                      Navigator.popUntil(c, (r) => r.isFirst);
                      toast(c, widget.urgent
                          ? 'Emergency request sent to ${v.name}!'
                          : 'Booking sent! Waiting for ${v.name} to accept.');
                    },
              child: Text(urgent ? 'Send emergency request' : useFree ? 'Book free check-up' : 'Continue to payment')),
        ]),
      );
    });
  }

  Widget _row(String l, double v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400))),
          Text(money(v), style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400)),
        ]),
      );
}

class StorePage extends StatelessWidget {
  final Store s;
  const StorePage(this.s, {super.key});
  @override
  Widget build(BuildContext context) => rx((c) => AppScaffold(
        bar: subBar(s.name),
        body: RList(padding: const EdgeInsets.all(16), children: [
          Pic(s.photo, w: double.infinity, h: 150, r: 18, fallback: Icons.store),
          const SizedBox(height: 10),
          TPill('${s.address} • ${s.km} km away'),
          sec('Available products'),
          if (s.products.isEmpty) const Box(child: Text('No products listed yet.')),
          for (final p in s.products)
            Box(
              child: Row(children: [
                Pic(p.img, w: 56, h: 56, r: 8, fallback: Icons.medication),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: h(17)),
                  Text(p.cat),
                  Text(money(p.price), style: h(17, C.green)),
                ])),
                !p.available
                    ? Pill('Not available', C.brown)
                    : p.stock == 0
                    ? Pill('Out of stock', C.brown)
                    : FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(92, 40)),
                        onPressed: () => reserveDialog(c, s, p),
                        child: const Text('Reserve')),
              ]),
            ),
        ]),
      ));
}

Future<void> reserveDialog(BuildContext c, Store s, Product p) async {
  var qty = 1;
  final ok = await showDialog<bool>(
    context: c,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: Text(p.name, style: h(19)),
        content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              onPressed: qty > 1 ? () => set(() => qty--) : null,
              icon: const Icon(Icons.remove_circle_outline)),
          Text('$qty', style: h(24)),
          IconButton(
              onPressed: qty < p.stock ? () => set(() => qty++) : null,
              icon: const Icon(Icons.add_circle_outline)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(110, 42)),
              onPressed: () => Navigator.pop(d, true),
              child: Text('Pay ${money(p.price * qty)}')),
        ],
      ),
    ),
  );
  if (ok != true || !c.mounted) return;
  final gref = await pay(c, 'Reserve at ${s.name}', [MapEntry('${p.name} × $qty', p.price * qty)],
      note: 'Pick up at the store with your reservation.');
  if (gref == null || !c.mounted) return;
  await app.reserve(s, p, qty, 'GCash', ref: gref);
  if (!c.mounted) return;
  toast(c, 'Reserved! Show your reservation at ${s.name}.');
}

// ---------------------------------------------------------------- bookings
class BookingsTab extends StatelessWidget {
  const BookingsTab({super.key});
  @override
  Widget build(BuildContext context) => rx((c) => DefaultTabController(
        length: 2,
        child: Column(children: [
          const TopHero('My Bookings', 'Vet visits and store reservations'),
          Container(
              color: C.surface,
              child: TabBar(
                  labelColor: C.green,
                  unselectedLabelColor: C.ink,
                  indicatorColor: C.amber,
                  tabs: const [Tab(text: 'Vet visits'), Tab(text: 'Reservations')])),
          Expanded(
            child: TabBarView(children: [
              RList(padding: const EdgeInsets.all(14), children: [
                if (app.bookings.isEmpty) const Box(child: Text('No bookings yet.')),
                for (final b in app.bookings) _booking(c, b),
              ]),
              RList(padding: const EdgeInsets.all(14), children: [
                if (app.reservations.isEmpty) const Box(child: Text('No reservations yet.')),
                for (final r in app.reservations)
                  Box(
                      child: Row(children: [
                    Pic(r.product.img, w: 50, h: 50, r: 8, fallback: Icons.medication),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${r.product.name} × ${r.qty}', style: h(17)),
                      Text('${r.store.name}\nPaid ${money(r.total)} via ${r.method}',
                          style: const TextStyle(fontSize: 13)),
                      if (!r.product.available)
                        Padding(padding: const EdgeInsets.only(top: 4), child: Pill('Not available', C.brown)),
                    ])),
                    r.pickedUp ? Pill('Picked up', C.green) : Pill('Reserved', C.d ? const Color(0xFF8FB0F0) : C.navy),
                  ])),
              ]),
            ]),
          ),
        ]),
      ));

  Widget _booking(BuildContext c, Booking b) {
    final open = b.status == BStatus.pending || b.status == BStatus.accepted;
    return Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Pic(b.vet.photo, w: 44, h: 44, r: 22, fallback: Icons.person),
          const SizedBox(width: 10),
          Expanded(child: Text(b.vet.name, style: h(18))),
          statusPill(b.status),
        ]),
        const SizedBox(height: 6),
        Text('${b.urgent ? '🚨 ' : ''}${b.animalName} • ${b.reason}'),
        Text('${fmt(b.date)}, ${b.time}', style: TextStyle(color: C.brown, fontWeight: FontWeight.w700)),
        Text(b.status == BStatus.unpaid ? 'Payment not completed' : b.urgent ? 'Emergency – free' : b.free ? 'Free Premium check-up' : 'Paid ${money(b.raiserPays)} via ${b.method ?? '-'}',
            style: const TextStyle(fontSize: 12)),
        if (open) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            OutlinedButton(
                onPressed: () async {
                  final d = await showDatePicker(
                      context: c,
                      initialDate: b.date.isBefore(app.now) ? app.now : b.date,
                      firstDate: app.now,
                      lastDate: app.now.add(const Duration(days: 90)));
                  if (d != null) app.reschedule(b, d);
                },
                child: const Text('Reschedule')),
            OutlinedButton(
                onPressed: () {
                  app.setStatus(b, BStatus.cancelled);
                  toast(c, 'Cancelled. Refund sent to ${b.method ?? 'your wallet'} (demo).');
                },
                child: const Text('Cancel')),
            if (b.status == BStatus.accepted && !b.rConfirm)
              FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(160, 40)),
                  onPressed: () => app.confirm(b, byRaiser: true),
                  child: const Text('Confirm completed')),
          ]),
          if (b.rConfirm && !b.vConfirm)
            const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('You confirmed. Waiting for the vet to confirm…',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
        if (b.status == BStatus.completed)
          Row(children: [
            const Text('Rate: '),
            for (var i = 1; i <= 5; i++)
              GestureDetector(
                  onTap: () => app.rate(b, i),
                  child: Icon((b.rating ?? 0) >= i ? Icons.star : Icons.star_border, color: C.amber)),
          ]),
      ]),
    );
  }
}

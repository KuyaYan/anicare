# AniCare 1.3.2: changes to make

Baseline: your working **1.3.1** project (do not re-apply the 1.3.1 file). Version goes from `1.3.1+71` to `1.3.2+72`.

**Do the Supabase step from the chat first** (one small SQL). Then follow this file top to bottom.

## What this update adds

1. **Animals**: edit (name, breed, number of heads for a flock) and delete (with confirmation) from a three-dot menu on the animal page.
2. **Health records**: edit your own notes (pencil icon). Records are **not** deletable. Notes written by a vet and the automatic "Marked done" note cannot be edited.
3. **Expenses**: edit and delete (with confirmation).
4. **Products** (shop owner): tap a product's name to edit name, category, price, stock, expiry and photo.
5. **Login screen**: the autofill list under the username box is gone; the field is plain. Demo accounts are in `accounts.md`.
6. **About page** shows version 1.3.2 (it reads `kVersion`).

No new package. Nothing to run except `flutter pub get` and `flutter run`.

## How to read the patches

- **FIND** = text already in the file (copy exactly). **REPLACE WITH** = what it becomes. An empty replacement means delete the found text.
- **ADD ABOVE / ADD BELOW** = keep the FIND text and put the new text right before / after it.

## CRUD status after this update

| Item | Create | Read | Update | Delete |
|---|---|---|---|---|
| Animal | yes | yes | **yes (new)** | **yes (new)** |
| Schedule item | automatic | yes | mark done / undo | no (by your choice) |
| Health record | yes | yes | **yes (new, own notes)** | no (by your choice) |
| Expense | yes | yes | **yes (new)** | **yes (new)** |
| Product | yes | yes | **yes (new)** | yes (remove) |
| Tickets, accounts, bookings, reservations | unchanged from 1.3.1 | | | |

## Step 1: edits

### `pubspec.yaml`

**Patch 1: Version: REPLACE**

FIND:
```yaml
version: 1.3.1+71
```
REPLACE WITH:
```yaml
version: 1.3.2+72
```

### `lib/ui.dart`

**Patch 2: Version (shown on the About page): REPLACE**

FIND:
```dart
const String kVersion = '1.3.1';
```
REPLACE WITH:
```dart
const String kVersion = '1.3.2';
```

**Patch 3: Form dialog can start with values (used by the edit buttons): REPLACE**

FIND:
```dart
Future<List<String>?> form(BuildContext c, String title, List<String> labels,
    {Set<int> numeric = const {}}) {
  final ctrls = [for (final _ in labels) TextEditingController()];
```
REPLACE WITH:
```dart
Future<List<String>?> form(BuildContext c, String title, List<String> labels,
    {Set<int> numeric = const {}, List<String>? initial}) {
  final ctrls = [
    for (var i = 0; i < labels.length; i++)
      TextEditingController(text: initial != null && i < initial.length ? initial[i] : '')
  ];
```

**Patch 4: Delete confirmation dialog (new helper): ADD ABOVE**

FIND:
```dart
/// Back-button handling for the 3 main menus.
```
ADD right before it:
```dart
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
```

### `lib/data.dart`

**Patch 5: New edit / delete functions in AppState: ADD ABOVE**

FIND:
```dart
  // ---- payments (feeds the admin's purchases screen)
```
ADD right before it:
```dart
  // ---- 1.3.2: edit / delete
  /// Edit name, breed and (for a flock) the number of heads.
  void editAnimal(Animal a, String name, String breed, int count) {
    a.name = name;
    a.breed = breed;
    if (a.flock) a.count = count < 1 ? 1 : count;
    _u('animals', a.id, {'name': name, 'breed': breed, 'heads': a.flock ? a.count : 1});
    notifyListeners();
  }

  /// Delete the animal with its schedule, records and expenses. Returns false if it could not be deleted.
  Future<bool> deleteAnimal(Animal a) async {
    try {
      await repo.remove('animals', 'id', a.id);
    } catch (e) {
      return false;
    }
    // the phone's SQLite has no cascade, so clean up the children too (Supabase already did it)
    for (final t in ['schedules', 'records', 'expenses']) {
      try {
        await repo.remove(t, 'animal_id', a.id);
      } catch (e) {}
    }
    _animals.removeWhere((x) => x.id == a.id);
    notifyListeners();
    return true;
  }

  /// A farmer may edit only his own notes (not notes written by a vet, and not the automatic "Marked done" note).
  bool canEditRec(Rec r) => r.by == 'Raiser' && r.note != 'Marked done by raiser.';

  void editRecord(Rec r, String title, String note) {
    r.title = title;
    r.note = note;
    _u('records', r.id, {'title': title, 'note': note});
    notifyListeners();
  }

  void editExpense(Exp e, String item, double amount) {
    e.item = item;
    e.amount = amount;
    _u('expenses', e.id, {'item': item, 'amount': amount});
    notifyListeners();
  }

  void deleteExpense(Animal a, Exp e) {
    a.exps.removeWhere((x) => x.id == e.id);
    unawaited(repo.remove('expenses', 'id', e.id).catchError((Object err) {}));
    notifyListeners();
  }

  /// Shop owner edits a product (a new photo is optional; without one the old picture stays).
  void editProduct(Product p,
      {required String name, required double price, required int stock, required String cat, DateTime? expiry, String? photo}) {
    p.name = name;
    p.price = price;
    p.stock = stock < 0 ? 0 : stock;
    p.cat = cat;
    p.expiry = expiry;
    if (photo != null) p.img = photo;
    _u('products', p.id, {
      'name': name, 'price': price, 'stock': p.stock, 'cat': cat,
      'expiry': expiry == null ? null : _ms(expiry),
      if (photo != null) 'img': photo,
    });
    notifyListeners();
  }
```

### `lib/raiser.dart`

**Patch 6: Animal page: three-dot menu (edit / delete animal): REPLACE**

FIND:
```dart
                  tabs: [Tab(text: 'Schedule'), Tab(text: 'Records'), Tab(text: 'Expenses')])),
```
REPLACE WITH:
```dart
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
```

**Patch 7: Animal page: the two functions the menu calls (inside class AnimalPage, above _list): ADD ABOVE**

FIND:
```dart
  Widget _list(String btn, List<Widget> items, VoidCallback add) => ListView(
```
ADD right before it:
```dart
  Future<void> _edit(BuildContext c) async {
    final v = await form(c, 'Edit animal', ['Name / tag', 'Breed', if (a.flock) 'Number of heads'],
        numeric: {2}, initial: [a.name, a.breed, if (a.flock) '${a.count}']);
    if (v == null) return;
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
```

**Patch 8: Records tab: edit button on your own notes: ADD BELOW**

FIND:
```dart
                        Expanded(child: Text(r.title, style: h(17))),
                        Text(fmt(r.date), style: const TextStyle(fontSize: 12)),
```
ADD right after it:
```dart
                        if (app.canEditRec(r))
                          IconButton(
                              tooltip: 'Edit note',
                              visualDensity: VisualDensity.compact,
                              onPressed: () async {
                                final v = await form(c, 'Edit note', ['Title', 'Note'], initial: [r.title, r.note]);
                                if (v != null && v[0].isNotEmpty) app.editRecord(r, v[0], v[1]);
                              },
                              icon: Icon(Icons.edit_outlined, size: 20, color: C.brown)),
```

**Patch 9: Expenses tab: edit and delete buttons: ADD BELOW**

FIND:
```dart
                      Text(money(e.amount), style: h(17, C.green)),
```
ADD right after it:
```dart
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
```

### `lib/vet.dart`

**Patch 10: Inventory: tap the product name to edit it: REPLACE**

FIND:
```dart
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: h(16)),
                      Text('${money(p.price)} • ${p.cat}', style: h(14, C.green)),
                      if (p.expiry != null) Text('Expires ${fmt(p.expiry!)}', style: const TextStyle(fontSize: 12)),
                    ])),
```
REPLACE WITH:
```dart
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
```

**Patch 11: Add product dialog: also used for editing (start of the function): REPLACE**

FIND:
```dart
Future<void> addProductDialog(BuildContext c, Store s) async {
  final name = TextEditingController(), price = TextEditingController(), stock = TextEditingController();
  var cat = 'Vaccine';
  DateTime? expiry;
```
REPLACE WITH:
```dart
Future<void> addProductDialog(BuildContext c, Store s, {Product? edit}) async {
  const cats = ['Vaccine', 'Dewormer', 'Supplement', 'Antibiotic', 'Other'];
  final name = TextEditingController(text: edit?.name ?? ''),
      price = TextEditingController(text: edit == null ? '' : edit.price.toString()),
      stock = TextEditingController(text: edit == null ? '' : '${edit.stock}');
  var cat = edit != null && cats.contains(edit.cat) ? edit.cat : (edit == null ? 'Vaccine' : 'Other');
  DateTime? expiry = edit?.expiry;
```

**Patch 12: Add product dialog: title: REPLACE**

FIND:
```dart
        title: Text('Add product', style: h(20)),
```
REPLACE WITH:
```dart
        title: Text(edit == null ? 'Add product' : 'Edit product', style: h(20)),
```

**Patch 13: Add product dialog: category list uses the shared list: REPLACE**

FIND:
```dart
                  for (final k in ['Vaccine', 'Dewormer', 'Supplement', 'Antibiotic', 'Other'])
```
REPLACE WITH:
```dart
                  for (final k in cats)
```

**Patch 14: Add product dialog: photo button text and preview: REPLACE**

FIND:
```dart
              label: Text(up ? 'Uploading…' : photo == null ? 'Photo (optional)' : 'Photo added, tap to change'),
            ),
            if (photo != null) Pic(photo, w: 80, h: 80, r: 12),
```
REPLACE WITH:
```dart
              label: Text(up
                  ? 'Uploading…'
                  : photo != null
                      ? 'Photo added, tap to change'
                      : edit == null
                          ? 'Photo (optional)'
                          : 'Change photo'),
            ),
            if (photo != null || edit?.img != null) Pic(photo ?? edit?.img, w: 80, h: 80, r: 12),
```

**Patch 15: Add product dialog: Save button saves an edit or a new product (end of the function): REPLACE**

FIND:
```dart
  if (ok != true || name.text.trim().isEmpty) return;
  app.addProduct(s, name.text.trim(), double.tryParse(price.text.trim()) ?? 0, int.tryParse(stock.text.trim()) ?? 0,
      cat: cat, expiry: expiry, photo: photo);
```
REPLACE WITH:
```dart
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
```

### `lib/auth.dart`

**Patch 16: Login: remove the autofill list under the username box: DELETE**

FIND and delete:
```dart
                      // autofill options (the 3 test accounts) appear while the username box is focused
                      if (focus.hasFocus && _options.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(rPill)),
                          child: Column(children: [
                            for (final a in _options)
                              ListTile(
                                dense: true,
                                leading: Icon(_ic(a.role), color: C.green),
                                title: Text(a.user, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(a.label),
                                onTap: () {
                                  setState(() {
                                    user.text = a.user;
                                    pass.text = kPassword;
                                    err = null;
                                  });
                                  focus.unfocus();
                                },
                              ),
                          ]),
                        ),
```

**Patch 17: Login: username field no longer needs the focus node: REPLACE**

FIND:
```dart
                        controller: user,
                        focusNode: focus,
```
REPLACE WITH:
```dart
                        controller: user,
```

**Patch 18: Login: clean up unused code (state class start): REPLACE**

FIND:
```dart
  final focus = FocusNode();
  bool hide = true, busy = false;
  String? err;

  @override
  void initState() {
    super.initState();
    focus.addListener(() => setState(() {}));
    user.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  List<Account> get _options {
    final t = user.text.trim().toLowerCase();
    return accounts.where((a) => t.isEmpty || a.user.contains(t)).toList();
  }
```
REPLACE WITH:
```dart
  bool hide = true, busy = false;
  String? err;
```

**Patch 19: Login: delete the unused icon helper: REPLACE**

FIND:
```dart
  IconData _ic(Role r) => switch (r) {
        Role.raiser => Icons.agriculture,
        Role.vet => Icons.medical_services_outlined,
        Role.store => Icons.storefront_outlined,
        Role.admin => Icons.admin_panel_settings_outlined,
      };

  @override
  Widget build(BuildContext context) => rx((c) => Scaffold(
        backgroundColor: C.surface,
```
REPLACE WITH:
```dart
  @override
  Widget build(BuildContext context) => rx((c) => Scaffold(
        backgroundColor: C.surface,
```

## Step 2: build

```
flutter pub get
flutter run
```

If the build shows an error, send me the exact error text and file name.

## Step 3: test checklist

**Login**
- [ ] Tapping the username box shows no list. Typing `ruben.farmer` and the password from `accounts.md` logs in.
- [ ] Settings > About shows Version 1.3.2.

**Farmer: animals**
- [ ] Animal page: three-dot menu shows Edit animal and Delete animal.
- [ ] Edit changes the name and breed (flock: the head count) and the page title and list update.
- [ ] Delete asks first. After Delete the animal is gone from Animals and Home reminders, and you return to the list.

**Farmer: records and expenses**
- [ ] A note you added has a pencil icon and can be edited. Vet notes and the automatic "Marked done" note have none. No record can be deleted.
- [ ] Expenses: pencil edits item and amount, the Total spent updates. Trash asks first, then removes it and lowers the total.

**Shop owner**
- [ ] Tap a product name (pencil beside it): the Edit product dialog opens already filled in.
- [ ] Change the price, stock, category, expiry or photo; Save shows "Product updated" and the list updates. Farmers see the new price in Find > Medicine.
- [ ] A product with an old or unusual category opens without a crash (it shows "Other").

**Two phones (Supabase mode)**
- [ ] Edit a note on phone A, pull to refresh on phone B: the edit stays (it does not revert after a refresh).
- [ ] Delete an animal on phone A: it disappears on phone B after a refresh.

## Notes and assumptions

- Your answer "No don't delete health records" was taken as: records can be edited, never deleted. Expenses were not mentioned, so I made them editable and deletable like animals.
- Only the farmer's own notes can be edited, so a vet's visit note cannot be changed by the farmer.
- Deleting an animal keeps its past bookings; they only lose the link to the animal.
- Editing a product does not send a notification to farmers.
- Not compiled here (no Flutter in my workspace); every Dart file was syntax-checked only.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'db.dart';

export 'db.dart' show kPassword;

// ---------------------------------------------------------------- models
enum Role { raiser, vet, store }

enum Species { hog, poultry, goat }

enum BStatus { pending, accepted, declined, cancelled, completed }

extension SpeciesX on Species {
  String get label => switch (this) {
        Species.hog => 'Hog',
        Species.poultry => 'Poultry',
        Species.goat => 'Goat'
      };
  IconData get icon => this == Species.poultry ? Icons.egg_alt : Icons.pets;
  // photos used by the sample animals
  String get photo => switch (this) {
        Species.hog => 'assets/img/pig.jpg',
        Species.poultry => 'assets/img/chickens.jpg',
        Species.goat => 'assets/img/goat.jpg',
      };
  // newer photos used for animals added by users
  String get newPhoto => switch (this) {
        Species.hog => 'assets/img/pig_n.jpg',
        Species.poultry => 'assets/img/chicken_n.jpg',
        Species.goat => 'assets/img/goat_n.jpg',
      };

  /// Sample schedule template: label -> days from today (demo data only).
  Map<String, int> get defaults => switch (this) {
        Species.hog => {'Iron injection': 3, 'Hog cholera vaccine': 14, 'Deworming': 30},
        Species.poultry => {'Newcastle disease vaccine': 7, 'Gumboro vaccine': 14, 'Deworming': 45},
        Species.goat => {'Deworming': 10, 'CD&T vaccine': 21, 'Hoof check': 40},
      };
}

/// Picture for a reminder / schedule item (vaccine, dewormer...).
String? remImg(String label) {
  final s = label.toLowerCase();
  if (s.contains('vaccin')) return 'assets/img/vaccine.jpg';
  if (s.contains('worm')) return 'assets/img/worm1.jpg';
  if (s.contains('iron')) return 'assets/img/vaccine2.jpg';
  return null;
}

/// The 3 test accounts (shown as autofill options on the login screen).
class Account {
  final String user, label;
  final Role role;
  const Account(this.user, this.label, this.role);
}

const accounts = [
  Account('ruben.farmer', 'Farmer', Role.raiser),
  Account('maria.vet', 'Veterinarian', Role.vet),
  Account('bunawan.store', 'Store owner', Role.store),
];

// photos handed to NEW vets / stores / products (from the Figma design)
const _vetPool = ['assets/img/vet_n0.jpg', 'assets/img/vet_n1.jpg', 'assets/img/vet_n2.jpg', 'assets/img/vet_n3.jpg'];
const _storePool = ['assets/img/store_n0.jpg', 'assets/img/store_n1.jpg', 'assets/img/store_n2.jpg', 'assets/img/store_n3.jpg'];
const _prodPool = [
  'assets/img/prod_n0.jpg', 'assets/img/prod_n1.jpg', 'assets/img/prod_n2.jpg',
  'assets/img/prod_n3.jpg', 'assets/img/prod_n4.jpg', 'assets/img/prod_n5.jpg'
];

DateTime _dt(Object? ms) => DateTime.fromMillisecondsSinceEpoch((ms as num).toInt());
int _ms(DateTime d) => d.millisecondsSinceEpoch;
double _d(Object? v) => (v as num).toDouble();
int _i(Object? v) => (v as num).toInt();
bool _b(Object? v) => _i(v) == 1;

class User {
  final int id;
  String username, fullName, phone, place, pass, salt;
  String? display;
  Role role;
  User(this.id, this.username, this.fullName, this.phone, this.place, this.role, this.pass, this.salt,
      this.display);
  String get greet => display ?? fullName.split(' ').first;
}

class Sched {
  final int id;
  String label;
  DateTime date;
  bool done;
  Sched(this.id, this.label, this.date, [this.done = false]);
}

class Rec {
  final int id;
  DateTime date;
  String title, note, by;
  Rec(this.id, this.date, this.title, this.note, this.by);
}

class Exp {
  final int id;
  DateTime date;
  String item;
  double amount;
  Exp(this.id, this.date, this.item, this.amount);
}

class Animal {
  final int id, ownerId;
  String name, breed;
  Species sp;
  bool flock;
  int count;
  String? photo;
  List<Sched> sched;
  List<Rec> recs;
  List<Exp> exps;
  Animal({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.sp,
    this.breed = '',
    this.flock = false,
    this.count = 1,
    this.photo,
    List<Sched>? sched,
    List<Rec>? recs,
    List<Exp>? exps,
  })  : sched = sched ?? [],
        recs = recs ?? [],
        exps = exps ?? [];
  double get spent => exps.fold(0.0, (s, e) => s + e.amount);
  String get sub => flock ? '${sp.label} flock • $count heads' : '${sp.label} • $breed';
}

class Vet {
  final int id;
  final int? userId;
  String name, kind, about, photo, license;
  double km, fee, rating;
  List<String> services;
  DateTime planUntil;
  Vet(this.id, this.userId, this.name, this.kind, this.about, this.photo, this.license, this.km, this.fee,
      this.rating, this.services, this.planUntil);
  String get ratingText => rating <= 0 ? 'New' : rating.toStringAsFixed(1);
}

class Product {
  final int id, storeId;
  String name, cat;
  String? img;
  double price;
  int stock;
  Product(this.id, this.storeId, this.name, this.cat, this.price, this.stock, [this.img]);
}

class Store {
  final int id;
  final int? userId;
  String name, address, photo;
  double km;
  List<Product> products;
  DateTime planUntil;
  Store(this.id, this.userId, this.name, this.address, this.photo, this.km, this.products, this.planUntil);
}

class Booking {
  final int id, raiserId;
  final String raiser, animalName, reason;
  final Vet vet;
  final Animal? animal;
  final double fee; // visit fee
  final bool urgent;
  DateTime date;
  String time;
  BStatus status;
  bool rConfirm, vConfirm;
  String? method;
  int? rating;
  Booking({
    required this.id,
    required this.raiserId,
    required this.raiser,
    required this.vet,
    required this.animalName,
    required this.reason,
    required this.date,
    required this.time,
    required this.fee,
    this.animal,
    this.urgent = false,
    this.status = BStatus.pending,
    this.rConfirm = false,
    this.vConfirm = false,
    this.method,
    this.rating,
  });
  bool get free => false;
  bool get premium => false;
  double get raiserPays => urgent ? 0 : fee + fee * AppState.rate / 2;
  double get vetGets => fee - fee * AppState.rate / 2;
}

class Reservation {
  final int id, raiserId;
  final String raiserName, method;
  final Store store;
  final Product product;
  final int qty;
  bool pickedUp;
  Reservation(this.id, this.raiserId, this.raiserName, this.store, this.product, this.qty, this.method,
      {this.pickedUp = false});
  double get total => product.price * qty;
}

class Due {
  final Animal a;
  final Sched s;
  Due(this.a, this.s);
}

// ---------------------------------------------------------------- state (SQLite-backed)
class AppState extends ChangeNotifier {
  static const rate = 0.05; // 5% per completed booking, split raiser / vet
  static const planPrice = 39.0; // vet + store monthly subscription
  static const premDiscount = 0.10; // (premium removed from the farmer menu – kept for BookPage maths)

  late Database db;
  bool dark = false;
  Role? role;
  User? user;
  final DateTime now = DateTime.now();

  List<User> _users = [];
  List<Vet> vets = [];
  List<Store> stores = [];
  List<Animal> _animals = [];
  List<Booking> _bookings = [];
  List<Reservation> _reservations = [];

  // ---- startup
  Future<void> init() async {
    db = await openAppDb();
    dark = (await _get('dark')) == '1';
    await _loadAll();
    final sid = await _get('session');
    if (sid != null) {
      for (final u in _users) {
        if (u.id == int.tryParse(sid)) {
          user = u;
          role = u.role;
        }
      }
    }
  }

  Future<String?> _get(String k) async {
    final r = await db.query('settings', where: 'k=?', whereArgs: [k]);
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  Future<void> _set(String k, String v) =>
      db.insert('settings', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);

  void _u(String table, int id, Map<String, Object?> values) =>
      unawaited(db.update(table, values, where: 'id=?', whereArgs: [id]));

  Future<void> _loadAll() async {
    _users = (await db.query('users'))
        .map((r) => User(_i(r['id']), r['username'] as String, r['full_name'] as String,
            (r['phone'] ?? '') as String, (r['place'] ?? '') as String,
            Role.values.byName(r['role'] as String), r['pass'] as String, r['salt'] as String,
            r['display'] as String?))
        .toList();
    vets = (await db.query('vets'))
        .map((r) => Vet(_i(r['id']), r['user_id'] == null ? null : _i(r['user_id']), r['name'] as String,
            r['kind'] as String, r['about'] as String, r['photo'] as String, (r['license'] ?? '') as String,
            _d(r['km']), _d(r['fee']), _d(r['rating']),
            (r['services'] as String).split(',').where((s) => s.isNotEmpty).toList(), _dt(r['plan_until'])))
        .toList();
    final prods = await db.query('products');
    stores = (await db.query('stores'))
        .map((r) => Store(
            _i(r['id']),
            r['user_id'] == null ? null : _i(r['user_id']),
            r['name'] as String,
            r['address'] as String,
            r['photo'] as String,
            _d(r['km']),
            prods
                .where((p) => _i(p['store_id']) == _i(r['id']))
                .map((p) => Product(_i(p['id']), _i(p['store_id']), p['name'] as String, p['cat'] as String,
                    _d(p['price']), _i(p['stock']), p['img'] as String?))
                .toList(),
            _dt(r['plan_until'])))
        .toList();
    final sch = await db.query('schedules');
    final rec = await db.query('records', orderBy: 'id DESC');
    final exp = await db.query('expenses', orderBy: 'id DESC');
    _animals = (await db.query('animals')).map((r) {
      final id = _i(r['id']);
      return Animal(
        id: id,
        ownerId: _i(r['owner_id']),
        name: r['name'] as String,
        sp: Species.values.byName(r['species'] as String),
        breed: (r['breed'] ?? '') as String,
        flock: _b(r['flock']),
        count: _i(r['heads']),
        photo: r['photo'] as String?,
        sched: sch.where((s) => _i(s['animal_id']) == id).map((s) => Sched(_i(s['id']), s['label'] as String, _dt(s['due']), _b(s['done']))).toList(),
        recs: rec.where((s) => _i(s['animal_id']) == id).map((s) => Rec(_i(s['id']), _dt(s['at']), s['title'] as String, (s['note'] ?? '') as String, (s['author'] ?? '') as String)).toList(),
        exps: exp.where((s) => _i(s['animal_id']) == id).map((s) => Exp(_i(s['id']), _dt(s['at']), s['item'] as String, _d(s['amount']))).toList(),
      );
    }).toList();
    _bookings = [];
    for (final r in await db.query('bookings', orderBy: 'id DESC')) {
      final vet = vets.firstWhere((v) => v.id == _i(r['vet_id']));
      Animal? an;
      for (final a in _animals) {
        if (r['animal_id'] != null && a.id == _i(r['animal_id'])) an = a;
      }
      _bookings.add(Booking(
        id: _i(r['id']),
        raiserId: _i(r['raiser_id']),
        raiser: r['raiser_name'] as String,
        vet: vet,
        animal: an,
        animalName: r['animal_name'] as String,
        reason: r['reason'] as String,
        date: _dt(r['day']),
        time: r['slot'] as String,
        fee: _d(r['fee']),
        urgent: _b(r['urgent']),
        status: BStatus.values.byName(r['status'] as String),
        rConfirm: _b(r['r_confirm']),
        vConfirm: _b(r['v_confirm']),
        method: r['method'] as String?,
        rating: r['rating'] == null ? null : _i(r['rating']),
      ));
    }
    _reservations = [];
    for (final r in await db.query('reservations', orderBy: 'id DESC')) {
      final st = stores.firstWhere((s) => s.id == _i(r['store_id']));
      final pr = st.products.firstWhere((p) => p.id == _i(r['product_id']));
      _reservations.add(Reservation(_i(r['id']), _i(r['raiser_id']), r['raiser_name'] as String, st, pr,
          _i(r['qty']), r['method'] as String,
          pickedUp: _b(r['picked_up'])));
    }
  }

  // ---- theme
  Future<void> setDark(bool v) async {
    dark = v;
    notifyListeners();
    await _set('dark', v ? '1' : '0');
  }

  // ---- accounts
  Future<String?> login(String username, String password) async {
    final u = username.trim().toLowerCase();
    User? found;
    for (final x in _users) {
      if (x.username == u) found = x;
    }
    if (found == null || hashPw(password, found.salt) != found.pass) {
      return 'Wrong username or password. Please try again.';
    }
    await _signIn(found);
    return null;
  }

  Future<void> _signIn(User u) async {
    user = u;
    role = u.role;
    await _set('session', '${u.id}');
    notifyListeners();
  }

  void signOut() {
    user = null;
    role = null;
    notifyListeners();
    unawaited(db.delete('settings', where: 'k=?', whereArgs: ['session']));
  }

  bool usernameTaken(String u) => _users.any((x) => x.username == u.trim().toLowerCase());

  /// Creates the account (+ vet / store profile) and signs the user in.
  Future<String?> register({
    required Role role,
    required String fullName,
    required String phone,
    required String username,
    required String password,
    String place = '',
    String kind = 'Veterinarian',
    String license = '',
    double fee = 350,
    String storeName = '',
    String storeAddress = '',
  }) async {
    final uname = username.trim().toLowerCase();
    if (usernameTaken(uname)) return 'That username is already taken.';
    final salt = newSalt();
    final hash = hashPw(password, salt);
    String? display;
    if (role == Role.vet) display = '${kind == 'Veterinarian' ? 'Dr.' : 'Tech.'} ${fullName.trim()}';
    if (role == Role.store) display = storeName.trim();
    final where = role == Role.store ? storeAddress.trim() : place.trim();
    final uid = await db.insert('users', {
      'username': uname, 'full_name': fullName.trim(), 'display': display, 'phone': phone,
      'place': where, 'role': role.name, 'pass': hash, 'salt': salt, 'created': _ms(now),
    });
    final u = User(uid, uname, fullName.trim(), phone, where, role, hash, salt, display);
    _users.add(u);
    final plan = now.add(const Duration(days: 30));
    final km = 1.0 + ((vets.length + stores.length) * 7 % 45) / 10;
    if (role == Role.vet) {
      final photo = _vetPool[vets.length % _vetPool.length];
      final services = kind == 'Veterinarian' ? 'Farm visit,Vaccination,Check-up' : 'Vaccination,Deworming,Basic care';
      const about = 'New AniCare provider in Bunawan.';
      final vid = await db.insert('vets', {
        'user_id': uid, 'name': display, 'kind': kind, 'about': about, 'photo': photo,
        'license': license.trim(), 'km': km, 'fee': fee, 'rating': 0.0, 'services': services,
        'plan_until': _ms(plan),
      });
      vets.add(Vet(vid, uid, display!, kind, about, photo, license.trim(), km, fee, 0, services.split(','), plan));
    } else if (role == Role.store) {
      final photo = _storePool[stores.length % _storePool.length];
      final sid = await db.insert('stores', {
        'user_id': uid, 'name': storeName.trim(), 'address': storeAddress.trim(), 'photo': photo,
        'km': km, 'plan_until': _ms(plan),
      });
      stores.add(Store(sid, uid, storeName.trim(), storeAddress.trim(), photo, km, [], plan));
    }
    await _signIn(u);
    return null;
  }

  // ---- scoped views of the data (each account only sees its own)
  Vet get me => vets.firstWhere((v) => v.userId == user?.id, orElse: () => vets.first);
  Store get myStore => stores.firstWhere((s) => s.userId == user?.id, orElse: () => stores.first);
  List<Animal> get animals => _animals.where((a) => a.ownerId == user?.id).toList();
  List<Booking> get bookings => _bookings.where((b) => b.raiserId == user?.id).toList();
  List<Booking> get vetBookings => _bookings.where((b) => b.vet.id == me.id).toList();
  List<Reservation> get reservations => _reservations.where((r) => r.raiserId == user?.id).toList();
  List<Reservation> get storeReservations => _reservations.where((r) => r.store.id == myStore.id).toList();

  // kept so the booking screen compiles (premium was removed from the farmer menu)
  bool get premium => false;
  int get freeChecks => 0;

  // ---- raiser: animals
  int get totalHeads => animals.fold(0, (s, a) => s + a.count);
  double get totalSpent => animals.fold(0.0, (s, a) => s + a.spent);
  List<Due> get upcoming {
    final l = [for (final a in animals) for (final s in a.sched) if (!s.done) Due(a, s)];
    l.sort((x, y) => x.s.date.compareTo(y.s.date));
    return l;
  }

  DateTime _day(int days) => DateTime(now.year, now.month, now.day).add(Duration(days: days));

  Future<void> addAnimal(String name, Species sp, String breed, bool flock, int count) async {
    final photo = sp.newPhoto;
    final id = await db.insert('animals', {
      'owner_id': user!.id, 'name': name, 'breed': breed, 'species': sp.name,
      'flock': flock ? 1 : 0, 'heads': flock ? count : 1, 'photo': photo,
    });
    final a = Animal(id: id, ownerId: user!.id, name: name, sp: sp, breed: breed, flock: flock,
        count: flock ? count : 1, photo: photo);
    for (final e in sp.defaults.entries) {
      final due = _day(e.value);
      final sid = await db.insert('schedules', {'animal_id': id, 'label': e.key, 'due': _ms(due), 'done': 0});
      a.sched.add(Sched(sid, e.key, due));
    }
    _animals.add(a);
    notifyListeners();
  }

  Future<void> markDone(Animal a, Sched s) async {
    s.done = true;
    _u('schedules', s.id, {'done': 1});
    await addRecord(a, Rec(0, now, s.label, 'Marked done by raiser.', 'Raiser'));
  }

  Future<void> addRecord(Animal a, Rec r) async {
    final id = await db.insert('records',
        {'animal_id': a.id, 'at': _ms(r.date), 'title': r.title, 'note': r.note, 'author': r.by});
    a.recs.insert(0, Rec(id, r.date, r.title, r.note, r.by));
    notifyListeners();
  }

  Future<void> addExpense(Animal a, Exp e) async {
    final id = await db.insert(
        'expenses', {'animal_id': a.id, 'at': _ms(e.date), 'item': e.item, 'amount': e.amount});
    a.exps.insert(0, Exp(id, e.date, e.item, e.amount));
    notifyListeners();
  }

  // ---- bookings
  Future<void> book(Vet v, Animal a, DateTime date, String time, String reason, String method,
      {required double fee, bool free = false, bool urgent = false}) async {
    final r = reason.isEmpty ? 'Check-up' : reason;
    final id = await db.insert('bookings', {
      'raiser_id': user!.id, 'raiser_name': user!.fullName, 'vet_id': v.id, 'animal_id': a.id,
      'animal_name': a.name, 'reason': r, 'day': _ms(date), 'slot': time, 'fee': fee,
      'urgent': urgent ? 1 : 0, 'status': 'pending', 'r_confirm': 0, 'v_confirm': 0, 'method': method,
    });
    _bookings.insert(
        0,
        Booking(id: id, raiserId: user!.id, raiser: user!.fullName, vet: v, animal: a, animalName: a.name,
            reason: r, date: date, time: time, fee: fee, urgent: urgent, method: method));
    notifyListeners();
  }

  void setStatus(Booking b, BStatus s) {
    b.status = s;
    _u('bookings', b.id, {'status': s.name});
    notifyListeners();
  }

  void reschedule(Booking b, DateTime d) {
    b.date = d;
    b.status = BStatus.pending;
    b.rConfirm = b.vConfirm = false;
    _u('bookings', b.id, {'day': _ms(d), 'status': 'pending', 'r_confirm': 0, 'v_confirm': 0});
    notifyListeners();
  }

  /// Booking completes only when BOTH raiser and vet confirm.
  void confirm(Booking b, {required bool byRaiser}) {
    if (byRaiser) {
      b.rConfirm = true;
    } else {
      b.vConfirm = true;
    }
    if (b.rConfirm && b.vConfirm) b.status = BStatus.completed;
    _u('bookings', b.id, {
      'r_confirm': b.rConfirm ? 1 : 0, 'v_confirm': b.vConfirm ? 1 : 0, 'status': b.status.name
    });
    notifyListeners();
  }

  void rateBooking(Booking b, int n) {
    b.rating = n;
    _u('bookings', b.id, {'rating': n});
    notifyListeners();
  }

  double get vetEarnings =>
      vetBookings.where((b) => b.status == BStatus.completed).fold(0.0, (s, b) => s + b.vetGets);

  // ---- stores
  Future<void> reserve(Store s, Product p, int qty, String method) async {
    p.stock -= qty;
    _u('products', p.id, {'stock': p.stock});
    final id = await db.insert('reservations', {
      'raiser_id': user!.id, 'raiser_name': user!.fullName, 'store_id': s.id, 'product_id': p.id,
      'qty': qty, 'method': method, 'picked_up': 0,
    });
    _reservations.insert(0, Reservation(id, user!.id, user!.fullName, s, p, qty, method));
    notifyListeners();
  }

  void pickedUp(Reservation r) {
    r.pickedUp = true;
    _u('reservations', r.id, {'picked_up': 1});
    notifyListeners();
  }

  void stock(Product p, int d) {
    p.stock = (p.stock + d).clamp(0, 9999);
    _u('products', p.id, {'stock': p.stock});
    notifyListeners();
  }

  Future<void> addProduct(Store s, String name, double price, int stock) async {
    final img = _prodPool[s.products.length % _prodPool.length];
    final id = await db.insert('products',
        {'store_id': s.id, 'name': name, 'cat': 'Product', 'price': price, 'stock': stock, 'img': img});
    s.products.add(Product(id, s.id, name, 'Product', price, stock, img));
    notifyListeners();
  }

  // ---- vet / store monthly plan (39/month)
  DateTime get planUntil => role == Role.store ? myStore.planUntil : me.planUntil;
  bool get planActive => planUntil.isAfter(now);
  void payPlan() {
    final base = planActive ? planUntil : now;
    final next = base.add(const Duration(days: 30));
    if (role == Role.store) {
      myStore.planUntil = next;
      _u('stores', myStore.id, {'plan_until': _ms(next)});
    } else {
      me.planUntil = next;
      _u('vets', me.id, {'plan_until': _ms(next)});
    }
    notifyListeners();
  }
}

final app = AppState();

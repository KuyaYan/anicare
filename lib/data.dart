import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'config.dart';
import 'db.dart';
import 'notify.dart';
import 'repo.dart';

export 'db.dart' show kPassword;

// ---------------------------------------------------------------- models
enum Role { raiser, vet, store, admin }

enum Species { hog, poultry, goat }

enum BStatus { unpaid, pending, accepted, declined, cancelled, completed }

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
  Account('admin', 'Admin', Role.admin),
];

/// Password rule: 8-32 characters, a letter, a number, a symbol, no spaces.
class PwCheck {
  final bool len, letter, digit, symbol, noSpace;
  PwCheck(String s)
      : len = s.length >= 8 && s.length <= 32,
        letter = RegExp(r'[A-Za-z]').hasMatch(s),
        digit = RegExp(r'[0-9]').hasMatch(s),
        symbol = RegExp(r'[^A-Za-z0-9\s]').hasMatch(s),
        noSpace = !RegExp(r'\s').hasMatch(s);
  bool get ok => len && letter && digit && symbol && noSpace;
}

const pwRuleText = 'Password needs 8–32 characters with a letter, a number and a symbol, and no spaces.';

/// Admin view: only the end of a name / phone number is shown.
String maskName(String n) {
  final t = n.trim();
  return '*****${t.length <= 5 ? t : t.substring(t.length - 5)}';
}

String maskPhone(String p) {
  final t = p.trim();
  return '*****${t.length <= 4 ? t : t.substring(t.length - 4)}';
}

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
  String? display, authId;
  Role role;
  bool active;
  User(this.id, this.username, this.fullName, this.phone, this.place, this.role, this.pass, this.salt,
      this.display,
      {this.active = true, this.authId});
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
  DateTime? expiry;
  bool available; // false = removed with the trash button (kept for the reservation history)
  Product(this.id, this.storeId, this.name, this.cat, this.price, this.stock,
      [this.img, this.expiry, this.available = true]);
}

class Store {
  final int id;
  final int? userId;
  String name, address, photo;
  double km;
  List<Product> products;
  DateTime planUntil;
  Store(this.id, this.userId, this.name, this.address, this.photo, this.km, this.products, this.planUntil);

  /// products that are still sold (removed ones stay in the database for the history)
  List<Product> get listed => products.where((p) => p.available).toList();
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
  double get raiserPays => urgent ? 0 : fee + fee * AppState.commissionRate / 2;
  double get vetGets => fee - fee * AppState.commissionRate / 2;
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

/// One line of money movement (reservation, booking, subscription or AniCare fee).
class Payment {
  final int id;
  final String kind, payer, payee, item, method, status;
  final double amount;
  final DateTime at;
  final String ref; // GCash reference number typed by the payer
  Payment(this.id, this.kind, this.payer, this.payee, this.item, this.amount, this.method, this.status, this.at,
      [this.ref = '']);
}

/// One entry of the bell list.
class AppNotification {
  final int id;
  final String kind, title, body;
  final String? payload;
  final DateTime at;
  bool read;
  AppNotification(this.id, this.kind, this.title, this.body, this.at, this.read, this.payload);
}

/// A Help & Support ticket (farmer / vet / shop owner -> admin).
class Ticket {
  final int id, userId;
  final String senderName, senderRole, senderPhone, topic, subject, body;
  bool open; // false = resolved
  final DateTime created;
  DateTime updated;
  String reply;
  DateTime? replied;
  bool adminSeen;
  Ticket(this.id, this.userId, this.senderName, this.senderRole, this.senderPhone, this.topic, this.subject,
      this.body, this.open, this.created, this.updated, this.reply, this.replied, this.adminSeen);
  String get roleLabel =>
      switch (senderRole) { 'raiser' => 'Farmer', 'vet' => 'Vet', 'store' => 'Shop owner', _ => senderRole };
}
class Due {
  final Animal a;
  final Sched s;
  Due(this.a, this.s);
}

// ---------------------------------------------------------------- state (SQLite or Supabase)
/// Set in main.dart: called when an account was switched off while it is signed in.
void Function()? onForceLogout;

class AppState extends ChangeNotifier {
  static const commissionRate = 0.05; // 5% per completed booking, split raiser / vet
  static const planPrice = 39.0; // store monthly subscription
  static const premDiscount = 0.10; // (premium removed from the farmer menu – kept for BookPage maths)
  static const lowStock = 10; // admin: warn when a vaccine has fewer than this

  late LocalRepo local; // settings (theme, local session) always live on the phone
  late Repo repo; // the data: local SQLite, or Supabase when config.dart has keys
  bool get remote => repo.remote;
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
  List<Payment> _payments = [];
  List<Ticket> _tickets = [];

  // notifications (bell list + phone notifications)
  List<AppNotification> notes = [];
  int get unread => notes.where((n) => !n.read).length;
  Timer? _pollTimer;
  bool planPrompt = false; // store owner: show the "extend your plan?" question once

  // hidden Debug tab (admin): tap the AniCare logo 5 times
  int debugTaps = 0;
  bool debugUnlocked = false;
  Timer? _tapTimer;
  int get tapsLeft => 5 - debugTaps;

  // ---- startup
  Future<void> init() async {
    local = LocalRepo();
    await local.init();
    dark = (await local.getSetting('dark')) == '1';
    if (kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty) {
      final r = SupabaseRepo();
      await r.init();
      repo = r;
      if (r.hasSession) {
        try {
          await _loadAll();
          _restoreRemoteUser();
          if (user != null) await _afterLogin();
        } catch (_) {}
      }
    } else {
      repo = local;
      await _loadAll();
      final sid = await local.getSetting('session');
      if (sid != null) {
        for (final u in _users) {
          if (u.id == int.tryParse(sid) && u.active) {
            user = u;
            role = u.role;
          }
        }
      }
      if (user != null) await _afterLogin();
    }
  }

  /// Supabase: find the profile of the signed-in auth user.
  String? _restoreRemoteUser() {
    User? found;
    for (final u in _users) {
      if (u.authId != null && u.authId == repo.authId) found = u;
    }
    if (found == null) return 'Account profile not found. Ask the admin.';
    if (!found.active) return 'This account is deactivated. Contact the admin.';
    user = found;
    role = found.role;
    return null;
  }

  void _u(String table, int id, Map<String, Object?> values) =>
      unawaited(repo.update(table, id, values).catchError((Object e) {}));

  void _clearData() {
    _users = [];
    vets = [];
    stores = [];
    _animals = [];
    _bookings = [];
    _reservations = [];
    _payments = [];
    _tickets = [];
  }

  Future<void> _loadAll() async {
    final users = await repo.query('users');
    final vetRows = await repo.query('vets');
    final prods = await repo.query('products');
    final storeRows = await repo.query('stores');
    final sch = await repo.query('schedules');
    final rec = await repo.query('records', orderBy: 'id DESC');
    final exp = await repo.query('expenses', orderBy: 'id DESC');
    final animalRows = await repo.query('animals');
    final bookingRows = await repo.query('bookings', orderBy: 'id DESC');
    final resRows = await repo.query('reservations', orderBy: 'id DESC');
    final payRows = await repo.query('payments', orderBy: 'id DESC');

    _users = users
        .map((r) => User(_i(r['id']), r['username'] as String, r['full_name'] as String,
            (r['phone'] ?? '') as String, (r['place'] ?? '') as String,
            Role.values.byName(r['role'] as String), (r['pass'] ?? '') as String, (r['salt'] ?? '') as String,
            r['display'] as String?,
            active: r['active'] == null ? true : _b(r['active']), authId: r['auth_id'] as String?))
        .toList();
    vets = vetRows
        .map((r) => Vet(_i(r['id']), r['user_id'] == null ? null : _i(r['user_id']), r['name'] as String,
            r['kind'] as String, (r['about'] ?? '') as String, r['photo'] as String, (r['license'] ?? '') as String,
            _d(r['km']), _d(r['fee']), _d(r['rating']),
            ((r['services'] ?? '') as String).split(',').where((s) => s.isNotEmpty).toList(), _dt(r['plan_until'])))
        .toList();
    stores = storeRows
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
                    _d(p['price']), _i(p['stock']), p['img'] as String?,
                    p['expiry'] == null ? null : _dt(p['expiry']),
                    p['available'] == null ? true : _b(p['available'])))
                .toList(),
            _dt(r['plan_until'])))
        .toList();
    _animals = animalRows.map((r) {
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
    for (final r in bookingRows) {
      Vet? vet;
      for (final v in vets) {
        if (v.id == _i(r['vet_id'])) vet = v;
      }
      if (vet == null) continue;
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
    for (final r in resRows) {
      Store? st;
      for (final s in stores) {
        if (s.id == _i(r['store_id'])) st = s;
      }
      if (st == null) continue;
      Product? pr;
      for (final p in st.products) {
        if (p.id == _i(r['product_id'])) pr = p;
      }
      if (pr == null) continue;
      _reservations.add(Reservation(_i(r['id']), _i(r['raiser_id']), r['raiser_name'] as String, st, pr,
          _i(r['qty']), r['method'] as String,
          pickedUp: _b(r['picked_up'])));
    }
    _payments = payRows
        .map((r) => Payment(_i(r['id']), r['kind'] as String, (r['payer'] ?? '') as String,
            (r['payee'] ?? '') as String, (r['item'] ?? '') as String, _d(r['amount']),
            (r['method'] ?? '') as String, (r['status'] ?? '') as String, _dt(r['at']), (r['ref'] ?? '') as String))
        .toList();
    await _loadTickets();
  }

  /// Help & Support tickets (a user gets only his own, the admin gets all: Supabase row-level security).
  Future<void> _loadTickets() async {
    try {
      final rows = await repo.query('tickets', orderBy: 'id DESC');
      _tickets = rows
          .map((r) => Ticket(
              _i(r['id']),
              _i(r['user_id']),
              (r['sender_name'] ?? '') as String,
              (r['sender_role'] ?? '') as String,
              (r['sender_phone'] ?? '') as String,
              (r['topic'] ?? '') as String,
              (r['subject'] ?? '') as String,
              (r['body'] ?? '') as String,
              (r['status'] ?? 'open') == 'open',
              _dt(r['created']),
              _dt(r['updated'] ?? r['created']),
              (r['reply'] ?? '') as String,
              r['replied'] == null ? null : _dt(r['replied']),
              r['admin_seen'] == null ? false : _b(r['admin_seen'])))
          .toList();
    } catch (_) {
      _tickets = [];
    }
  }

  /// Pull-to-refresh: re-read everything (this is how phones sync with Supabase).
  Future<void> refresh() async {
    try {
      await _loadAll();
    } catch (_) {
      return;
    }
    if (user != null) {
      User? u;
      for (final x in _users) {
        if (x.id == user!.id) u = x;
      }
      if (u == null || !u.active) {
        signOut();
        onForceLogout?.call();
        return;
      }
      user = u;
      try {
        await _loadNotes();
        if (role == Role.store) await checkPlanReminder();
      } catch (_) {}
    }
    notifyListeners();
  }

  // ---- theme
  Future<void> setDark(bool v) async {
    dark = v;
    notifyListeners();
    await local.setSetting('dark', v ? '1' : '0');
  }

  // ---- accounts
  static const _deactivated = 'This account is deactivated. Contact the admin.';

  Future<String?> login(String username, String password) async {
    if (remote) {
      final e = await repo.signIn(username, password);
      if (e != null) return e;
      try {
        await _loadAll();
      } catch (_) {
        return 'No internet connection. Please try again.';
      }
      final err = _restoreRemoteUser();
      if (err != null) {
        await repo.signOut();
        _clearData();
        return err;
      }
      await _afterLogin();
      notifyListeners();
      return null;
    }
    final u = username.trim().toLowerCase();
    User? found;
    for (final x in _users) {
      if (x.username == u) found = x;
    }
    if (found == null || hashPw(password, found.salt) != found.pass) {
      return 'Wrong username or password. Please try again.';
    }
    if (!found.active) return _deactivated;
    user = found;
    role = found.role;
    await local.setSetting('session', '${found.id}');
    await _afterLogin();
    notifyListeners();
    return null;
  }

  void signOut() {
    _pollTimer?.cancel();
    _tapTimer?.cancel();
    notes = [];
    debugUnlocked = false; // the Debug tab hides again at logout
    debugTaps = 0;
    planPrompt = false;
    user = null;
    role = null;
    if (remote) {
      unawaited(repo.signOut());
      _clearData();
    } else {
      unawaited(local.delSetting('session'));
    }
    notifyListeners();
  }

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
    if (role == Role.admin) return 'Admin accounts cannot be created here.';
    if (!PwCheck(password).ok) return pwRuleText;
    final uname = username.trim().toLowerCase();
    final salt = newSalt();
    final hash = hashPw(password, salt);
    String? display;
    if (role == Role.vet) display = '${kind == 'Veterinarian' ? 'Dr.' : 'Tech.'} ${fullName.trim()}';
    if (role == Role.store) display = storeName.trim();
    final where = role == Role.store ? storeAddress.trim() : place.trim();
    final values = <String, Object?>{
      'username': uname, 'full_name': fullName.trim(), 'display': display, 'phone': phone,
      'place': where, 'role': role.name, 'active': 1, 'created': _ms(DateTime.now()),
    };
    if (remote) {
      if (await repo.usernameTaken(uname)) return 'That username is already taken.';
      final e = await repo.signUp(uname, password);
      if (e != null) return e;
      values['auth_id'] = repo.authId;
    } else {
      for (final x in _users) {
        if (x.username == uname) return 'That username is already taken.';
      }
      values['pass'] = hash;
      values['salt'] = salt;
    }
    final int uid;
    try {
      uid = await repo.insert('users', values);
    } catch (_) {
      return 'Could not save the account. That username may already be taken.';
    }
    final plan = DateTime.now().add(const Duration(days: 30));
    final km = 1.0 + ((vets.length + stores.length) * 7 % 45) / 10;
    if (role == Role.vet) {
      final photo = _vetPool[vets.length % _vetPool.length];
      final services = kind == 'Veterinarian' ? 'Farm visit,Vaccination,Check-up' : 'Vaccination,Deworming,Basic care';
      await repo.insert('vets', {
        'user_id': uid, 'name': display, 'kind': kind, 'about': 'New AniCare provider in Bunawan.',
        'photo': photo, 'license': license.trim(), 'km': km, 'fee': fee, 'rating': 0.0, 'services': services,
        'plan_until': _ms(plan),
      });
    } else if (role == Role.store) {
      final photo = _storePool[stores.length % _storePool.length];
      await repo.insert('stores', {
        'user_id': uid, 'name': storeName.trim(), 'address': storeAddress.trim(), 'photo': photo,
        'km': km, 'plan_until': _ms(plan),
      });
    }
    await _loadAll();
    User? me2;
    for (final x in _users) {
      if (x.id == uid) me2 = x;
    }
    if (me2 == null) return 'Account created. Please log in.';
    user = me2;
    this.role = me2.role;
    if (!remote) await local.setSetting('session', '$uid');
    await _afterLogin();
    notifyListeners();
    return null;
  }

  // ---- scoped views of the data (each account only sees its own)
  Vet get me => vets.firstWhere((v) => v.userId == user?.id, orElse: () => vets.first);
  Store get myStore => stores.firstWhere((s) => s.userId == user?.id, orElse: () => stores.first);
  List<Animal> get animals => _animals.where((a) => a.ownerId == user?.id).toList();
  List<Booking> get bookings => _bookings.where((b) => b.raiserId == user?.id).toList();
  List<Booking> get vetBookings =>
      _bookings.where((b) => b.vet.id == me.id && b.status != BStatus.unpaid).toList();
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

  Future<void> addAnimal(String name, Species sp, String breed, bool flock, int count, {String? picked}) async {
    final photo = picked ?? sp.newPhoto;
    final id = await repo.insert('animals', {
      'owner_id': user!.id, 'name': name, 'breed': breed, 'species': sp.name,
      'flock': flock ? 1 : 0, 'heads': flock ? count : 1, 'photo': photo,
    });
    final a = Animal(id: id, ownerId: user!.id, name: name, sp: sp, breed: breed, flock: flock,
        count: flock ? count : 1, photo: photo);
    for (final e in sp.defaults.entries) {
      final due = _day(e.value);
      final sid = await repo.insert('schedules', {'animal_id': id, 'label': e.key, 'due': _ms(due), 'done': 0});
      a.sched.add(Sched(sid, e.key, due));
    }
    _animals.add(a);
    notifyListeners();
  }

  // ---- photos (gallery -> Supabase Storage, or the phone in offline mode)
  Future<String> savePhoto(Uint8List bytes) => repo.uploadPhoto(bytes);

  void setAnimalPhoto(Animal a, String photo) {
    a.photo = photo;
    _u('animals', a.id, {'photo': photo});
    notifyListeners();
  }

  /// Vet = profile photo, shop owner = shop photo.
  void setMyPhoto(String photo) {
    if (role == Role.vet) {
      me.photo = photo;
      _u('vets', me.id, {'photo': photo});
    } else if (role == Role.store) {
      myStore.photo = photo;
      _u('stores', myStore.id, {'photo': photo});
    }
    notifyListeners();
  }
  Future<void> markDone(Animal a, Sched s) async {
    s.done = true;
    _u('schedules', s.id, {'done': 1});
    await addRecord(a, Rec(0, DateTime.now(), s.label, 'Marked done by raiser.', 'Raiser'));
  }

  /// Undo: the check mark goes back to "not done" and the "Marked done by raiser" note is removed.
  Future<void> unmarkDone(Animal a, Sched s) async {
    s.done = false;
    _u('schedules', s.id, {'done': 0});
    final i = a.recs.indexWhere((r) => r.title == s.label && r.note == 'Marked done by raiser.');
    if (i >= 0) {
      final r = a.recs.removeAt(i);
      unawaited(repo.remove('records', 'id', r.id).catchError((Object e) {}));
    }
    notifyListeners();
  }

  Future<void> addRecord(Animal a, Rec r) async {
    final id = await repo.insert('records',
        {'animal_id': a.id, 'at': _ms(r.date), 'title': r.title, 'note': r.note, 'author': r.by});
    a.recs.insert(0, Rec(id, r.date, r.title, r.note, r.by));
    notifyListeners();
  }

  Future<void> addExpense(Animal a, Exp e) async {
    final id = await repo.insert(
        'expenses', {'animal_id': a.id, 'at': _ms(e.date), 'item': e.item, 'amount': e.amount});
    a.exps.insert(0, Exp(id, e.date, e.item, e.amount));
    notifyListeners();
  }

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
      } catch (e) {
        // Supabase deletes the children itself; local cleanup is best-effort.
      }
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
  // ---- payments (feeds the admin's purchases screen)
  Future<void> _recordPayment(String kind, int ref, String payer, String payee, String item, double amount,
      String method, String status,
      {int? payerId, int? payeeId, String? payRef}) async {
    try {
      final at = DateTime.now();
      final id = await repo.insert('payments', {
        'kind': kind, 'ref_id': ref, 'payer': payer, 'payee': payee, 'item': item, 'amount': amount,
        'method': method, 'status': status, 'at': _ms(at), 'payer_id': payerId, 'payee_id': payeeId,
        'ref': payRef,
      });
      _payments.insert(0, Payment(id, kind, payer, payee, item, amount, method, status, at, payRef ?? ''));
    } catch (_) {}
  }

  // ---- bookings
  Future<void> book(Vet v, Animal a, DateTime date, String time, String reason, String method,
      {required double fee, bool free = false, bool urgent = false, String? ref}) async {
    final r = reason.isEmpty ? 'Check-up' : reason;
    final id = await repo.insert('bookings', {
      'raiser_id': user!.id, 'raiser_name': user!.fullName, 'vet_id': v.id, 'animal_id': a.id,
      'animal_name': a.name, 'reason': r, 'day': _ms(date), 'slot': time, 'fee': fee,
      'urgent': urgent ? 1 : 0, 'status': 'pending', 'r_confirm': 0, 'v_confirm': 0, 'method': method,
    });
    final b = Booking(id: id, raiserId: user!.id, raiser: user!.fullName, vet: v, animal: a, animalName: a.name,
        reason: r, date: date, time: time, fee: fee, urgent: urgent, method: method);
    _bookings.insert(0, b);
    if (!urgent && fee > 0) {
      await _recordPayment('booking', id, user!.fullName, v.name, r, b.raiserPays, method, 'held',
          payerId: user!.id, payeeId: v.userId, payRef: ref);
    }
    await _notifyLocal(v.userId, 'booking_paid', urgent ? 'Emergency request' : 'New paid booking',
        '${user!.fullName} booked ${v.name} • $r', payload: 'bell');
    if (!urgent && fee > 0) await _payAlerts('a vet booking', b.raiserPays, ref ?? '-');
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
    final was = b.status;
    if (byRaiser) {
      b.rConfirm = true;
    } else {
      b.vConfirm = true;
    }
    if (b.rConfirm && b.vConfirm) b.status = BStatus.completed;
    _u('bookings', b.id, {
      'r_confirm': b.rConfirm ? 1 : 0, 'v_confirm': b.vConfirm ? 1 : 0, 'status': b.status.name
    });
    if (was != BStatus.completed && b.status == BStatus.completed && b.fee > 0) {
      // AniCare's 5% fee (2.5% from each side) is booked when the visit is completed
      // AniCare's 5% (2.5% from each side) goes to the admin; the vet's share is only recorded (no real payout)
      unawaited(_recordPayment('fee', b.id, 'Raiser & vet (2.5% each)', 'AniCare', 'Booking fee (5%)',
          b.fee * commissionRate, b.method ?? '', 'paid'));
      unawaited(_recordPayment('payout', b.id, 'AniCare', b.vet.name, 'Vet share (recorded, not paid out)',
          b.vetGets, b.method ?? '', 'owed', payeeId: b.vet.userId));
      for (final u in _users) {
        if (u.role == Role.admin) {
          unawaited(_notifyLocal(u.id, 'fee', 'AniCare fee recorded', '${money0(b.fee * commissionRate)} (5%) from a completed booking.'));
        }
      }
    }
    notifyListeners();
  }

  void rate(Booking b, int n) {
    b.rating = n;
    _u('bookings', b.id, {'rating': n});
    notifyListeners();
  }

  double get vetEarnings =>
      vetBookings.where((b) => b.status == BStatus.completed).fold(0.0, (s, b) => s + b.vetGets);

  // ---- stores
  Future<void> reserve(Store s, Product p, int qty, String method, {String? ref}) async {
    p.stock -= qty;
    unawaited(repo.adjustStock(p.id, -qty).catchError((Object e) {}));
    final id = await repo.insert('reservations', {
      'raiser_id': user!.id, 'raiser_name': user!.fullName, 'store_id': s.id, 'product_id': p.id,
      'qty': qty, 'method': method, 'picked_up': 0,
    });
    _reservations.insert(0, Reservation(id, user!.id, user!.fullName, s, p, qty, method));
    await _recordPayment('reservation', id, user!.fullName, s.name, '${p.name} × $qty', p.price * qty, method, 'paid',
        payerId: user!.id, payeeId: s.userId, payRef: ref);
    await _notifyLocal(s.userId, 'reservation', 'New reservation', '${user!.fullName} reserved ${p.name} × $qty.', payload: 'bell');
    await _payAlerts('${p.name} × $qty', p.price * qty, ref ?? '-');
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

  Future<void> addProduct(Store s, String name, double price, int stock,
      {String cat = 'Other', DateTime? expiry, String? photo}) async {
    final img = photo ?? _prodPool[s.products.length % _prodPool.length];
    final id = await repo.insert('products', {
      'store_id': s.id, 'name': name, 'cat': cat, 'price': price, 'stock': stock, 'img': img,
      'expiry': expiry == null ? null : _ms(expiry),
    });
    s.products.add(Product(id, s.id, name, cat, price, stock, img, expiry));
    for (final u in _users) {
      if (u.role == Role.raiser) {
        unawaited(_notifyLocal(u.id, 'new_product', 'New product available', '$name at ${s.name}.', payload: 'bell'));
      }
    }
    notifyListeners();
  }

  /// Trash button: the product is hidden from the store and tagged "Not available" for farmers.
  /// It is NOT deleted, so old reservations keep their history.
  Future<void> removeProduct(Store s, Product p) async {
    p.available = false;
    _u('products', p.id, {'available': 0});
    for (final u in _users) {
      if (u.role == Role.raiser) {
        unawaited(_notifyLocal(u.id, 'product_removed', 'Product not available',
            '${p.name} at ${s.name} is no longer available.', payload: 'bell'));
      }
    }
    notifyListeners();
  }

  // ---- store monthly plan (39/month)
  DateTime get planUntil => myStore.planUntil;
  bool get planActive => planUntil.isAfter(now);
  Future<void> payPlan(String method, {String? ref}) async {
    final base = planActive ? planUntil : DateTime.now();
    final next = base.add(const Duration(days: 30));
    myStore.planUntil = next;
    _u('stores', myStore.id, {'plan_until': _ms(next)});
    await _recordPayment('subscription', myStore.id, myStore.name, 'AniCare', 'Store plan – 1 month', planPrice, method, 'paid',
        payerId: user?.id, payRef: ref);
    await _notifyLocal(user?.id, 'sub_bought', 'Subscription active', 'Your AniCare Store plan is active until ${_fmtDate(next)}.', payload: 'plan');
    for (final u in _users) {
      if (u.role == Role.admin) {
        unawaited(_notifyLocal(u.id, 'sub_bought', 'Store subscription bought', '${myStore.name} paid ₱${planPrice.toStringAsFixed(0)} for the store plan (GCash ref. ${ref ?? '-'}).'));
      }
    }
    notifyListeners();
  }

  // ================================================================ NOTIFICATIONS
  static String _fmtDate(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String money0(num v) => '₱${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}';

  /// Runs after every login / app start: loads the bell list and starts checking for new alerts.
  // ---- Help & Support
  List<Ticket> get myTickets => _tickets.where((t) => t.userId == user?.id).toList();
  List<Ticket> get allTickets => _tickets;
  int get newTickets => _tickets.where((t) => !t.adminSeen).length; // admin: not opened yet

  /// Farmer / vet / shop owner sends a ticket (max 3 open at the same time).
  Future<String?> sendTicket(String topic, String subject, String body) async {
    final u = user!;
    if (subject.trim().length < 3) return 'Please type a short subject.';
    if (body.trim().length < 10) return 'Please describe the problem (at least 10 characters).';
    if (myTickets.where((t) => t.open).length >= 3) {
      return 'You already have 3 open tickets. Please wait until support resolves one.';
    }
    final at = DateTime.now();
    try {
      final id = await repo.insert('tickets', {
        'user_id': u.id, 'sender_name': u.fullName, 'sender_role': u.role.name, 'sender_phone': u.phone,
        'topic': topic, 'subject': subject.trim(), 'body': body.trim(), 'status': 'open',
        'created': _ms(at), 'updated': _ms(at), 'reply': null, 'replied': null, 'admin_seen': 0,
      });
      final t = Ticket(id, u.id, u.fullName, u.role.name, u.phone, topic, subject.trim(), body.trim(), true, at, at,
          '', null, false);
      _tickets.insert(0, t);
      for (final a in _users) {
        if (a.role == Role.admin) {
          unawaited(_notifyLocal(a.id, 'ticket_new', 'New help request',
              '${u.fullName} (${t.roleLabel}): ${t.subject}', payload: 'bell'));
        }
      }
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().contains('3 open')
          ? 'You already have 3 open tickets. Please wait until support resolves one.'
          : 'Could not send. Check your connection and try again.';
    }
  }

  /// Admin opened the message.
  void ticketSeen(Ticket t) {
    if (t.adminSeen) return;
    t.adminSeen = true;
    _u('tickets', t.id, {'admin_seen': 1});
    notifyListeners();
  }

  Future<bool> replyTicket(Ticket t, String text) async {
    final at = DateTime.now();
    final r = text.trim();
    try {
      await repo.update('tickets', t.id, {'reply': r, 'replied': _ms(at), 'updated': _ms(at), 'admin_seen': 1});
    } catch (_) {
      return false;
    }
    t.reply = r;
    t.replied = at;
    t.updated = at;
    t.adminSeen = true;
    unawaited(_notifyLocal(t.userId, 'ticket_reply', 'Reply from AniCare support', 'Re: ${t.subject} – $r',
        payload: 'bell'));
    notifyListeners();
    return true;
  }

  Future<bool> setTicketOpen(Ticket t, bool open) async {
    final at = DateTime.now();
    try {
      await repo.update('tickets', t.id, {'status': open ? 'open' : 'resolved', 'updated': _ms(at)});
    } catch (_) {
      return false;
    }
    t.open = open;
    t.updated = at;
    unawaited(_notifyLocal(t.userId, open ? 'ticket_reopened' : 'ticket_resolved',
        open ? 'Ticket reopened' : 'Ticket resolved', t.subject, payload: 'bell'));
    notifyListeners();
    return true;
  }

  Future<bool> deleteTicket(Ticket t) async {
    try {
      await repo.remove('tickets', 'id', t.id);
    } catch (_) {
      return false;
    }
    _tickets.remove(t);
    notifyListeners();
    return true;
  }
  Future<void> _afterLogin() async {
    try {
      await _loadNotes();
    } catch (_) {}
    _pollTimer?.cancel();
    if (remote) {
      // other phones create notifications on the server; look for new ones every 20 seconds
      _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
        if (user == null) return;
        try {
          await _loadNotes();
          await _loadTickets();
          notifyListeners();
        } catch (_) {}
      });
    }
    if (role == Role.store) {
      try {
        await checkPlanReminder();
      } catch (_) {}
    }
  }

  Future<void> _loadNotes() async {
    final me2 = user;
    if (me2 == null) {
      notes = [];
      return;
    }
    final rows = await repo.query('notifications', orderBy: 'id DESC');
    notes = rows
        .where((r) => _i(r['user_id']) == me2.id)
        .take(100)
        .map((r) => AppNotification(_i(r['id']), (r['kind'] ?? '') as String, (r['title'] ?? '') as String,
            (r['body'] ?? '') as String, _dt(r['created']), _b(r['read']), r['payload'] as String?))
        .toList();
    // phone notifications for anything new since last time
    final key = 'notified_${me2.id}';
    final last = int.tryParse(await local.getSetting(key) ?? '');
    final maxId = notes.isEmpty ? 0 : notes.first.id;
    if (last == null) {
      await local.setSetting(key, '$maxId'); // first time: do not flood with old alerts
    } else if (maxId > last) {
      for (final n in notes.reversed) {
        if (n.id > last && !n.read) {
          await notifier.show(n.id, n.title, n.body, payload: n.payload, extend: n.kind == 'sub_ending');
        }
      }
      await local.setSetting(key, '$maxId');
    }
  }

  /// Local-only mode: the app itself creates the alert for the other account (Supabase mode uses SQL triggers).
  Future<void> _notifyLocal(int? userId, String kind, String title, String body, {String? payload}) async {
    if (remote || userId == null) return;
    await _insertNote(userId, kind, title, body, payload);
  }

  /// Local-only mode: everyone involved in a GCash payment gets an alert (Supabase mode: SQL trigger).
  Future<void> _payAlerts(String item, double amount, String ref) async {
    if (remote || user == null) return;
    final amt = money0(amount);
    await _notifyLocal(user!.id, 'pay_ok', 'Payment successful',
        'Your GCash payment of $amt for $item was received (ref. $ref).', payload: 'bell');
    for (final u in _users) {
      if (u.role == Role.admin) {
        await _notifyLocal(u.id, 'pay_in', 'GCash payment received',
            '${user!.fullName} paid $amt for $item (ref. $ref).', payload: 'bell');
      }
    }
  }

  /// The admin's mobile number = receiver of every payment (the QR code is made from it).
  Future<String> gcashNumber() async {
    if (remote) return (await repo.rpcText('gcash_receiver')) ?? '';
    for (final u in _users) {
      if (u.role == Role.admin && u.active) return u.phone;
    }
    return '';
  }

  Future<void> _insertNote(int userId, String kind, String title, String body, String? payload) async {
    final at = DateTime.now();
    final id = await repo.insert('notifications',
        {'user_id': userId, 'kind': kind, 'title': title, 'body': body, 'created': _ms(at), 'read': 0, 'payload': payload});
    if (userId == user?.id) {
      notes.insert(0, AppNotification(id, kind, title, body, at, false, payload));
      await notifier.show(id, title, body, payload: payload, extend: kind == 'sub_ending');
      await local.setSetting('notified_$userId', '$id');
      notifyListeners();
    }
  }

  void markRead(AppNotification n) {
    if (n.read) return;
    n.read = true;
    _u('notifications', n.id, {'read': 1});
    notifyListeners();
  }

  void markAllRead() {
    for (final n in notes) {
      if (!n.read) {
        n.read = true;
        _u('notifications', n.id, {'read': 1});
      }
    }
    notifyListeners();
  }

  /// "Clear" button on the notification list: deletes this account's notifications.
  Future<void> clearNotes() async {
    final id = user?.id;
    if (id == null) return;
    notes = [];
    notifyListeners();
    try {
      await repo.remove('notifications', 'user_id', id);
    } catch (_) {}
  }

  /// Store owner: 7 days before the plan ends, tell them once and ask if they want to extend.
  Future<void> checkPlanReminder() async {
    if (role != Role.store || user == null) return;
    final s = myStore;
    final left = s.planUntil.difference(DateTime.now()).inDays;
    if (left > 7 || !s.planUntil.isAfter(DateTime.now())) return;
    final key = 'plan_remind_${s.id}';
    if (await local.getSetting(key) == '${_ms(s.planUntil)}') return;
    await local.setSetting(key, '${_ms(s.planUntil)}');
    await _insertNote(user!.id, 'sub_ending', 'Subscription ending soon',
        'Your store plan ends in ${left <= 0 ? 'less than a day' : '$left day${left == 1 ? '' : 's'}'} (${_fmtDate(s.planUntil)}). Extend it now?', 'plan');
    planPrompt = true;
    notifyListeners();
  }

  // ---- hidden Debug tab
  void logoTap() {
    if (role != Role.admin || debugUnlocked) return;
    debugTaps++;
    _tapTimer?.cancel();
    if (debugTaps >= 5) {
      debugUnlocked = true;
      debugTaps = 0;
    } else {
      _tapTimer = Timer(const Duration(milliseconds: 2500), () {
        debugTaps = 0;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  /// Debug button: sends a test notification of one kind to the admin's own phone and bell list.
  Future<void> debugNotify(String kind) async {
    if (user == null) return;
    final n = DateTime.now();
    final end = _fmtDate(n.add(const Duration(days: 30)));
    final t = switch (kind) {
      'sub_bought' => ['Subscription active', 'Test: the AniCare Store plan is active until $end.', 'plan'],
      'sub_ending' => ['Subscription ending soon', 'Test: the plan ends in 7 days. Extend it now?', 'plan'],
      'new_product' => ['New product available', 'Test: Gumboro vaccine at Green Valley Agri-Vet.', 'bell'],
      'booking_paid' => ['New paid booking', 'Test: Ruben Alvarez paid ₱358.75 with GCash.', 'bell'],
      'reservation' => ['New reservation', 'Test: Ruben Alvarez reserved Ivermectin × 2.', 'bell'],
      'pay_ok' => ['Payment successful', 'Test: your GCash payment of ₱358.75 was received (ref. 1234567890123).', 'bell'],
      'pay_in' => ['GCash payment received', 'Test: Ruben Alvarez paid ₱358.75 for a vet booking (ref. 1234567890123).', 'bell'],
      'product_removed' => ['Product not available', 'Test: Gumboro vaccine at Green Valley Agri-Vet is no longer available.', 'bell'],
      _ => ['AniCare fee recorded', 'Test: ₱17.50 (5%) from a completed booking.', 'bell'],
    };
    await _insertNote(user!.id, kind, t[0], t[1], t[2]);
  }

  // ================================================================ SETTINGS (cog)
  Future<String?> updateProfile({
    required String fullName,
    required String phone,
    String? place,
    double? vetFee,
    String? vetKind,
    String? license,
    String? storeName,
    String? storeAddress,
  }) async {
    final u = user!;
    if (fullName.trim().length < 3) return 'Please enter your full name.';
    if (!RegExp(r'^9\d{9}$').hasMatch(phone.trim())) return 'Mobile number: 10 digits starting with 9.';
    String? display = u.display;
    var where = u.place;
    if (u.role == Role.raiser) {
      where = (place ?? u.place).trim();
      if (fullName.trim() != u.fullName) display = null;
    } else if (u.role == Role.vet) {
      final kind = vetKind ?? me.kind;
      display = '${kind == 'Veterinarian' ? 'Dr.' : 'Tech.'} ${fullName.trim()}';
    } else if (u.role == Role.store) {
      display = (storeName ?? myStore.name).trim();
      where = (storeAddress ?? myStore.address).trim();
    }
    try {
      if (remote) {
        await repo.rpc('update_my_profile',
            {'p_full_name': fullName.trim(), 'p_phone': phone.trim(), 'p_place': where, 'p_display': display});
      } else {
        await repo.update('users', u.id, {'full_name': fullName.trim(), 'phone': phone.trim(), 'place': where, 'display': display});
      }
      if (u.role == Role.vet) {
        final v = me;
        final kind = vetKind ?? v.kind;
        v.name = display!;
        v.kind = kind;
        if (vetFee != null) v.fee = vetFee;
        if (license != null) v.license = license.trim();
        await repo.update('vets', v.id, {'name': v.name, 'kind': v.kind, 'fee': v.fee, 'license': v.license});
      } else if (u.role == Role.store) {
        final s = myStore;
        s.name = display!;
        s.address = where;
        await repo.update('stores', s.id, {'name': s.name, 'address': s.address});
      }
    } catch (_) {
      return 'Could not save. Check your connection and try again.';
    }
    u.fullName = fullName.trim();
    u.phone = phone.trim();
    u.place = where;
    u.display = display;
    notifyListeners();
    return null;
  }

  Future<String?> changeUsername(String newName) async {
    final n = newName.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9._]{4,20}$').hasMatch(n)) return 'Username: 4–20 letters, numbers, dot or underscore.';
    if (n == user!.username) return null;
    try {
      if (remote) {
        if (await repo.usernameTaken(n)) return 'That username is already taken.';
        await repo.rpc('change_username', {'p_new': n});
      } else {
        for (final x in _users) {
          if (x.username == n) return 'That username is already taken.';
        }
        await repo.update('users', user!.id, {'username': n});
      }
    } catch (_) {
      return 'Could not change the username. Try again.';
    }
    user!.username = n;
    notifyListeners();
    return null;
  }

  /// Asks for the old password first.
  Future<String?> changePassword(String oldPw, String newPw) async {
    if (!PwCheck(newPw).ok) return pwRuleText;
    final u = user!;
    if (remote) {
      final e = await repo.signIn(u.username, oldPw);
      if (e != null) return e.contains('No internet') ? e : 'The old password is wrong.';
      return repo.updatePassword(newPw);
    }
    if (hashPw(oldPw, u.salt) != u.pass) return 'The old password is wrong.';
    final salt = newSalt();
    u.salt = salt;
    u.pass = hashPw(newPw, salt);
    await repo.update('users', u.id, {'pass': u.pass, 'salt': salt});
    return null;
  }

  // ================================================================ ADMIN
  List<User> get managedUsers => _users.where((u) => u.role != Role.admin).toList();
  List<Animal> get allAnimals => _animals;
  List<Payment> get payments => _payments;
  List<Payment> get payments30 {
    final from = DateTime.now().subtract(const Duration(days: 30));
    // only money that really moved / is recorded (pending and failed payments are left out)
    return _payments.where((x) => x.at.isAfter(from) && (x.status == 'paid' || x.status == 'held' || x.status == 'owed')).toList();
  }

  String placeOf(int userId) {
    for (final u in _users) {
      if (u.id == userId) return u.place;
    }
    return '';
  }

  /// every vaccine product in every store
  List<({Store store, Product p})> get vaccines =>
      [for (final s in stores) for (final p in s.listed) if (p.cat == 'Vaccine') (store: s, p: p)];

  Future<void> adminSaveProfile(User u, {String? fullName, String? phone, String? place}) async {
    final v = <String, Object?>{};
    if (fullName != null && fullName.trim().isNotEmpty) {
      u.fullName = fullName.trim();
      v['full_name'] = u.fullName;
      if (u.role == Role.vet) {
        final pre = (u.display ?? '').startsWith('Tech.') ? 'Tech.' : 'Dr.';
        u.display = '$pre ${u.fullName}';
        v['display'] = u.display;
        for (final vt in vets) {
          if (vt.userId == u.id) {
            vt.name = u.display!;
            _u('vets', vt.id, {'name': vt.name});
          }
        }
      } else if (u.role == Role.raiser) {
        u.display = null;
        v['display'] = null;
      }
    }
    if (phone != null && phone.trim().isNotEmpty) {
      u.phone = phone.trim();
      v['phone'] = u.phone;
    }
    if (place != null && place.trim().isNotEmpty) {
      u.place = place.trim();
      v['place'] = u.place;
    }
    if (v.isNotEmpty) await repo.update('users', u.id, v);
    notifyListeners();
  }

  Future<void> adminSetActive(User u, bool active) async {
    if (remote) {
      await repo.rpc('admin_set_active', {'p_user': u.id, 'p_active': active ? 1 : 0});
    } else {
      await repo.update('users', u.id, {'active': active ? 1 : 0});
    }
    u.active = active;
    notifyListeners();
  }

  Future<String?> adminResetPassword(User u, String newPassword) async {
    if (!PwCheck(newPassword).ok) return pwRuleText;
    if (remote) {
      await repo.rpc('admin_reset_password', {'p_user': u.id, 'p_password': newPassword});
    } else {
      final salt = newSalt();
      u.salt = salt;
      u.pass = hashPw(newPassword, salt);
      await repo.update('users', u.id, {'pass': u.pass, 'salt': salt});
    }
    return null;
  }
}

final app = AppState();

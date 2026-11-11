import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const kPassword = 'AniCare2987!'; // password of the 3 test accounts

String newSalt() {
  final r = Random.secure();
  return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
}

/// Passwords are never stored as text: salt + SHA-256 hash.
String hashPw(String pw, String salt) => sha256.convert(utf8.encode('$salt:$pw')).toString();

/// Opens (and on first run creates + seeds) the on-device SQLite database.
Future<Database> openAppDb() async {
  final path = p.join(await getDatabasesPath(), 'anicare.db');
  return openDatabase(path, version: 1, onCreate: (db, v) async {
    await _schema(db);
    await _seed(db);
  });
}

Future<void> _schema(Database db) async {
  const t = [
    'CREATE TABLE settings (k TEXT PRIMARY KEY, v TEXT)',
    '''CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT UNIQUE NOT NULL,
       full_name TEXT NOT NULL, display TEXT, phone TEXT, place TEXT, role TEXT NOT NULL,
       pass TEXT NOT NULL, salt TEXT NOT NULL, created INTEGER)''',
    '''CREATE TABLE vets (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, name TEXT, kind TEXT,
       about TEXT, photo TEXT, license TEXT, km REAL, fee REAL, rating REAL, services TEXT, plan_until INTEGER)''',
    '''CREATE TABLE stores (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, name TEXT, address TEXT,
       photo TEXT, km REAL, plan_until INTEGER)''',
    '''CREATE TABLE products (id INTEGER PRIMARY KEY AUTOINCREMENT, store_id INTEGER, name TEXT, cat TEXT,
       price REAL, stock INTEGER, img TEXT)''',
    '''CREATE TABLE animals (id INTEGER PRIMARY KEY AUTOINCREMENT, owner_id INTEGER, name TEXT, breed TEXT,
       species TEXT, flock INTEGER, heads INTEGER, photo TEXT)''',
    '''CREATE TABLE schedules (id INTEGER PRIMARY KEY AUTOINCREMENT, animal_id INTEGER, label TEXT,
       due INTEGER, done INTEGER)''',
    '''CREATE TABLE records (id INTEGER PRIMARY KEY AUTOINCREMENT, animal_id INTEGER, at INTEGER,
       title TEXT, note TEXT, author TEXT)''',
    '''CREATE TABLE expenses (id INTEGER PRIMARY KEY AUTOINCREMENT, animal_id INTEGER, at INTEGER,
       item TEXT, amount REAL)''',
    '''CREATE TABLE bookings (id INTEGER PRIMARY KEY AUTOINCREMENT, raiser_id INTEGER, raiser_name TEXT,
       vet_id INTEGER, animal_id INTEGER, animal_name TEXT, reason TEXT, day INTEGER, slot TEXT,
       fee REAL, urgent INTEGER, status TEXT, r_confirm INTEGER, v_confirm INTEGER, method TEXT, rating INTEGER)''',
    '''CREATE TABLE reservations (id INTEGER PRIMARY KEY AUTOINCREMENT, raiser_id INTEGER, raiser_name TEXT,
       store_id INTEGER, product_id INTEGER, qty INTEGER, method TEXT, picked_up INTEGER)''',
  ];
  for (final s in t) {
    await db.execute(s);
  }
}

int _ms(int days) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day).add(Duration(days: days)).millisecondsSinceEpoch;
}

/// Starting data: the 3 test accounts + sample providers, stores, animals, bookings.
Future<void> _seed(Database db) async {
  Future<int> user(String u, String name, String display, String phone, String place, String role) {
    final salt = newSalt();
    return db.insert('users', {
      'username': u, 'full_name': name, 'display': display, 'phone': phone, 'place': place,
      'role': role, 'pass': hashPw(kPassword, salt), 'salt': salt,
      'created': DateTime.now().millisecondsSinceEpoch,
    });
  }

  final ruben = await user('ruben.farmer', 'Ruben Alvarez', 'Mang Ruben', '9171234567', 'Poblacion, Bunawan', 'raiser');
  final maria = await user('maria.vet', 'Maria Santos', 'Dr. Maria Santos', '9181234567', 'Poblacion, Bunawan', 'vet');
  final shop = await user('bunawan.store', 'Bunawan AgriVet Supply', 'Bunawan AgriVet Supply', '9191234567', 'Poblacion, Bunawan', 'store');

  Future<int> vet(int? uid, String name, String kind, String about, String photo, double km, double fee,
      double rating, String services) =>
      db.insert('vets', {
        'user_id': uid, 'name': name, 'kind': kind, 'about': about, 'photo': photo, 'license': '',
        'km': km, 'fee': fee, 'rating': rating, 'services': services, 'plan_until': _ms(30),
      });
  final v1 = await vet(maria, 'Dr. Maria Santos, DVM', 'Veterinarian',
      'Swine and poultry health. Farm visits within Bunawan.', 'assets/img/doctor.jpg', 1.2, 350, 4.9,
      'Farm visit,Vaccination,Pregnancy check');
  final v2 = await vet(null, 'Tech. Carlo Reyes', 'Animal Technician',
      'Vaccination, deworming and basic care for goats and hogs.', 'assets/img/doctor_3.jpg', 2.8, 200, 4.7,
      'Vaccination,Deworming,Hoof care');
  await vet(null, 'Dr. Paolo Lim, DVM', 'Veterinarian', 'Large animal and flock health programs.',
      'assets/img/doctor_2.jpg', 4.5, 400, 4.8, 'Farm visit,Flock program,Emergency');

  Future<int> store(int? uid, String name, String addr, String photo, double km) => db.insert('stores',
      {'user_id': uid, 'name': name, 'address': addr, 'photo': photo, 'km': km, 'plan_until': _ms(30)});
  Future<void> prod(int sid, String n, String c, double pr, int st, [String? img]) => db.insert('products',
      {'store_id': sid, 'name': n, 'cat': c, 'price': pr, 'stock': st, 'img': img}).then((_) {});
  final s1 = await store(shop, 'Bunawan AgriVet Supply', 'Poblacion, Bunawan', 'assets/img/store1.jpg', 0.9);
  final s2 = await store(null, 'Green Valley Agri-Vet', 'Consuelo, Bunawan', 'assets/img/store2.jpg', 3.1);
  final s3 = await store(null, 'Farm & Vet Mart', 'Imelda, Bunawan', 'assets/img/store1.jpg', 5.4);
  await prod(s1, 'Ivermectin (dewormer)', 'Dewormer', 180, 24, 'assets/img/worm1.jpg');
  await prod(s1, 'Newcastle vaccine (100 doses)', 'Vaccine', 260, 12, 'assets/img/vaccine.jpg');
  await prod(s1, 'Iron dextran injection', 'Supplement', 150, 18, 'assets/img/vaccine2.jpg');
  await prod(s2, 'Hog cholera vaccine', 'Vaccine', 320, 8, 'assets/img/vaccine2.jpg');
  await prod(s2, 'Vitamin B-complex', 'Supplement', 95, 30);
  await prod(s2, 'Electrolytes (poultry)', 'Supplement', 70, 40);
  await prod(s3, 'Albendazole (dewormer)', 'Dewormer', 120, 0, 'assets/img/worm2.jpg');
  await prod(s3, 'Oxytetracycline', 'Antibiotic', 210, 15);
  await prod(s3, 'Ivermectin (dewormer)', 'Dewormer', 175, 10, 'assets/img/worm3.jpg');

  Future<int> animal(String n, String sp, String breed, bool flock, int heads, String photo) =>
      db.insert('animals', {'owner_id': ruben, 'name': n, 'breed': breed, 'species': sp,
        'flock': flock ? 1 : 0, 'heads': heads, 'photo': photo});
  Future<void> sched(int a, String l, int days) =>
      db.insert('schedules', {'animal_id': a, 'label': l, 'due': _ms(days), 'done': 0}).then((_) {});
  Future<void> rec(int a, int days, String t, String n, String by) =>
      db.insert('records', {'animal_id': a, 'at': _ms(days), 'title': t, 'note': n, 'author': by}).then((_) {});
  Future<void> exp(int a, int days, String i, double amt) =>
      db.insert('expenses', {'animal_id': a, 'at': _ms(days), 'item': i, 'amount': amt}).then((_) {});

  final a1 = await animal('Native Chickens – Batch 3', 'poultry', 'Native', true, 120, 'assets/img/chickens.jpg');
  await sched(a1, 'Newcastle disease vaccine', 2);
  await sched(a1, 'Gumboro vaccine', 15);
  await sched(a1, 'Deworming', 40);
  await rec(a1, -20, 'Vaccination', 'Newcastle booster given. Flock healthy.', 'Tech. Carlo Reyes');
  await exp(a1, -25, 'Starter feed (5 sacks)', 4250);
  await exp(a1, -20, 'Vaccine', 260);

  final a2 = await animal('Bella', 'goat', 'Boer cross', false, 1, 'assets/img/goat.jpg');
  await sched(a2, 'Deworming', 5);
  await sched(a2, 'CD&T vaccine', 21);
  await rec(a2, -45, 'Check-up', 'Good body condition. Hooves trimmed.', 'Dr. Maria Santos, DVM');
  await exp(a2, -10, 'Dewormer', 180);

  final a3 = await animal('Sow “Rosa”', 'hog', 'Landrace', false, 1, 'assets/img/pig.jpg');
  await sched(a3, 'Hog cholera vaccine', 1);
  await sched(a3, 'Deworming', 30);
  await exp(a3, -5, 'Feed (2 sacks)', 2400);

  Future<void> booking(int vet, int animalId, String an, String reason, int days, String slot, double fee,
      String status, bool rc, bool vc, String method, int? rating) =>
      db.insert('bookings', {
        'raiser_id': ruben, 'raiser_name': 'Ruben Alvarez', 'vet_id': vet, 'animal_id': animalId,
        'animal_name': an, 'reason': reason, 'day': _ms(days), 'slot': slot, 'fee': fee, 'urgent': 0,
        'status': status, 'r_confirm': rc ? 1 : 0, 'v_confirm': vc ? 1 : 0, 'method': method, 'rating': rating,
      }).then((_) {});
  await booking(v1, a3, 'Sow “Rosa”', 'Hog cholera vaccination', 1, '9:00 AM', 350, 'pending', false, false, 'GCash', null);
  await booking(v1, a2, 'Bella', 'Goat check-up', 3, '2:00 PM', 350, 'accepted', false, false, 'Maya', null);
  await booking(v2, a1, 'Native Chickens – Batch 3', 'Flock vaccination', -20, '10:00 AM', 200, 'completed',
      true, true, 'GCash', 5);
}

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
  return openDatabase(path, version: 4, onCreate: (db, v) async {
    await _schema(db);
    await _seed(db);
    await _seedV2(db);
    await _upgradeV3(db);
    await _upgradeV4(db);
  }, onUpgrade: (db, oldV, newV) async {
    if (oldV < 2) {
      // version 5.x -> 6.0.0: admin account, payments, expiry dates, account on/off switch
      await db.execute('ALTER TABLE users ADD COLUMN active INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE products ADD COLUMN expiry INTEGER');
      await db.execute(_paymentsSql);
      await _seedV2(db);
    }
    if (oldV < 3) await _upgradeV3(db);
    if (oldV < 4) await _upgradeV4(db);
  });
}

const _paymentsSql = '''CREATE TABLE payments (id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT, ref_id INTEGER,
       payer TEXT, payee TEXT, item TEXT, amount REAL, method TEXT, status TEXT, at INTEGER)''';

Future<void> _schema(Database db) async {
  const t = [
    'CREATE TABLE settings (k TEXT PRIMARY KEY, v TEXT)',
    '''CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT UNIQUE NOT NULL,
       full_name TEXT NOT NULL, display TEXT, phone TEXT, place TEXT, role TEXT NOT NULL,
       pass TEXT NOT NULL, salt TEXT NOT NULL, created INTEGER, active INTEGER NOT NULL DEFAULT 1)''',
    '''CREATE TABLE vets (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, name TEXT, kind TEXT,
       about TEXT, photo TEXT, license TEXT, km REAL, fee REAL, rating REAL, services TEXT, plan_until INTEGER)''',
    '''CREATE TABLE stores (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, name TEXT, address TEXT,
       photo TEXT, km REAL, plan_until INTEGER)''',
    '''CREATE TABLE products (id INTEGER PRIMARY KEY AUTOINCREMENT, store_id INTEGER, name TEXT, cat TEXT,
       price REAL, stock INTEGER, img TEXT, expiry INTEGER)''',
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
    _paymentsSql,
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
  await booking(v1, a2, 'Bella', 'Goat check-up', 3, '2:00 PM', 350, 'accepted', false, false, 'GCash', null);
  await booking(v2, a1, 'Native Chickens – Batch 3', 'Flock vaccination', -20, '10:00 AM', 200, 'completed',
      true, true, 'GCash', 5);
}

// ---------------------------------------------------------------- v2 seed (6.0.0)
Future<void> _seedV2(Database db) async {
  Future<int> addUser(String u, String name, String display, String phone, String place, String role) {
    final salt = newSalt();
    return db.insert('users', {
      'username': u, 'full_name': name, 'display': display, 'phone': phone, 'place': place,
      'role': role, 'pass': hashPw(kPassword, salt), 'salt': salt, 'active': 1,
      'created': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // built-in admin (test account, same password as the others)
  await addUser('admin', 'AniCare Admin', 'AniCare Admin', '9170000000', 'Poblacion, Bunawan', 'admin');

  // sample farmers in other barangays (so the LGU numbers have something to show)
  const sched = {
    'hog': ['Iron injection', 'Hog cholera vaccine', 'Deworming'],
    'poultry': ['Newcastle disease vaccine', 'Gumboro vaccine', 'Deworming'],
    'goat': ['Deworming', 'CD&T vaccine', 'Hoof check'],
  };
  final farmers = [
    ['maria.cruz', 'Maria Cruz', 'Consuelo, Bunawan', '9175550101', [['Native Hens', 'poultry', 'Native', true, 60], ['Biik', 'hog', 'Duroc', false, 1]]],
    ['jose.reyes', 'Jose Reyes', 'Imelda, Bunawan', '9185550202', [['Boer Goats', 'goat', 'Boer', true, 8]]],
    ['ana.lopez', 'Ana Lopez', 'Libertad, Bunawan', '9195550303', [['Sow “Nene”', 'hog', 'Landrace', false, 1], ['Broilers', 'poultry', 'Cobb', true, 200]]],
  ];
  var n = 0;
  for (final f in farmers) {
    final uid = await addUser(f[0] as String, f[1] as String, '', f[3] as String, f[2] as String, 'raiser');
    await db.update('users', {'display': null}, where: 'id=?', whereArgs: [uid]);
    for (final a in f[4] as List) {
      final aid = await db.insert('animals', {
        'owner_id': uid, 'name': a[0], 'breed': a[2], 'species': a[1],
        'flock': (a[3] as bool) ? 1 : 0, 'heads': a[4], 'photo': null,
      });
      final labels = sched[a[1]]!;
      for (var i = 0; i < labels.length; i++) {
        await db.insert('schedules', {
          'animal_id': aid, 'label': labels[i], 'due': _ms(-10 + i * 12), 'done': (n + i) % 2 == 0 ? 1 : 0,
        });
      }
      await db.insert('expenses', {'animal_id': aid, 'at': _ms(-8), 'item': 'Feed', 'amount': 1500.0 + n * 400});
      n++;
    }
  }
  // the sample schedules of Ruben: one vaccine already done so compliance is not 0
  await db.rawUpdate("UPDATE schedules SET done=1 WHERE label='Deworming' AND animal_id IN (SELECT id FROM animals WHERE owner_id=1) AND due > ? ", [_ms(0)]);

  // ---- vaccine stock with expiry dates
  Future<int?> storeId(String name) async {
    final r = await db.query('stores', columns: ['id'], where: 'name=?', whereArgs: [name]);
    return r.isEmpty ? null : r.first['id'] as int;
  }

  await db.rawUpdate("UPDATE products SET expiry=? WHERE name LIKE 'Newcastle vaccine%'", [_ms(18)]);
  await db.rawUpdate("UPDATE products SET expiry=? WHERE name LIKE 'Hog cholera%'", [_ms(150)]);
  final gv = await storeId('Green Valley Agri-Vet');
  final fv = await storeId('Farm & Vet Mart');
  if (gv != null) {
    await db.insert('products', {'store_id': gv, 'name': 'Gumboro vaccine (100 doses)', 'cat': 'Vaccine',
      'price': 280.0, 'stock': 25, 'img': 'assets/img/vaccine.jpg', 'expiry': _ms(90)});
  }
  if (fv != null) {
    await db.insert('products', {'store_id': fv, 'name': 'Newcastle vaccine (100 doses)', 'cat': 'Vaccine',
      'price': 255.0, 'stock': 3, 'img': 'assets/img/vaccine.jpg', 'expiry': _ms(-5)});
  }
  await db.rawUpdate('UPDATE products SET expiry=? WHERE expiry IS NULL', [_ms(300)]);
}

/// 6.1.0: payment links + Maya reference, notifications table, and NO dummy purchase history
/// (the admin's purchase data now comes only from real Maya sandbox transactions).
Future<void> _upgradeV3(Database db) async {
  await db.execute('ALTER TABLE payments ADD COLUMN payer_id INTEGER');
  await db.execute('ALTER TABLE payments ADD COLUMN payee_id INTEGER');
  await db.execute('ALTER TABLE payments ADD COLUMN ref TEXT');
  await db.execute('''CREATE TABLE notifications (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER,
       kind TEXT, title TEXT, body TEXT, created INTEGER, read INTEGER NOT NULL DEFAULT 0, payload TEXT)''');
  await db.delete('payments', where: 'ref_id = 0'); // old sample rows
}

/// 1.3.0: removed products stay in the database (tagged "not available"), Maya wording becomes GCash.
Future<void> _upgradeV4(Database db) async {
  await db.execute('ALTER TABLE products ADD COLUMN available INTEGER NOT NULL DEFAULT 1');
  await db.execute("UPDATE bookings SET method='GCash' WHERE method='Maya'");
  await db.execute("UPDATE payments SET method='GCash' WHERE method='Maya'");
  await db.execute("UPDATE reservations SET method='GCash' WHERE method='Maya'");
}

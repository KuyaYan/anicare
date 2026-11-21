import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'db.dart';

/// Shows a message when a Supabase call fails (set in main.dart).
void Function(String message)? onRepoError;

/// Where the data lives. Same table / column names in both implementations,
/// so the app code does not care whether it talks to SQLite or Supabase.
abstract class Repo {
  bool get remote;
  Future<List<Map<String, Object?>>> query(String table, {String? orderBy});
  Future<int> insert(String table, Map<String, Object?> values);
  Future<void> update(String table, int id, Map<String, Object?> values);
  Future<void> adjustStock(int productId, int delta);
  // --- Supabase only
  String? get authId;
  bool get hasSession;
  Future<String?> signIn(String username, String password);
  Future<String?> signUp(String username, String password);
  Future<void> signOut();
  Future<bool> usernameTaken(String username);
  Future<void> rpc(String fn, Map<String, dynamic> params);
  Future<String?> rpcText(String fn);
  Future<void> remove(String table, String col, int value);
  Future<String> uploadPhoto(Uint8List bytes);
  Future<String?> updatePassword(String newPassword);
}

// ---------------------------------------------------------------- local SQLite
class LocalRepo implements Repo {
  late Database db;
  Future<void> init() async => db = await openAppDb();

  @override
  bool get remote => false;

  @override
  Future<List<Map<String, Object?>>> query(String table, {String? orderBy}) =>
      db.query(table, orderBy: orderBy);

  @override
  Future<int> insert(String table, Map<String, Object?> values) => db.insert(table, values);

  @override
  Future<void> update(String table, int id, Map<String, Object?> values) async {
    await db.update(table, values, where: 'id=?', whereArgs: [id]);
  }

  @override
  Future<void> adjustStock(int productId, int delta) async {
    await db.rawUpdate('UPDATE products SET stock = MAX(stock + ?, 0) WHERE id=?', [delta, productId]);
  }

  // settings (theme, local session) are always kept on the phone
  Future<String?> getSetting(String k) async {
    final r = await db.query('settings', where: 'k=?', whereArgs: [k]);
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  Future<void> setSetting(String k, String v) =>
      db.insert('settings', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> delSetting(String k) => db.delete('settings', where: 'k=?', whereArgs: [k]);

  @override
  String? get authId => null;
  @override
  bool get hasSession => false;
  @override
  Future<String?> signIn(String username, String password) async => null;
  @override
  Future<String?> signUp(String username, String password) async => null;
  @override
  Future<void> signOut() async {}
  @override
  Future<bool> usernameTaken(String username) async => false;
  @override
  Future<void> rpc(String fn, Map<String, dynamic> params) async {}
  @override
  Future<String?> rpcText(String fn) async => null;
  @override
  Future<void> remove(String table, String col, int value) async {
    await db.delete(table, where: '$col=?', whereArgs: [value]);
  }
  /// offline mode: the picture is saved inside the app's own folder on the phone
  @override
  Future<String> uploadPhoto(Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await f.writeAsBytes(bytes);
    return f.path;
  }
  @override
  Future<String?> updatePassword(String newPassword) async => null;
}

// ---------------------------------------------------------------- Supabase
class SupabaseRepo implements Repo {
  Future<void> init() => Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);

  SupabaseClient get c => Supabase.instance.client;

  @override
  bool get remote => true;

  void _fail(Object e) {
    final t = e.toString().toLowerCase();
    final offline = t.contains('socket') || t.contains('failed host') || t.contains('network') || t.contains('connection');
    onRepoError?.call(offline ? 'No internet connection. Pull down to refresh when you are back online.' : 'Sync problem: $e');
  }

  @override
  Future<List<Map<String, Object?>>> query(String table, {String? orderBy}) async {
    try {
      final base = c.from(table).select();
      final List<Map<String, dynamic>> rows;
      if (orderBy == null) {
        rows = await base;
      } else {
        final p = orderBy.split(' ');
        rows = await base.order(p[0], ascending: !(p.length > 1 && p[1].toUpperCase() == 'DESC'));
      }
      return rows.map((e) => Map<String, Object?>.from(e)).toList();
    } catch (e) {
      _fail(e);
      rethrow;
    }
  }

  @override
  Future<int> insert(String table, Map<String, Object?> values) async {
    try {
      final row = await c.from(table).insert(values).select().single();
      return (row['id'] as num).toInt();
    } catch (e) {
      _fail(e);
      rethrow;
    }
  }

  @override
  Future<void> update(String table, int id, Map<String, Object?> values) async {
    try {
      await c.from(table).update(values).eq('id', id);
    } catch (e) {
      _fail(e);
      rethrow;
    }
  }

  @override
  Future<void> adjustStock(int productId, int delta) => rpc('adjust_stock', {'p_id': productId, 'p_delta': delta});

  String _email(String u) => '${u.trim().toLowerCase()}@anicare.app';

  @override
  String? get authId => c.auth.currentUser?.id;

  @override
  bool get hasSession => c.auth.currentSession != null;

  @override
  Future<String?> signIn(String username, String password) async {
    try {
      await c.auth.signInWithPassword(email: _email(username), password: password);
      return null;
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('retryable fetch') || m.contains('socket') || m.contains('connection') || m.contains('host lookup')) {
        return 'No internet connection. Please try again.';
      }
      return m.contains('banned')
          ? 'This account is deactivated. Contact the admin.'
          : 'Wrong username or password. Please try again.';
    } catch (_) {
      return 'No internet connection. Please try again.';
    }
  }

  @override
  Future<String?> signUp(String username, String password) async {
    try {
      final r = await c.auth.signUp(email: _email(username), password: password);
      if (r.session == null) return 'Sign-up needs "Confirm email" turned OFF in Supabase (see the guide).';
      return null;
    } on AuthException catch (e) {
      return e.message.toLowerCase().contains('already') ? 'That username is already taken.' : e.message;
    } catch (_) {
      return 'No internet connection. Please try again.';
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await c.auth.signOut();
    } catch (_) {}
  }

  @override
  Future<bool> usernameTaken(String username) async {
    try {
      final r = await c.rpc('username_taken', params: {'p_name': username.trim().toLowerCase()});
      return r == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> rpc(String fn, Map<String, dynamic> params) async {
    try {
      await c.rpc(fn, params: params);
    } catch (e) {
      _fail(e);
      rethrow;
    }
  }

  @override
  Future<String?> rpcText(String fn) async {
    try {
      final r = await c.rpc(fn);
      return r?.toString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> remove(String table, String col, int value) async {
    try {
      await c.from(table).delete().eq(col, value);
    } catch (e) {
      _fail(e);
      rethrow;
    }
  }

  /// uploads to the Storage bucket (one folder per signed-in user) and returns the public address
  @override
  Future<String> uploadPhoto(Uint8List bytes) async {
    try {
      final path = '${c.auth.currentUser?.id ?? 'anon'}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await c.storage
          .from(kPhotoBucket)
          .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
      return c.storage.from(kPhotoBucket).getPublicUrl(path);
    } catch (e) {
      _fail(e);
      rethrow;
    }
  }
  @override
  Future<String?> updatePassword(String newPassword) async {
    try {
      await c.auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'No internet connection. Please try again.';
    }
  }
}

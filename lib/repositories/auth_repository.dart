import '../core/constants.dart';
import '../database/db_helper.dart';
import '../models/user_model.dart';

/// Repository autentikasi & sesi pengguna.
class AuthRepository {
  final DBHelper _db = DBHelper.instance;

  Future<Map<String, Object?>?> _activeUser() async {
    final Map<String, Object?>? byName = await _db.queryOne(
      DBHelper.tblUsers,
      where: 'username = ? AND is_active = 1',
      whereArgs: <Object?>[AppConstants.defaultUsername],
    );
    return byName ??
        await _db.queryOne(
          DBHelper.tblUsers,
          where: 'is_active = 1',
        );
  }

  /// Apakah bendahara sudah membuat PIN-nya sendiri.
  Future<bool> isPinSet() async {
    final Map<String, Object?>? row = await _activeUser();
    if (row == null) return false;
    final String hash = (row['password_hash'] as String?) ?? '';
    return hash.isNotEmpty;
  }

  /// Buat PIN pertama. Hanya berhasil bila belum ada PIN sama sekali,
  /// sehingga PIN tidak bisa diganti lewat jalur ini.
  Future<bool> setInitialPin(String pin) async {
    if (pin.isEmpty) return false;
    if (await isPinSet()) return false;

    final Map<String, Object?>? row = await _activeUser();
    if (row == null) return false;

    final String now = DateTime.now().toIso8601String();
    await _db.update(
      DBHelper.tblUsers,
      <String, Object?>{
        'password_hash': DBHelper.hashPassword(pin, row['username'] as String),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: <Object?>[row['id']],
    );
    return true;
  }

  /// Verifikasi PIN login. Mengembalikan user aktif bila PIN cocok.
  ///
  /// Bila PIN belum pernah dibuat (`password_hash` kosong) login selalu
  /// ditolak — pengguna harus membuat PIN lebih dulu.
  Future<UserModel?> loginWithPin(String pin) async {
    if (pin.isEmpty) return null;

    final Map<String, Object?>? row = await _activeUser();
    if (row == null) return null;

    final UserModel user = UserModel.fromMap(row);
    if (user.passwordHash == AppConstants.noPinHash) return null;
    if (!DBHelper.verifyPassword(pin, user.username, user.passwordHash)) {
      return null;
    }

    await _db.update(
      DBHelper.tblUsers,
      <String, Object?>{
        'last_login': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[user.id],
    );
    return user;
  }

  /// Ambil berapa kali percobaan login gagal (untuk lockout ringan).
  Future<Map<String, Object?>> getAuthAttempts() async {
    final Map<String, Object?>? row = await _db.queryOne(
      DBHelper.tblSettings,
      where: 'key IN (?, ?)',
      whereArgs: const <Object?>['login_attempts', 'login_locked_until'],
    );
    return <String, Object?>{
      'attempts': row,
    };
  }

  /// Ganti kata sandi pengguna.
  Future<bool> changePassword({required int userId, required String oldPassword, required String newPassword}) async {
    final Map<String, Object?>? row = await _db.queryOne(
      DBHelper.tblUsers,
      where: 'id = ?',
      whereArgs: <Object?>[userId],
    );
    if (row == null) return false;
    final UserModel user = UserModel.fromMap(row);
    if (!DBHelper.verifyPassword(oldPassword, user.username, user.passwordHash)) {
      return false;
    }
    await _db.update(
      DBHelper.tblUsers,
      <String, Object?>{
        'password_hash': DBHelper.hashPassword(newPassword, user.username),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[userId],
    );
    return true;
  }

  /// Reset kata sandi ke default (dipakai khusus uji / fase 7).
  Future<void> resetPassword({required String username}) async {
    await _db.update(
      DBHelper.tblUsers,
      <String, Object?>{
        'password_hash': DBHelper.hashPassword(
          AppConstants.defaultPassword,
          username,
        ),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'username = ?',
      whereArgs: <Object?>[username],
    );
  }
}
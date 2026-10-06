import '../core/constants.dart';
import '../database/db_helper.dart';
import '../models/user_model.dart';

/// Repository autentikasi & sesi pengguna.
class AuthRepository {
  final DBHelper _db = DBHelper.instance;

  /// Verifikasi kredensial. Mengembalikan user jika berhasil, null jika gagal.
  Future<UserModel?> login({required String username, required String password}) async {
    final Map<String, Object?>? row = await _db.queryOne(
      DBHelper.tblUsers,
      where: 'username = ? AND is_active = 1',
      whereArgs: <Object?>[username.trim().toLowerCase()],
    );
    if (row == null) return null;

    final UserModel user = UserModel.fromMap(row);
    final bool valid = DBHelper.verifyPassword(
      password,
      user.username,
      user.passwordHash,
    );
    if (!valid) return null;

    // Perbarui last_login
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
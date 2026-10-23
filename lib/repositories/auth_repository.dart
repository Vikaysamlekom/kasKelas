import 'dart:math';

import '../core/constants.dart';
import '../database/db_helper.dart';
import '../models/user_model.dart';

/// Status pemulihan PIN di perangkat ini. Jawaban pertanyaan TIDAK
/// dikembalikan (hanya hash); UI hanya melihat teks pertanyaan + ada/tidaknya
/// kode pemulihan.
class RecoveryInfo {
  /// Teks pertanyaan keamanan terpasang (null = belum diatur).
  final String? q1;
  final String? q2;

  /// Apakah kode pemulihan sudah diaktifkan.
  final bool codeSet;

  /// Sudah berapa kali percobaan verifikasi gagal sejak gelombang ini.
  final int attempts;

  /// Sisa waktu terkunci (menit) setelah terlalu banyak percobaan salah.
  final int lockedRemainingMinutes;

  const RecoveryInfo({
    this.q1,
    this.q2,
    this.codeSet = false,
    this.attempts = 0,
    this.lockedRemainingMinutes = 0,
  });

  /// Kedua pertanyaan keamanan sudah diatur.
  bool get questionsSet => q1 != null && q2 != null;

  /// Minimal satu jalur pemulihan tersedia.
  bool get siap => questionsSet || codeSet;

  /// Sisa percobaan salah sebelum terkunci sementara.
  int get sisaPercobaan {
    final int sisa = AuthRepository.maxRecoveryAttempts - attempts;
    return sisa > 0 ? sisa : 1;
  }
}

/// Hasil percobaan reset PIN via jalur pemulihan.
enum RecoveryError {
  none, // sukses
  belumDisetup, // pemulihan belum diaktifkan
  terkunci, // terlalu banyak percobaan salah
  jawabanSalah,
  kodeSalah,
  gagal, // kesalahan internal (user tidak ditemukan, dsb.)
}

/// Hasil reset PIN + keterangan untuk pesan di UI.
class ResetPinOutcome {
  final RecoveryError error;

  /// Sisa menit terkunci (hanya bila [error] == RecoveryError.terkunci).
  final int lockedMinutes;

  const ResetPinOutcome(this.error, {this.lockedMinutes = 0});

  bool get ok => error == RecoveryError.none;
}

/// Repository autentikasi & sesi pengguna.
class AuthRepository {
  final DBHelper _db = DBHelper.instance;

  // Kunci settings untuk data pemulihan PIN.
  static const String _kRecoveryQ1 = 'recovery_q1';
  static const String _kRecoveryQ2 = 'recovery_q2';
  static const String _kRecoveryA1 = 'recovery_a1';
  static const String _kRecoveryA2 = 'recovery_a2';
  static const String _kRecoveryCode = 'recovery_code_hash';
  static const String _kRecoveryAttempts = 'recovery_attempts';
  static const String _kRecoveryLockedUntil = 'recovery_locked_until';

  /// Batas percobaan jawaban/kode salah sebelum terkunci sementara.
  static const int maxRecoveryAttempts = 5;

  /// Lama terkunci (menit) setelah batas percobaan dilewati.
  static const int recoveryLockMinutes = 10;

  /// Abjad kode pemulihan — tanpa karakter mudah tertukar (0/O, 1/I/L).
  static const String _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// Buat kode pemulihan acak berformat `XXXXX-XXXXX`. Plain text hanya
  /// dikembalikan untuk ditampilkan SEKALI; hash tersimpan saat
  /// [saveRecoverySetup] dipanggil dengan kode tersebut.
  static String generateRecoveryCodePlain() {
    final Random random = Random.secure();
    final StringBuffer s = StringBuffer();
    for (int i = 0; i < 10; i++) {
      if (i == 5) s.write('-');
      s.write(_codeAlphabet[random.nextInt(_codeAlphabet.length)]);
    }
    return s.toString();
  }

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

  // ------------------------------------------------------------------
  // PEMULIHAN PIN (LUPA PIN)
  // ------------------------------------------------------------------

  /// Wajib: jawaban dinormalisasi (huruf kecil, tanpa spasi berlebih) agar
  /// "Budi  Santoso" dan "budi santoso" diperlakukan sama saat verifikasi.
  static String normalisasiJawaban(String raw) {
    return raw
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Kode pemulihan dinormalisasi: huruf besar & tanpa pemisah, sehingga
  /// "8d2k9-7qw3x" tetap cocok dengan "8D2K97QW3X".
  static String normalisasiKodePemulihan(String raw) {
    return raw.toUpperCase().trim().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Baca status pemulihan PIN untuk layar Lupa PIN / Ubah PIN.
  Future<RecoveryInfo> recoveryInfo() async {
    final String? q1 = await _db.getSetting(_kRecoveryQ1);
    final String? q2 = await _db.getSetting(_kRecoveryQ2);
    final String? codeHash = await _db.getSetting(_kRecoveryCode);
    final int attempts =
        int.tryParse(await _db.getSetting(_kRecoveryAttempts) ?? '') ?? 0;
    final int lockedMinutes = await recoveryLockedRemainingMinutes();
    return RecoveryInfo(
      q1: (q1 != null && q1.isNotEmpty) ? q1 : null,
      q2: (q2 != null && q2.isNotEmpty) ? q2 : null,
      codeSet: codeHash != null && codeHash.isNotEmpty,
      attempts: attempts,
      lockedRemainingMinutes: lockedMinutes,
    );
  }

  /// Simpan / perbarui data pemulihan PIN.
  ///
  /// • [q1][q2] teks pertanyaan; [a1][a2] jawaban plain (langsung di-hash).
  /// • [recoveryCode] bila tidak null → aktifkan/perbarui kode pemulihan;
  ///   plain text TIDAK disimpan, hanya hash.
  Future<void> saveRecoverySetup({
    required String q1,
    required String a1,
    required String q2,
    required String a2,
    String? recoveryCode,
  }) async {
    final Map<String, Object?>? user = await _activeUser();
    if (user == null) {
      throw StateError('Pengguna aktif tidak ditemukan.');
    }
    final String salt = user['username'] as String;

    await _db.setSetting(
        _kRecoveryQ1, q1.trim());
    await _db.setSetting(_kRecoveryQ2, q2.trim());
    await _db.setSetting(
        _kRecoveryA1, DBHelper.hashPassword(normalisasiJawaban(a1), salt));
    await _db.setSetting(
        _kRecoveryA2, DBHelper.hashPassword(normalisasiJawaban(a2), salt));
    if (recoveryCode != null && recoveryCode.trim().isNotEmpty) {
      await _db.setSetting(
          _kRecoveryCode, DBHelper.hashPassword(normalisasiKodePemulihan(recoveryCode), salt));
    }
    // Data baru → bersihkan hitungan percobaan.
    await _db.setSetting(_kRecoveryAttempts, '0');
    await _db.setSetting(_kRecoveryLockedUntil, '');
  }

  /// Sisa menit terkunci (0 = tidak terkunci) setelah percobaan salah.
  Future<int> recoveryLockedRemainingMinutes() async {
    final String? raw = await _db.getSetting(_kRecoveryLockedUntil);
    if (raw == null || raw.isEmpty) return 0;
    final DateTime? until = DateTime.tryParse(raw);
    if (until == null) return 0;
    final Duration sisa = until.difference(DateTime.now());
    if (sisa.isNegative) return 0;
    return sisa.inMinutes + 1;
  }

  /// Catat satu kegagalan verifikasi jawaban/kode. Setelah [maxRecoveryAttempts]
  /// kegagalan, pemulihan dikunci selama [recoveryLockMinutes] menit.
  Future<void> _registerRecoveryFailure() async {
    final int total =
        int.tryParse(await _db.getSetting(_kRecoveryAttempts) ?? '') ?? 0;
    final int berikut = total + 1;
    if (berikut >= maxRecoveryAttempts) {
      final DateTime until =
          DateTime.now().add(const Duration(minutes: recoveryLockMinutes));
      await _db.setSetting(
          _kRecoveryLockedUntil, until.toIso8601String());
      await _db.setSetting(_kRecoveryAttempts, '0');
    } else {
      await _db.setSetting(_kRecoveryAttempts, berikut.toString());
    }
  }

  Future<void> _clearRecoveryLock() async {
    await _db.setSetting(_kRecoveryAttempts, '0');
    await _db.setSetting(_kRecoveryLockedUntil, '');
  }

  /// Reset PIN UNTUK jalur pertanyaan keamanan: verifikasi + penulisan PIN
  /// baru dilakukan atomik agar jawaban tidak bisa "dicoba" tanpa menuntaskan
  /// reset (komposisi keamanan jalur pemulihan).
  Future<ResetPinOutcome> resetPinViaQuestions({
    required String answer1,
    required String answer2,
    required String newPin,
  }) async {
    final int lockedMinutes = await recoveryLockedRemainingMinutes();
    if (lockedMinutes > 0) {
      return ResetPinOutcome(
        RecoveryError.terkunci,
        lockedMinutes: lockedMinutes,
      );
    }
    final Map<String, Object?>? user = await _activeUser();
    if (user == null) return const ResetPinOutcome(RecoveryError.gagal);

    final String salt = user['username'] as String;
    final String? q1 = await _db.getSetting(_kRecoveryQ1);
    final String? q2 = await _db.getSetting(_kRecoveryQ2);
    final String? a1 = await _db.getSetting(_kRecoveryA1);
    final String? a2 = await _db.getSetting(_kRecoveryA2);
    if (q1 == null || q2 == null || a1 == null || a2 == null ||
        a1.isEmpty || a2.isEmpty) {
      return const ResetPinOutcome(RecoveryError.belumDisetup);
    }

    // Jawaban baris pertama & kedua WAJIB keduanya cocok.
    final bool ok = DBHelper.verifyPassword(
            normalisasiJawaban(answer1), salt, a1) &&
        DBHelper.verifyPassword(normalisasiJawaban(answer2), salt, a2);
    if (!ok) {
      await _registerRecoveryFailure();
      return const ResetPinOutcome(RecoveryError.jawabanSalah);
    }

    final bool reset = await _applyNewPin(newPin, userId: user['id'] as int,
        via: 'pertanyaan keamanan');
    if (!reset) return const ResetPinOutcome(RecoveryError.gagal);
    await _clearRecoveryLock();
    return const ResetPinOutcome(RecoveryError.none);
  }

  /// Reset PIN untuk jalur kode pemulihan: verifikasi + reset atomik.
  Future<ResetPinOutcome> resetPinViaRecoveryCode({
    required String recoveryCode,
    required String newPin,
  }) async {
    final int lockedMinutes = await recoveryLockedRemainingMinutes();
    if (lockedMinutes > 0) {
      return ResetPinOutcome(
        RecoveryError.terkunci,
        lockedMinutes: lockedMinutes,
      );
    }
    final Map<String, Object?>? user = await _activeUser();
    if (user == null) return const ResetPinOutcome(RecoveryError.gagal);

    final String salt = user['username'] as String;
    final String? codeHash = await _db.getSetting(_kRecoveryCode);
    if (codeHash == null || codeHash.isEmpty) {
      return const ResetPinOutcome(RecoveryError.belumDisetup);
    }

    if (!DBHelper.verifyPassword(
        normalisasiKodePemulihan(recoveryCode), salt, codeHash)) {
      await _registerRecoveryFailure();
      return const ResetPinOutcome(RecoveryError.kodeSalah);
    }

    final bool reset = await _applyNewPin(newPin, userId: user['id'] as int,
        via: 'kode pemulihan');
    if (!reset) return const ResetPinOutcome(RecoveryError.gagal);
    await _clearRecoveryLock();
    return const ResetPinOutcome(RecoveryError.none);
  }

  /// Tulis PIN baru untuk pengguna aktif (dipanggil SETELAH verifikasi
  /// pemulihan berhasil) + catat jejak audit.
  Future<bool> _applyNewPin(String newPin,
      {required int userId, required String via}) async {
    if (newPin.isEmpty ||
        newPin.length < AppConstants.pinMinLength ||
        newPin.length > AppConstants.pinMaxLength) {
      return false;
    }
    final Map<String, Object?>? row = await _db.queryOne(
      DBHelper.tblUsers,
      where: 'id = ?',
      whereArgs: <Object?>[userId],
    );
    if (row == null) return false;
    final String username = row['username'] as String;

    await _db.update(
      DBHelper.tblUsers,
      <String, Object?>{
        'password_hash': DBHelper.hashPassword(newPin, username),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[userId],
    );
    await _db.logAudit(
      userId: userId,
      action: 'reset_pin',
      entityTable: DBHelper.tblUsers,
      entityId: userId,
      description: 'Reset PIN lewat Lupa PIN (via $via)',
    );
    return true;
  }
}
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
/// Kunci prefs untuk sesi login.
class SessionPrefs {
  static const String loggedInUserId = 'logged_in_user_id';
  static const String loggedInUsername = 'logged_in_username';
  static const String loggedInFullName = 'logged_in_full_name';
}

/// Provider status autentikasi pengguna.
class SessionProvider extends ChangeNotifier {
  final AuthRepository authRepository;

  SessionProvider({required this.authRepository});

  UserModel? _user;
  bool _isLoggingIn = false;
  String? _errorMessage;
  bool _hasTriedRestore = false;
  bool _isPinSet = false;

  UserModel? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoggingIn => _isLoggingIn;
  String? get errorMessage => _errorMessage;

  /// Apakah bendahara sudah membuat PIN (false → tampilkan layar Buat PIN).
  bool get isPinSet => _isPinSet;

  /// Apakah app dibuka langsung ke dashboard setelah masuk.
  bool get hasTriedRestore => _hasTriedRestore;

  /// Mulai sesi login memverifikasi PIN yang dimasukkan pengguna.
  Future<bool> loginWithPin(String pin) async {
    _isLoggingIn = true;
    _errorMessage = null;
    notifyListeners();

    final UserModel? user = await authRepository.loginWithPin(pin);

    _isLoggingIn = false;
    if (user == null) {
      _errorMessage = 'PIN salah. Coba lagi.';
      notifyListeners();
      return false;
    }

    await _persistSession(user);
    _user = user;
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  /// Buat PIN pertama saat pengguna baru membuka aplikasi, lalu langsung masuk.
  ///
  /// Hanya bisa dipanggil sekali — setelah ada PIN, `setInitialPin` menolak.
  Future<bool> createInitialPin(String pin) async {
    final bool created = await authRepository.setInitialPin(pin);
    if (!created) {
      _errorMessage = 'Gagal membuat PIN. Coba lagi.';
      notifyListeners();
      return false;
    }
    _isPinSet = true;
    return loginWithPin(pin);
  }

  // ------------------------------------------------------------------
  // PEMULIHAN PIN (LUPA PIN)
  // ------------------------------------------------------------------

  /// Baca status pemulihan: pertanyaan keamanan & kode pemulihan tersedia?
  Future<RecoveryInfo> recoveryInfo() => authRepository.recoveryInfo();

  /// Simpan data pemulihan dari sheet setup (dipanggil saat sudah login).
  Future<void> activateRecovery({
    required String q1,
    required String a1,
    required String q2,
    required String a2,
    String? recoveryCode,
  }) {
    return authRepository.saveRecoverySetup(
      q1: q1,
      a1: a1,
      q2: q2,
      a2: a2,
      recoveryCode: recoveryCode,
    );
  }

  /// Reset PIN lewat pertanyaan keamanan. Jika berhasil, pengguna LANGSUNG
  /// masuk aplikasi (identitas sudah terbukti lewat jawaban).
  Future<ResetPinOutcome> resetPinViaQuestions({
    required String answer1,
    required String answer2,
    required String newPin,
  }) async {
    final ResetPinOutcome outcome = await authRepository.resetPinViaQuestions(
      answer1: answer1,
      answer2: answer2,
      newPin: newPin,
    );
    if (outcome.ok) {
      await loginWithPin(newPin);
    }
    return outcome;
  }

  /// Reset PIN lewat kode pemulihan. Jika berhasil, langsung masuk aplikasi.
  Future<ResetPinOutcome> resetPinViaRecoveryCode({
    required String recoveryCode,
    required String newPin,
  }) async {
    final ResetPinOutcome outcome =
        await authRepository.resetPinViaRecoveryCode(
      recoveryCode: recoveryCode,
      newPin: newPin,
    );
    if (outcome.ok) {
      await loginWithPin(newPin);
    }
    return outcome;
  }

  /// Dipanggil saat startup. Aplikasi selalu mewajibkan PIN setiap kali
  /// dibuka, sehingga sesi lama sengaja TIDAK dipulihkan. Sesi tersimpan
  /// dibersihkan agar bendahara tidak bisa masuk tanpa memasukkan PIN lagi.
  ///
  /// [isPinSet] ikut dibaca untuk memutuskan layar Buat PIN atau Login.
  Future<void> restoreSession() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(SessionPrefs.loggedInUserId);
      await prefs.remove(SessionPrefs.loggedInUsername);
      await prefs.remove(SessionPrefs.loggedInFullName);
      _user = null;
      _isPinSet = await authRepository.isPinSet();
    } finally {
      _hasTriedRestore = true;
      notifyListeners();
    }
  }

  Future<void> _persistSession(UserModel user) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(SessionPrefs.loggedInUserId, user.id ?? -1);
    await prefs.setString(SessionPrefs.loggedInUsername, user.username);
    await prefs.setString(SessionPrefs.loggedInFullName, user.fullName);
  }

  /// Keluar dari aplikasi & hapus sesi lokal.
  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(SessionPrefs.loggedInUserId);
    _user = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Bersihkan pesan error di form login.
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}

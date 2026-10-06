import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/db_helper.dart';
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

  UserModel? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoggingIn => _isLoggingIn;
  String? get errorMessage => _errorMessage;

  /// Apakah app dibuka langsung ke dashboard setelah masuk.
  bool get hasTriedRestore => _hasTriedRestore;

  /// Mulai sesi login.
  Future<bool> login(String username, String password) async {
    _isLoggingIn = true;
    _errorMessage = null;
    notifyListeners();

    final UserModel? user = await authRepository.login(
      username: username,
      password: password,
    );

    _isLoggingIn = false;
    if (user == null) {
      _errorMessage = 'Username atau kata sandi salah.';
      notifyListeners();
      return false;
    }

    await _persistSession(user);
    _user = user;
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  /// Pulihkan sesi dari penyimpanan lokal (dipanggil saat startup).
  Future<void> restoreSession() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt(SessionPrefs.loggedInUserId);
      if (userId != null) {
        final Map<String, Object?>? row = await DBHelper.instance.queryOne(
          DBHelper.tblUsers,
          where: 'id = ? AND is_active = 1',
          whereArgs: <Object?>[userId],
        );
        if (row == null) {
          await prefs.remove(SessionPrefs.loggedInUserId);
        } else {
          _user = UserModel.fromMap(row);
        }
      }
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

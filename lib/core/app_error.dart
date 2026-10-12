import 'package:flutter/foundation.dart';

/// Error aplikasi yang sudah diformat untuk ditampilkan ke pengguna.
/// Repository membungkus error mentah (DatabaseException, FileSystemException,
/// dll) menjadi [_AppException] agar UI cukup menampilkan [message].
class AppException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() => message;
}

/// Pesan error default bila penyebabnya tidak dikenali.
String pesanErrorUmum(Object error, String konteks) {
  if (error is AppException) return error.message;
  return '$konteks gagal: $error';
}

/// Dilempar saat nominal pengeluaran akan membuat saldo kas minus
/// (pengeluaran melebihi pemasukan). UI menangkap ini untuk menampilkan
/// pesan "tidak bisa melanjutkan pengeluaran".
class SaldoInsufficientException implements Exception {
  /// Nominal pengeluaran yang ditolak.
  final int amount;

  /// Saldo tersedia saat ini (pemasukan − pengeluaran, tidak negatif).
  final int saldo;

  const SaldoInsufficientException({required this.amount, required this.saldo});

  String get message =>
      'Tidak bisa melanjutkan pengeluaran. Nominal melebihi pemasukan '
      '(saldo tersedia $saldo).';

  @override
  String toString() => message;
}

/// Helper global untuk repository: jalankan operasi (database maupun berkas)
/// dengan try/catch + pencatatan log, lalu lempar [AppException] berisi pesan
/// yang ramah pengguna bila error tidak dikenali.
class DbSafe {
  DbSafe._();

  /// Jalankan [action]; bila gagal, log lalu lempar [AppException].
  static Future<T> run<T>(
    Future<T> Function() action,
    String konteks, {
    String? pesan,
  }) async {
    try {
      return await action();
    } catch (error, stack) {
      debugPrint('[$konteks] $error\n$stack');
      if (error is AppException) rethrow;
      throw AppException(
        pesan ?? pesanErrorUmum(error, konteks),
        cause: error,
        stackTrace: stack,
      );
    }
  }

  /// Sama seperti [run] tetapi mengembalikan [fallback] bila gagal
  /// (untuk operasi baca yang boleh menampilkan data kosong).
  static Future<T> runOr<T>(
    Future<T> Function() action,
    String konteks,
    T fallback, {
    void Function(Object error)? onError,
  }) async {
    try {
      return await action();
    } catch (error, stack) {
      debugPrint('[$konteks] $error\n$stack');
      onError?.call(error);
      return fallback;
    }
  }
}

/// Helper untuk membungkus error apa pun menjadi [AppException].
extension AppErrorX on Object {
  Never asAppError(String konteks, {String? pesan}) {
    throw AppException(pesan ?? pesanErrorUmum(this, konteks),
        cause: this, stackTrace: StackTrace.current);
  }
}

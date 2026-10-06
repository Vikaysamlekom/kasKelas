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

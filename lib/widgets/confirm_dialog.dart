import 'package:flutter/material.dart';

import '../core/app_error.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../repositories/siswa_repo.dart';

/// Dialog konfirmasi hapus dengan pesan dinamis.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Ya, Hapus',
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title, style: AppText.title.copyWith(fontSize: 17)),
        content: Text(message, style: AppText.body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Tampilkan informasi hasil delete/deaktivasi (dari DeleteResult).
void showDeleteResult(BuildContext context, DeleteResult result, String nama) {
  final String message;
  if (result.isDeleted) {
    message = '$nama berhasil dihapus.';
  } else if (result.isDeactivated) {
    message = '$nama tidak bisa dihapus karena masih digunakan.\n'
        'Statusnya diubah menjadi nonaktif.';
  } else {
    message = '$nama tidak dapat dihapus.';
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Jalankan [aksi] dan pastikan kegagalan selalu terlihat oleh pengguna.
///
/// Tanpa pembungkus ini, error database membuat dialog langsung tertutup
/// tanpa pesan apa pun sehingga tombol terlihat "tidak merespons".
Future<void> jalankanAksi(BuildContext context, Future<void> Function() aksi,
    {required String konteks}) async {
  try {
    await aksi();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pesanErrorUmum(e, konteks))),
    );
  }
}
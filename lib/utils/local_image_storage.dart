import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Simpan gambar hasil picker agar tetap tersedia setelah aplikasi ditutup.
///
/// Di Android, gambar disalin ke folder dokumen aplikasi dan path file
/// dikembalikan. Di web, tidak ada filesystem permanen; gambar disimpan sebagai
/// data URL base64 di kolom database sehingga tetap ikut backup JSON.
Future<String> persistPickedImage(
  XFile picked, {
  required String folder,
  required String prefix,
}) async {
  if (kIsWeb) {
    final Uint8List bytes = await picked.readAsBytes();
    final String? pickedMime = picked.mimeType;
    final String mime = (pickedMime != null && pickedMime.startsWith('image/'))
        ? pickedMime
        : 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  final Directory docs = await getApplicationDocumentsDirectory();
  final Directory dir = Directory(p.join(docs.path, folder));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final String ext = p.extension(picked.path);
  final String fileName =
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}'
      '${ext.isEmpty ? '.jpg' : ext}';
  final File saved = await File(picked.path)
      .copy(p.join(dir.path, fileName));
  return saved.path;
}

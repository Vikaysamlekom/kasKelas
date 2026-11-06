import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// True bila [path] berupa data URL gambar (dipakai di web).
bool isStoredImageDataUrl(String? path) {
  return path != null && path.startsWith('data:image/');
}

/// Decode data URL gambar menjadi byte. Null bila bukan data URL valid.
Uint8List? decodeStoredImageDataUrl(String path) {
  if (!isStoredImageDataUrl(path)) return null;
  final int separator = path.indexOf(',');
  if (separator < 0) return null;
  try {
    return base64Decode(path.substring(separator + 1));
  } catch (_) {
    return null;
  }
}

/// ImageProvider untuk path foto yang tersimpan.
///
/// - Data URL (web) → [MemoryImage]
/// - Path file (Android) → [FileImage]
/// - Path file di web / data URL rusak → null (jangan membuat `File` di web)
ImageProvider<Object>? storedImageProvider(String? path) {
  if (path == null || path.isEmpty) return null;

  final Uint8List? bytes = decodeStoredImageDataUrl(path);
  if (bytes != null) return MemoryImage(bytes);

  if (kIsWeb) return null;
  return FileImage(File(path));
}

/// Widget gambar untuk foto yang tersimpan (foto nota / lampiran).
///
/// Menampilkan [fallback] bila path kosong, file tidak ditemukan, atau
/// gambar tidak bisa didecode. Tidak pernah membuat `File` di web.
class StoredImage extends StatelessWidget {
  final String? path;
  final double? height;
  final double? width;
  final BoxFit fit;
  final Widget? fallback;

  const StoredImage({
    super.key,
    required this.path,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object>? provider = storedImageProvider(path);
    if (provider == null) {
      return fallback ?? const SizedBox.shrink();
    }

    return Image(
      image: provider,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (
        BuildContext _,
        Object _,
        StackTrace? _,
      ) =>
          fallback ?? const SizedBox.shrink(),
    );
  }
}

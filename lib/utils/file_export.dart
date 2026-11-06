import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Bagikan atau unduh byte file.
///
/// Di web, `share_plus` memakai Web Share API bila tersedia. Jika browser
/// tidak mendukung berbagi file, `downloadFallbackEnabled` membuat file
/// otomatis diunduh. Di Android helper ini tetap aman dipakai, tetapi
/// pemanggil biasanya hanya memakainya pada cabang `kIsWeb`.
Future<void> shareOrDownloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? text,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[
        XFile.fromData(bytes, mimeType: mimeType),
      ],
      fileNameOverrides: <String>[fileName],
      text: text,
      downloadFallbackEnabled: true,
    ),
  );
}

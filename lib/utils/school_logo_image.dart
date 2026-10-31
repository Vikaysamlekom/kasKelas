import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

ImageProvider<Object> schoolLogoImageProvider(String path) {
  if (path.startsWith('data:image/')) {
    final int separator = path.indexOf(',');
    return MemoryImage(base64Decode(path.substring(separator + 1)));
  }
  return FileImage(File(path));
}

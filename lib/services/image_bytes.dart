import 'dart:io';

import 'package:flutter/services.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/widgets/app_image.dart';

/// AI에게 함께 보낼 수 있는 사진 크기 상한. 넘으면 사진 없이 글만 보낸다.
const int maxChatImageBytes = 4 * 1024 * 1024;

/// asset 또는 기기 파일 사진을 AI 요청용으로 읽는다. 없거나 너무 크면 null.
Future<ChatImage?> loadChatImage(String path) async {
  if (path.isEmpty) return null;
  try {
    final Uint8List bytes = isAssetPath(path)
        ? (await rootBundle.load(path)).buffer.asUint8List()
        : await File(path).readAsBytes();
    if (bytes.isEmpty || bytes.length > maxChatImageBytes) return null;
    final bool png = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
    return (bytes: bytes, mimeType: png ? 'image/png' : 'image/jpeg');
  } catch (_) {
    return null;
  }
}

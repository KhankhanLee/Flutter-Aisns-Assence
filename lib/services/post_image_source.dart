import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/utils/format.dart';

/// 페르소나가 새 게시물에 쓸 사진을 만든다. 만들 수 없으면 예외를 던지고,
/// 그때는 페르소나의 기존 사진 중에서 고른다.
abstract class PostImageSource {
  bool get isEnabled;

  /// [scene] 장면의 사진을 만들어 기기에 저장하고 파일 경로를 돌려준다.
  Future<String> create({required Persona persona, required String scene});
}

/// Gemini 이미지 모델로 프로필 사진 속 인물을 유지한 채 새 사진을 만든다.
class GeminiPostImageSource implements PostImageSource {
  final GeminiService _gemini;
  final bool Function() _enabled;

  GeminiPostImageSource(this._gemini, {required bool Function() enabled})
    : _enabled = enabled;

  @override
  bool get isEnabled => _enabled() && _gemini.isConfigured;

  @override
  Future<String> create({
    required Persona persona,
    required String scene,
  }) async {
    final String? avatar = persona.avatarPath;
    final Uint8List? reference = avatar == null
        ? null
        : (await rootBundle.load(avatar)).buffer.asUint8List();
    final Uint8List bytes = await _gemini.generateImage(
      reference: reference,
      prompt:
          '인스타그램 피드에 올릴 자연스러운 스마트폰 사진을 만들어줘. 장면: $scene\n'
          '${reference == null ? '' : '참고 사진 속 인물과 같은 사람이 등장해야 해. '}'
          '실제 사진처럼 자연스럽게, 글자·워터마크 없이, 정사각형 구도로.',
    );

    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${docs.path}/ai_posts');
    await dir.create(recursive: true);
    final bool png = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
    final File file = File(
      '${dir.path}/${newId(persona.id)}.${png ? 'png' : 'jpg'}',
    );
    await file.writeAsBytes(bytes);
    return file.path;
  }
}

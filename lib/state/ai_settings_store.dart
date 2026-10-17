import 'package:flutter/foundation.dart';
import 'package:assence/models/chat_message.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/local_store.dart';

/// 앱 안에서 입력한 Gemini API 키와 사용할 모델.
///
/// 키를 빌드 옵션(`--dart-define`) 없이 폰에서 바로 넣을 수 있게 한다.
/// 저장된 키가 있으면 빌드 옵션의 키보다 우선한다.
class AiSettingsStore extends ChangeNotifier {
  static const String _keyStorageKey = 'gemini_api_key';
  static const String _modelStorageKey = 'gemini_model';
  static const String _imageStorageKey = 'ai_image_generation';

  final LocalStore _local;
  final GeminiService _gemini;
  bool _testing = false;
  bool _imageGeneration = false;

  AiSettingsStore(this._local, this._gemini) {
    final Object? savedKey = _local.readJson(_keyStorageKey);
    final Object? savedModel = _local.readJson(_modelStorageKey);
    if (savedKey is String && savedKey.isNotEmpty) {
      _gemini.configure(
        apiKey: savedKey,
        model: savedModel is String ? savedModel : null,
      );
    } else if (savedModel is String) {
      _gemini.configure(apiKey: _gemini.apiKey, model: savedModel);
    }
    _imageGeneration = _local.readJson(_imageStorageKey) == true;
    // 키를 쓰다가 모델을 자동으로 바꾸면 다음 실행에도 그 모델을 쓴다.
    _gemini.onModelChanged = (String model) {
      _local.writeJson(_modelStorageKey, model);
      notifyListeners();
    };
  }

  bool get isConfigured => _gemini.isConfigured;
  bool get isTesting => _testing;
  String get model => _gemini.model;

  /// AI 친구가 새 게시물 사진을 Gemini로 직접 만들지 여부.
  /// 이미지 모델은 유료일 수 있어 기본값은 꺼짐 (꺼져 있으면 기존 사진 중에서 고른다).
  bool get imageGeneration => _imageGeneration;

  set imageGeneration(bool value) {
    _imageGeneration = value;
    _local.writeJson(_imageStorageKey, value);
    notifyListeners();
  }

  /// 화면 표시용으로 가린 키 (예: AIza••••••1234).
  String get maskedKey {
    final String key = _gemini.apiKey;
    if (key.length <= 8) return key.isEmpty ? '' : '••••';
    return '${key.substring(0, 4)}••••••${key.substring(key.length - 4)}';
  }

  /// 키로 쓸 수 있는 모델을 찾고 짧은 메시지로 실제 응답까지 확인한 뒤 저장한다.
  /// 실패하면 이전 설정으로 되돌리고 [GeminiException]을 던진다.
  /// 성공하면 테스트 응답 문장을 돌려준다.
  Future<String> saveAndTest(String apiKey) async {
    final String key = apiKey.trim();
    if (key.isEmpty) {
      throw const GeminiException(GeminiErrorKind.missingApiKey, 'empty');
    }
    final String previousKey = _gemini.apiKey;
    final String previousModel = _gemini.model;
    final void Function(String)? onModelChanged = _gemini.onModelChanged;

    _testing = true;
    notifyListeners();
    // 테스트가 끝나기 전에는 모델 변경을 저장하지 않는다.
    _gemini.onModelChanged = null;
    try {
      _gemini.configure(apiKey: key);
      await _gemini.resolveModel();
      final String reply = await _gemini.generateReply(
        persona: '너는 SNS 앱의 연결 테스트 도우미야. 한 문장으로 짧게 인사해.',
        history: <ChatMessage>[
          ChatMessage(role: ChatMessage.userRole, text: '연결 테스트'),
        ],
      );
      await _local.writeJson(_keyStorageKey, key);
      await _local.writeJson(_modelStorageKey, _gemini.model);
      return reply;
    } on GeminiException {
      _gemini.configure(apiKey: previousKey, model: previousModel);
      _gemini.model = previousModel;
      rethrow;
    } finally {
      _gemini.onModelChanged = onModelChanged;
      _testing = false;
      notifyListeners();
    }
  }

  /// 앱에 저장한 키를 지운다. 빌드 옵션으로 넣은 키가 있으면 그 키로 돌아간다.
  Future<void> clearKey() async {
    await _local.writeJson(_keyStorageKey, '');
    _gemini.configure(apiKey: const String.fromEnvironment('GEMINI_API_KEY'));
    notifyListeners();
  }
}

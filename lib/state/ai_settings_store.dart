import 'package:flutter/foundation.dart';
import 'package:assence/models/chat_message.dart';
import 'package:assence/services/claude_client.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/utils/humanize.dart';

/// 앱 안에서 입력한 AI 키와 모델, 그리고 지금 쓸 AI(Gemini 또는 Claude).
///
/// 키를 빌드 옵션(`--dart-define`) 없이 폰에서 바로 넣을 수 있게 한다.
/// 저장된 Gemini 키가 있으면 빌드 옵션의 키보다 우선한다.
class AiSettingsStore extends ChangeNotifier {
  static const String _keyStorageKey = 'gemini_api_key';
  static const String _modelStorageKey = 'gemini_model';
  static const String _imageStorageKey = 'ai_image_generation';
  static const String _providerStorageKey = 'ai_provider';
  static const String _claudeKeyStorageKey = 'claude_api_key';
  static const String _claudeModelStorageKey = 'claude_model';

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
    final Object? claudeKey = _local.readJson(_claudeKeyStorageKey);
    if (claudeKey is String) _gemini.claude.apiKey = claudeKey;
    final Object? claudeModel = _local.readJson(_claudeModelStorageKey);
    if (claudeModel is String && claudeModel.isNotEmpty) {
      _gemini.claude.model = claudeModel;
    }
    if (_local.readJson(_providerStorageKey) == AiProvider.claude.name) {
      _gemini.provider = AiProvider.claude;
    }
    _imageGeneration = _local.readJson(_imageStorageKey) == true;
    // 키를 쓰다가 모델을 자동으로 바꾸면 다음 실행에도 그 모델을 쓴다.
    _gemini.onModelChanged = (String model) {
      _local.writeJson(_modelStorageKey, model);
      notifyListeners();
    };
  }

  /// 지금 앱에서 쓰는 AI.
  AiProvider get provider => _gemini.provider;

  /// 지금 쓰는 AI의 키가 있는지.
  bool get isConfigured => _gemini.isConfigured;
  bool hasKey(AiProvider p) => _gemini.hasKey(p);
  bool get isTesting => _testing;

  /// 지금 쓰는 AI의 모델 (화면 표시용).
  String get model => modelOf(provider);

  String modelOf(AiProvider p) => switch (p) {
    AiProvider.gemini => _gemini.model,
    AiProvider.claude => _gemini.claude.model,
  };

  /// 기본 Gemini 모델이 한도에 걸려 다른 모델을 잠시 쓰는 중이면 그 모델, 아니면 null.
  String? get fallbackModel {
    if (provider != AiProvider.gemini) return null;
    final String active = _gemini.activeGeminiModel;
    return active == _gemini.model ? null : active;
  }

  /// AI 친구가 새 게시물 사진을 Gemini로 직접 만들지 여부.
  /// 이미지 모델은 유료일 수 있어 기본값은 꺼짐 (꺼져 있으면 기존 사진 중에서 고른다).
  /// 사진 생성은 Gemini만 지원해서 Gemini 키가 있어야 동작한다.
  bool get imageGeneration => _imageGeneration;

  set imageGeneration(bool value) {
    _imageGeneration = value;
    _local.writeJson(_imageStorageKey, value);
    notifyListeners();
  }

  /// 화면 표시용으로 가린 지금 AI의 키 (예: AIza••••••1234).
  String get maskedKey => maskedKeyOf(provider);

  String maskedKeyOf(AiProvider p) {
    final String key = switch (p) {
      AiProvider.gemini => _gemini.apiKey,
      AiProvider.claude => _gemini.claude.apiKey,
    };
    if (key.length <= 8) return key.isEmpty ? '' : '••••';
    return '${key.substring(0, 4)}••••••${key.substring(key.length - 4)}';
  }

  /// 앱에서 쓸 AI를 바꾼다.
  Future<void> selectProvider(AiProvider p) async {
    if (_gemini.provider == p) return;
    _gemini.provider = p;
    await _local.writeJson(_providerStorageKey, p.name);
    notifyListeners();
  }

  Future<void> setClaudeModel(String id) async {
    _gemini.claude.model = id;
    await _local.writeJson(_claudeModelStorageKey, id);
    notifyListeners();
  }

  /// 키로 짧은 메시지를 보내 실제 응답까지 확인한 뒤 저장하고, 그 AI를 쓰도록 바꾼다.
  /// Gemini는 그 키로 쓸 수 있는 모델도 찾는다.
  /// 실패하면 이전 설정으로 되돌리고 [GeminiException]을 던진다.
  /// 성공하면 테스트 응답 문장을 돌려준다.
  Future<String> saveAndTest(
    String apiKey, {
    AiProvider provider = AiProvider.gemini,
  }) async {
    final String key = apiKey.trim();
    if (key.isEmpty) {
      throw const GeminiException(GeminiErrorKind.missingApiKey, 'empty');
    }
    final AiProvider previousProvider = _gemini.provider;
    final String previousKey = _gemini.apiKey;
    final String previousModel = _gemini.model;
    final String previousClaudeKey = _gemini.claude.apiKey;
    final void Function(String)? onModelChanged = _gemini.onModelChanged;

    _testing = true;
    notifyListeners();
    // 테스트가 끝나기 전에는 모델 변경을 저장하지 않는다.
    _gemini.onModelChanged = null;
    _gemini.provider = provider;
    try {
      if (provider == AiProvider.gemini) {
        _gemini.configure(apiKey: key);
        await _gemini.resolveModel();
      } else {
        _gemini.claude.apiKey = key;
      }
      final String reply = await _gemini.generateReply(
        persona: '너는 SNS 앱의 연결 테스트 도우미야. 한 문장으로 짧게 인사해.',
        history: <ChatMessage>[
          ChatMessage(role: ChatMessage.userRole, text: '연결 테스트'),
        ],
        // 이 키 자체를 확인하는 요청이라 다른 AI·모델로 넘어가지 않게 한다.
        background: true,
      );
      if (provider == AiProvider.gemini) {
        await _local.writeJson(_keyStorageKey, key);
        await _local.writeJson(_modelStorageKey, _gemini.model);
      } else {
        await _local.writeJson(_claudeKeyStorageKey, key);
      }
      await _local.writeJson(_providerStorageKey, provider.name);
      return extractReply(reply);
    } on GeminiException {
      _gemini.provider = previousProvider;
      _gemini.configure(apiKey: previousKey, model: previousModel);
      _gemini.model = previousModel;
      _gemini.claude.apiKey = previousClaudeKey;
      rethrow;
    } finally {
      _gemini.onModelChanged = onModelChanged;
      _testing = false;
      notifyListeners();
    }
  }

  /// 앱에 저장한 키를 지운다. Gemini는 빌드 옵션으로 넣은 키가 있으면 그 키로 돌아간다.
  Future<void> clearKey({AiProvider provider = AiProvider.gemini}) async {
    if (provider == AiProvider.gemini) {
      await _local.writeJson(_keyStorageKey, '');
      _gemini.configure(apiKey: const String.fromEnvironment('GEMINI_API_KEY'));
    } else {
      await _local.writeJson(_claudeKeyStorageKey, '');
      _gemini.claude.apiKey = '';
    }
    notifyListeners();
  }

  /// Claude 모델 목록 (설정 화면용).
  List<ClaudeModelOption> get claudeModels => ClaudeClient.models;
}

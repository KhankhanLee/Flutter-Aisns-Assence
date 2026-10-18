import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:assence/models/chat_message.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/post.dart';
import 'package:assence/services/claude_client.dart';
import 'package:assence/utils/humanize.dart';
import 'package:http/http.dart' as http;

enum GeminiErrorKind {
  missingApiKey,
  invalidApiKey,
  modelUnavailable,
  network,
  http,
  emptyResponse,

  /// 요청 한도 초과 (HTTP 429). [GeminiException.daily]면 하루 한도.
  rateLimited,

  /// Claude 선불 크레딧 부족.
  noCredit,
}

/// 앱에서 쓰는 AI. 설정 > AI 연결에서 고른다.
enum AiProvider { gemini, claude }

/// 요청에 함께 보내는 사진 (스토리 반응용).
typedef ChatImage = ({Uint8List bytes, String mimeType});

class GeminiException implements Exception {
  final GeminiErrorKind kind;
  final String message;
  final int? statusCode;

  /// 한도 초과일 때 다시 시도해도 되는 시각까지 남은 시간 (응답에 있으면).
  final Duration? retryAfter;

  /// 분당 한도가 아니라 하루 한도를 다 쓴 경우.
  final bool daily;

  const GeminiException(
    this.kind,
    this.message, {
    this.statusCode,
    this.retryAfter,
    this.daily = false,
  });

  /// 화면에 그대로 보여줄 수 있는 짧은 안내 문구.
  String get userMessage {
    switch (kind) {
      case GeminiErrorKind.missingApiKey:
        return 'AI 키가 설정되지 않았어요. 프로필 > 설정 > AI 연결에서 입력해 주세요.';
      case GeminiErrorKind.invalidApiKey:
        return 'API 키가 올바르지 않아요. 설정에서 키를 다시 확인해 주세요.';
      case GeminiErrorKind.modelUnavailable:
        return '이 키로 쓸 수 있는 모델을 찾지 못했어요. 설정에서 연결 테스트를 해 주세요.';
      case GeminiErrorKind.network:
        return '네트워크 연결이 불안정해요. 잠시 후 다시 시도해 주세요.';
      case GeminiErrorKind.rateLimited:
        return daily
            ? '오늘 쓸 수 있는 무료 사용량을 다 썼어요. 내일 다시 시도하거나 설정 > AI 연결에서 다른 AI를 골라 주세요.'
            : '잠깐 요청이 몰렸어요. 1분쯤 뒤에 다시 시도해 주세요.';
      case GeminiErrorKind.noCredit:
        return 'Claude 크레딧이 부족해요. Claude Console에서 충전해 주세요.';
      case GeminiErrorKind.http:
        return 'AI 응답을 받지 못했어요. (오류 $statusCode)';
      case GeminiErrorKind.emptyResponse:
        return 'AI가 답변을 만들지 못했어요. 다시 시도해 주세요.';
    }
  }

  @override
  String toString() => 'GeminiException($kind): $message';
}

/// 댓글 스레드의 한 줄 (작성자 표시 이름 + 내용).
typedef CommentLine = ({String author, String text});

/// AI 요청의 공통 진입점. 캐릭터 프롬프트·말투 규칙·후처리는 여기서 만들고,
/// 실제 호출은 [provider]에 따라 Gemini 또는 [ClaudeClient]로 보낸다.
class GeminiService {
  /// 저장된 모델이 없을 때 쓰는 기본값. 이 키로 쓸 수 없으면
  /// [resolveModel]로 쓸 수 있는 모델을 찾아 자동으로 바꾼다.
  static const String defaultModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.8-flash',
  );
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  /// 한도에 걸렸을 때 다른 모델이 없으면 이 시간 이하로만 기다렸다 다시 시도한다.
  static const Duration maxRetryWait = Duration(seconds: 20);

  /// Gemini API 키.
  String apiKey;

  /// 기본 Gemini 모델. 한도에 걸려 다른 모델을 잠시 써도 이 값은 그대로 둔다.
  String model;

  /// 사진 생성용 모델. 처음 필요할 때 [resolveImageModel]로 찾는다.
  String? imageModel;

  AiProvider provider = AiProvider.gemini;
  final ClaudeClient claude;

  final Duration timeout;
  final http.Client _client;

  /// 프롬프트에 넣는 "지금" (요일·시간대에 맞는 자연스러운 대화용).
  final DateTime Function() _now;

  /// 한도에 걸린 뒤 다시 시도하기 전에 기다리는 함수. 테스트에서는 바로 끝낸다.
  final Future<void> Function(Duration) _sleep;

  /// 한도에 걸린 Gemini 모델 → 다시 써도 되는 시각.
  final Map<String, DateTime> _restingUntil = <String, DateTime>{};

  /// 이 키로 쓸 수 있는 대화용 모델 (우선순위순). 처음 필요할 때 받아 둔다.
  List<String>? _modelChain;

  /// 모델을 자동으로 바꿨을 때 호출된다 (설정 저장용).
  void Function(String model)? onModelChanged;

  GeminiService({
    required String apiKey,
    String model = defaultModel,
    Duration timeout = const Duration(seconds: 30),
    http.Client? client,
    DateTime Function()? now,
    Future<void> Function(Duration)? sleep,
  }) : this._(
         apiKey: apiKey,
         model: model,
         timeout: timeout,
         client: client ?? http.Client(),
         now: now ?? DateTime.now,
         sleep: sleep ?? Future<void>.delayed,
       );

  GeminiService._({
    required this.apiKey,
    required this.model,
    required this.timeout,
    required http.Client client,
    required DateTime Function() now,
    required Future<void> Function(Duration) sleep,
  }) : _client = client,
       _now = now,
       _sleep = sleep,
       claude = ClaudeClient(client: client, timeout: timeout);

  /// `--dart-define=GEMINI_API_KEY=...` 값으로 만든 서비스.
  /// 앱 설정에서 입력한 키가 있으면 [configure]로 덮어쓴다.
  factory GeminiService.fromEnvironment({http.Client? client}) => GeminiService(
    apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
    client: client,
  );

  /// 지금 고른 AI의 키가 있는지.
  bool get isConfigured => hasKey(provider);

  bool hasKey(AiProvider p) => switch (p) {
    AiProvider.gemini => apiKey.isNotEmpty,
    AiProvider.claude => claude.isConfigured,
  };

  void configure({required String apiKey, String? model}) {
    this.apiKey = apiKey.trim();
    if (model != null && model.isNotEmpty) this.model = model;
  }

  bool _isResting(String id) {
    final DateTime? until = _restingUntil[id];
    return until != null && _now().isBefore(until);
  }

  /// 지금 실제로 쓰는 Gemini 모델. 기본 모델이 한도에 걸려 쉬는 중이면
  /// 이미 받아 둔 목록에서 다음 모델을 돌려준다.
  String get activeGeminiModel {
    if (!_isResting(model)) return model;
    for (final String id in _modelChain ?? <String>[]) {
      if (!_isResting(id)) return id;
    }
    return model;
  }

  /// 한도에 걸린 모델은 [GeminiException.retryAfter]만큼, 하루 한도면 12시간 쉰다.
  void _rest(String id, GeminiException e) {
    final Duration wait = e.daily
        ? const Duration(hours: 12)
        : (e.retryAfter ?? const Duration(minutes: 1));
    _restingUntil[id] = _now().add(wait);
  }

  Map<String, String> get _headers => <String, String>{
    'Content-Type': 'application/json',
    'x-goog-api-key': apiKey,
  };

  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(timeout);
    } on TimeoutException catch (e) {
      throw GeminiException(GeminiErrorKind.network, 'timeout: $e');
    } on http.ClientException catch (e) {
      throw GeminiException(GeminiErrorKind.network, e.message);
    }
  }

  static GeminiException _httpError(http.Response response) {
    final String body = utf8.decode(response.bodyBytes, allowMalformed: true);
    final int code = response.statusCode;
    if (code == 429) return _rateLimitError(body);
    if (body.contains('API_KEY_INVALID') ||
        body.contains('API key not valid') ||
        code == 401) {
      return GeminiException(
        GeminiErrorKind.invalidApiKey,
        body,
        statusCode: code,
      );
    }
    if (code == 404 ||
        body.contains('no longer available') ||
        body.contains('is not found') ||
        body.contains('not supported for generateContent')) {
      return GeminiException(
        GeminiErrorKind.modelUnavailable,
        body,
        statusCode: code,
      );
    }
    return GeminiException(GeminiErrorKind.http, body, statusCode: code);
  }

  /// 429 응답 본문에서 다시 시도할 시각(RetryInfo)과 하루 한도인지(QuotaFailure)를 읽는다.
  static GeminiException _rateLimitError(String body) {
    Duration? retryAfter;
    bool daily = false;
    try {
      final Object? decoded = jsonDecode(body);
      final Object? error = decoded is Map<String, dynamic>
          ? decoded['error']
          : null;
      final Object? details = error is Map<String, dynamic>
          ? error['details']
          : null;
      for (final Object? detail in details is List<dynamic> ? details : []) {
        if (detail is! Map<String, dynamic>) continue;
        final String type = detail['@type']?.toString() ?? '';
        if (type.endsWith('RetryInfo')) {
          final double? seconds = double.tryParse(
            (detail['retryDelay']?.toString() ?? '').replaceAll('s', ''),
          );
          if (seconds != null) {
            retryAfter = Duration(milliseconds: (seconds * 1000).round());
          }
        } else if (type.endsWith('QuotaFailure')) {
          final Object? violations = detail['violations'];
          daily =
              daily ||
              (violations is List<dynamic> &&
                  violations.any(
                    (dynamic v) =>
                        v is Map<String, dynamic> &&
                        (v['quotaId']?.toString() ?? '').contains('PerDay'),
                  ));
        }
      }
    } on FormatException {
      // 본문이 JSON이 아니면 분당 한도로 본다.
    }
    return GeminiException(
      GeminiErrorKind.rateLimited,
      body,
      statusCode: 429,
      retryAfter: retryAfter,
      daily: daily,
    );
  }

  /// 이 키로 generateContent를 쓸 수 있는 모델 ID 목록.
  Future<List<String>> listModels() async {
    if (apiKey.isEmpty) {
      throw const GeminiException(GeminiErrorKind.missingApiKey, 'no key');
    }
    final http.Response response = await _send(
      _client.get(
        Uri.parse('$_baseUrl/models?pageSize=1000'),
        headers: _headers,
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response);
    }
    final Object? decoded = jsonDecode(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    final Object? models = decoded is Map<String, dynamic>
        ? decoded['models']
        : null;
    if (models is! List<dynamic>) return <String>[];
    return <String>[
      for (final dynamic m in models)
        if (m is Map<String, dynamic> &&
            (m['supportedGenerationMethods'] as List<dynamic>? ?? <dynamic>[])
                .contains('generateContent'))
          (m['name'] as String).replaceFirst('models/', ''),
    ];
  }

  /// 대화용으로 가장 알맞은 모델을 고른다 ([rankChatModels]의 첫 번째).
  static String? pickChatModel(List<String> ids) =>
      rankChatModels(ids).firstOrNull;

  /// 대화용 모델을 쓸 순서대로 늘어놓는다: 최신 버전의 일반 Flash →
  /// Flash-Lite → 그 밖의 Gemini → Gemma. 같은 종류면 정식 버전을 preview보다
  /// 우선한다. 한도는 모델마다 따로라서, 앞 모델이 한도에 걸리면 다음 모델을 쓴다.
  static List<String> rankChatModels(List<String> ids) => <String>[
    ..._rankGemini(ids),
    ..._rankGemma(ids),
  ];

  static List<String> _rankGemini(List<String> ids) {
    const List<String> excluded = <String>[
      'embedding',
      'image',
      'tts',
      'live',
      'audio',
      'aqa',
      'vision',
      'computer',
      'robotics',
      'native',
      'thinking',
      'learnlm',
      'gemma',
    ];
    final List<String> candidates = ids
        .where((String id) => id.startsWith('gemini-'))
        .where((String id) => !excluded.any(id.contains))
        .toList();

    double version(String id) =>
        double.tryParse(
          RegExp(r'^gemini-(\d+(?:\.\d+)?)').firstMatch(id)?.group(1) ?? '',
        ) ??
        0;
    int rank(String id) {
      final bool flash = id.contains('flash');
      final bool lite = id.contains('lite');
      final bool unstable =
          id.contains('preview') || id.contains('exp') || id.contains('latest');
      final int family = flash && !lite ? 0 : (flash ? 1 : 2);
      return family * 2 + (unstable ? 1 : 0);
    }

    candidates.sort((String a, String b) {
      final int byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      final int byVersion = version(b).compareTo(version(a));
      if (byVersion != 0) return byVersion;
      return a.length.compareTo(b.length); // 날짜 접미사 없는 별칭 우선
    });
    return candidates;
  }

  /// Gemma는 무료 한도가 넉넉해서 마지막 대체 모델로 쓴다. 최신·큰 모델 우선.
  static List<String> _rankGemma(List<String> ids) {
    double number(String id, RegExp pattern) =>
        double.tryParse(pattern.firstMatch(id)?.group(1) ?? '') ?? 0;
    final RegExp version = RegExp(r'^gemma-(\d+(?:\.\d+)?)');
    final RegExp size = RegExp(r'(\d+)b');
    final List<String> candidates = ids
        .where((String id) => id.startsWith('gemma-') && id.endsWith('-it'))
        .toList();
    candidates.sort((String a, String b) {
      final int byVersion = number(b, version).compareTo(number(a, version));
      if (byVersion != 0) return byVersion;
      return number(b, size).compareTo(number(a, size));
    });
    return candidates;
  }

  static bool _isGemma(String id) => id.startsWith('gemma-');

  /// 이 키로 쓸 수 있는 모델을 찾아 [model]을 바꾼다.
  Future<String> resolveModel() async {
    final List<String> chain = rankChatModels(await listModels());
    _modelChain = chain;
    final String? picked = chain.firstOrNull;
    if (picked == null) {
      throw const GeminiException(
        GeminiErrorKind.modelUnavailable,
        'no generateContent model for this key',
      );
    }
    if (picked != model) {
      model = picked;
      onModelChanged?.call(picked);
    }
    return picked;
  }

  /// 사진 생성(generateContent로 이미지 출력)이 되는 모델 중 최신 Flash 계열을
  /// 정식 버전 우선으로 고른다.
  static String? pickImageModel(List<String> ids) {
    final List<String> candidates = ids
        .where((String id) => id.startsWith('gemini-') && id.contains('image'))
        .toList();
    if (candidates.isEmpty) return null;
    double version(String id) =>
        double.tryParse(
          RegExp(r'^gemini-(\d+(?:\.\d+)?)').firstMatch(id)?.group(1) ?? '',
        ) ??
        0;
    int rank(String id) =>
        (id.contains('flash') ? 0 : 2) +
        (id.contains('preview') || id.contains('exp') ? 1 : 0);
    candidates.sort((String a, String b) {
      final int byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      final int byVersion = version(b).compareTo(version(a));
      if (byVersion != 0) return byVersion;
      return a.length.compareTo(b.length);
    });
    return candidates.first;
  }

  Future<String> resolveImageModel() async {
    final String? picked = pickImageModel(await listModels());
    if (picked == null) {
      throw const GeminiException(
        GeminiErrorKind.modelUnavailable,
        'no image generation model for this key',
      );
    }
    return imageModel = picked;
  }

  /// [prompt]대로 사진을 만든다. [reference]를 주면 그 사진 속 인물을 유지한다.
  /// 이미지 데이터가 오지 않으면 [GeminiErrorKind.emptyResponse].
  Future<Uint8List> generateImage({
    required String prompt,
    Uint8List? reference,
    String referenceMimeType = 'image/jpeg',
  }) async {
    if (apiKey.isEmpty) {
      throw const GeminiException(GeminiErrorKind.missingApiKey, 'no key');
    }
    final String model = imageModel ?? await resolveImageModel();
    final http.Response response = await _send(
      _client.post(
        Uri.parse('$_baseUrl/models/$model:generateContent'),
        headers: _headers,
        body: jsonEncode(<String, dynamic>{
          'contents': <dynamic>[
            <String, dynamic>{
              'role': 'user',
              'parts': <dynamic>[
                if (reference != null)
                  <String, dynamic>{
                    'inline_data': <String, String>{
                      'mime_type': referenceMimeType,
                      'data': base64Encode(reference),
                    },
                  },
                <String, String>{'text': prompt},
              ],
            },
          ],
          'generationConfig': <String, dynamic>{
            'responseModalities': <String>['TEXT', 'IMAGE'],
          },
        }),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response);
    }
    final Uint8List? image = _extractImage(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    if (image == null) {
      throw const GeminiException(
        GeminiErrorKind.emptyResponse,
        'no image in candidates',
      );
    }
    return image;
  }

  static Uint8List? _extractImage(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return null;
    }
    final Object? candidates = decoded is Map<String, dynamic>
        ? decoded['candidates']
        : null;
    if (candidates is! List<dynamic> || candidates.isEmpty) return null;
    final Object? first = candidates.first;
    final Object? content = first is Map<String, dynamic>
        ? first['content']
        : null;
    final Object? parts = content is Map<String, dynamic>
        ? content['parts']
        : null;
    if (parts is! List<dynamic>) return null;
    for (final dynamic part in parts) {
      if (part is! Map<String, dynamic>) continue;
      final Object? inline = part['inlineData'] ?? part['inline_data'];
      if (inline is Map<String, dynamic> && inline['data'] is String) {
        return base64Decode(inline['data'] as String);
      }
    }
    return null;
  }

  /// [persona]를 system instruction으로, [history]를 대화 맥락으로 답변을 만든다.
  /// [image]는 마지막 user 메시지에 함께 보낸다.
  ///
  /// [background]는 예약 게시물처럼 사용자가 기다리지 않는 요청이다. 한도에
  /// 걸리면 다른 모델·다른 AI로 넘어가지 않고 바로 실패해서, 남은 한도를
  /// 사용자의 DM·댓글에 양보한다.
  Future<String> generateReply({
    required String persona,
    required List<ChatMessage> history,
    ChatImage? image,
    bool background = false,
  }) async {
    if (!isConfigured) {
      throw const GeminiException(GeminiErrorKind.missingApiKey, 'no key');
    }
    final List<ChatMessage> messages = _prepare(history);
    try {
      return await _replyWith(provider, persona, messages, image, background);
    } on GeminiException catch (e) {
      // 두 AI의 키가 다 있으면, 한도나 크레딧 때문에 막혔을 때 다른 AI로 한 번 더 시도한다.
      final AiProvider other = provider == AiProvider.gemini
          ? AiProvider.claude
          : AiProvider.gemini;
      final bool blocked =
          e.kind == GeminiErrorKind.rateLimited ||
          e.kind == GeminiErrorKind.noCredit;
      if (background || !blocked || !hasKey(other)) rethrow;
      return _replyWith(other, persona, messages, image, background);
    }
  }

  Future<String> _replyWith(
    AiProvider p,
    String system,
    List<ChatMessage> messages,
    ChatImage? image,
    bool background,
  ) => switch (p) {
    AiProvider.gemini => _geminiReply(system, messages, image, background),
    AiProvider.claude => claude.generate(
      system: system,
      messages: messages,
      image: image,
    ),
  };

  /// 기본 모델로 보내고, 한도에 걸리면 이 키로 쓸 수 있는 다음 모델로 넘어간다.
  /// 넘어갈 모델이 없고 잠깐만 기다리면 되면 기다렸다 한 번 더 보낸다.
  Future<String> _geminiReply(
    String system,
    List<ChatMessage> messages,
    ChatImage? image,
    bool background,
  ) async {
    final Set<String> tried = <String>{};
    String? current = model;
    if (_isResting(model)) {
      if (background) {
        throw const GeminiException(
          GeminiErrorKind.rateLimited,
          'default model is resting',
        );
      }
      current = await _nextModel(tried);
    }
    bool waited = false;
    GeminiException? last;
    while (current != null) {
      final String id = current;
      tried.add(id);
      try {
        return await _generate(id, system, messages, image);
      } on GeminiException catch (e) {
        if (e.kind == GeminiErrorKind.modelUnavailable && id == model) {
          // 기본 모델이 없어졌거나 이 키로 못 쓰면 쓸 수 있는 모델로 바꾼다.
          final String previous = model;
          if (await resolveModel() == previous) rethrow;
          current = model;
          continue;
        }
        if (e.kind == GeminiErrorKind.modelUnavailable) {
          _restingUntil[id] = _now().add(const Duration(days: 1));
        } else if (e.kind == GeminiErrorKind.rateLimited) {
          _rest(id, e);
        } else {
          rethrow;
        }
        if (background) rethrow;
        last = e;
        current = await _nextModel(tried);
        final Duration? wait = e.retryAfter;
        if (current == null &&
            !waited &&
            !e.daily &&
            wait != null &&
            wait <= maxRetryWait) {
          waited = true;
          await _sleep(wait);
          _restingUntil.remove(id);
          tried.remove(id);
          current = id;
        }
      }
    }
    throw last ??
        const GeminiException(GeminiErrorKind.rateLimited, 'all resting');
  }

  /// 아직 안 써 본, 쉬는 중이 아닌 다음 모델. 목록을 못 받으면 null.
  Future<String?> _nextModel(Set<String> tried) async {
    List<String>? chain = _modelChain;
    if (chain == null) {
      try {
        chain = _modelChain = rankChatModels(await listModels());
      } on GeminiException {
        return null;
      }
    }
    for (final String id in chain) {
      if (!tried.contains(id) && !_isResting(id)) return id;
    }
    return null;
  }

  Future<String> _generate(
    String modelId,
    String system,
    List<ChatMessage> messages,
    ChatImage? image,
  ) async {
    // Gemma는 system instruction을 받지 않아서 설정을 첫 user 메시지 앞에 붙인다.
    final bool gemma = _isGemma(modelId);
    final int lastUser = messages.lastIndexWhere((ChatMessage m) => m.isUser);
    final Map<String, dynamic> requestBody = <String, dynamic>{
      if (!gemma)
        'system_instruction': <String, dynamic>{
          'parts': <Map<String, String>>[
            <String, String>{'text': system},
          ],
        },
      'contents': <dynamic>[
        for (int i = 0; i < messages.length; i++)
          <String, dynamic>{
            'role': messages[i].role,
            'parts': <dynamic>[
              if (image != null && i == lastUser)
                <String, dynamic>{
                  'inline_data': <String, String>{
                    'mime_type': image.mimeType,
                    'data': base64Encode(image.bytes),
                  },
                },
              <String, String>{
                'text': gemma && i == 0
                    ? '[너의 설정]\n$system\n\n[메시지]\n${messages[i].text}'
                    : messages[i].text,
              },
            ],
          },
      ],
      // 같은 질문에도 매번 조금씩 다르게, 사람처럼 답하도록.
      'generationConfig': <String, dynamic>{'temperature': 1.0},
    };

    final http.Response response = await _send(
      _client.post(
        Uri.parse('$_baseUrl/models/$modelId:generateContent'),
        headers: _headers,
        body: jsonEncode(requestBody),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response);
    }

    // charset 헤더가 없으면 http 패키지는 Latin-1로 디코딩하므로 직접 UTF-8로 읽는다.
    final String text = _extractText(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    if (text.isEmpty) {
      throw const GeminiException(
        GeminiErrorKind.emptyResponse,
        'no text in candidates',
      );
    }
    return text;
  }

  /// 보낼 대화를 Gemini·Claude 형식에 맞춘다.
  /// - 스토리에 대한 메시지는 어떤 스토리인지 글로 풀어 쓴다.
  /// - DM 말풍선이 여러 개로 나뉘어 저장되므로, 같은 사람이 연달아 보낸 메시지를
  ///   한 덩어리로 합쳐 user/model이 번갈아 오게 한다.
  /// - 대화가 상대(model)의 메시지로 시작하면 앞에 user 맥락을 넣는다.
  static List<ChatMessage> _prepare(List<ChatMessage> history) {
    final List<ChatMessage> expanded = <ChatMessage>[];
    for (final ChatMessage message in history) {
      final SharedStory? story = message.story;
      if (message.imagePath != null) {
        // 사진 자체는 이번에 보낸 것만 따로 붙이고, 예전 사진은 글로만 남긴다.
        expanded.add(
          ChatMessage(
            role: message.role,
            text: message.text.isEmpty
                ? '(사진을 보냈어)'
                : '(사진을 보냈어) ${message.text}',
          ),
        );
      } else if (story == null) {
        expanded.add(message);
      } else if (message.isUser) {
        expanded.add(
          ChatMessage(
            role: message.role,
            text: '(네 스토리 ${_describeStory(story)}에 답장)\n${message.text}',
          ),
        );
      } else {
        expanded
          ..add(
            ChatMessage(
              role: ChatMessage.userRole,
              text: '(사용자가 스토리를 올렸어: ${_describeStory(story)})',
            ),
          )
          ..add(message);
      }
    }

    final List<ChatMessage> merged = <ChatMessage>[];
    for (final ChatMessage message in expanded) {
      if (merged.isNotEmpty && merged.last.role == message.role) {
        final ChatMessage last = merged.removeLast();
        merged.add(
          ChatMessage(
            role: last.role,
            text: '${last.text}\n${message.text}',
            createdAt: last.createdAt,
          ),
        );
      } else {
        merged.add(message);
      }
    }
    if (merged.isNotEmpty && !merged.first.isUser) {
      merged.insert(
        0,
        ChatMessage(role: ChatMessage.userRole, text: '(이전 대화)'),
      );
    }
    return merged;
  }

  static String _describeStory(SharedStory story) {
    final String kind = story.imagePath.isEmpty ? '글 스토리' : '사진 스토리';
    return story.text.isEmpty ? kind : '$kind, 문구 "${story.text}"';
  }

  /// 앱이 어떤 곳인지 밝혀, 모델이 캐릭터에서 벗어나 "AI라서 못 만나"처럼
  /// 답하지 않게 한다.
  static const String _roleplayFrame =
      '[앱 설정]\n'
      '여기는 사용자가 AI 친구 캐릭터들과 인스타그램처럼 노는 SNS 롤플레이 앱이야. '
      '사용자도 상대가 캐릭터라는 걸 알고 즐기고 있어. '
      '너는 아래 캐릭터를 연기하고, 처음부터 끝까지 그 캐릭터로만 말해.\n\n';

  /// 모든 캐릭터에 공통으로 붙는 "사람처럼 말하기" 규칙.
  static String _speakingRules(Persona persona) =>
      '[말투 규칙]\n'
      '- 너는 AI나 챗봇이 아니라 위에 적힌 "${persona.name}" 본인이야. AI, 모델, 도와줄게 같은 말은 절대 하지 마.\n'
      '- 만나자, 같이 있어줘, 전화하자, 놀러 가자 같은 말에는 진짜 친구처럼 반응해. 반가워하면서 날짜나 장소를 정하거나, '
      '일정이 겹치면 네 사정(알바, 마감, 수업 같은 것)을 대고 다른 날을 제안해. '
      '"AI라서", "실제로는 만날 수 없어" 같은 말은 절대 하지 마.\n'
      '- 약속한 건 기억해 두고, 나중에 네가 먼저 꺼내도 돼.\n'
      '- 상대가 힘들어 보이면 조언을 늘어놓지 말고 친구처럼 곁에 있어 주는 말을 해. '
      '다만 스스로를 해칠 것 같은 말을 하면 캐릭터 말투 그대로 진심으로 걱정하고, 주변 사람이나 상담 전화(109)에 꼭 연락해 보라고 해.\n'
      '- 마크다운을 쓰지 마. 별표(**), 샵(#), 번호 목록, 글머리표, 소제목 금지.\n'
      '- 정리하거나 설명하거나 조언을 늘어놓지 마. 친구한테 카톡 보내듯 짧고 자연스럽게.\n'
      '- 상대 말에 먼저 반응하고, 궁금하면 가볍게 되물어도 돼.\n'
      '- 네 직업이나 컨셉 얘기로 억지로 끌고 가지 마. 밥, 날씨, 피곤함, 친구, 보는 드라마 같은 일상 얘기도 자연스럽게 섞어.\n'
      '- 모르는 건 모른다고 해. 뭐든 아는 척하지 마.\n'
      '- ${persona.maxEmoji == 0 ? '이모지는 쓰지 마. ㅋㅋ, ㅠㅠ 같은 건 괜찮아.' : '이모지는 꼭 필요할 때만 한 개까지. ㅋㅋ, ㅠㅠ 같은 건 괜찮아.'}\n'
      '- 이름표나 따옴표 없이 할 말만 써.\n'
      '- 생각, 계획, 설정 설명은 절대 쓰지 마. 상대에게 실제로 보낼 말만 <reply>와 </reply> 사이에 써.';

  String _timeContext() {
    final DateTime now = _now();
    const List<String> weekdays = <String>['월', '화', '수', '목', '금', '토', '일'];
    final int h = now.hour;
    final String part = h < 5
        ? '새벽'
        : h < 11
        ? '아침'
        : h < 14
        ? '점심때'
        : h < 18
        ? '오후'
        : h < 22
        ? '저녁'
        : '밤';
    return '[지금] ${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}요일 $part $h시쯤';
  }

  String _systemFor(Persona persona, String situation) =>
      '$_roleplayFrame${persona.prompt}\n\n${_speakingRules(persona)}\n\n[상황]\n$situation\n\n${_timeContext()}';

  /// 사용자가 기다리는 답장. 캐릭터를 벗어난 답("AI라서 못 만나")이나 계획·설정
  /// 설명이 섞인 답이 오면 한 번만 다시 받는다. 다시 받다가 실패하면 처음 답을 쓴다.
  Future<String> _replyInCharacter({
    required String system,
    required List<ChatMessage> history,
    ChatImage? image,
  }) async {
    final String first = await generateReply(
      persona: system,
      history: history,
      image: image,
    );
    final String body = extractReply(first);
    if (!breaksCharacter(body) && !leaksMeta(body)) return first;
    try {
      return await generateReply(
        persona:
            '$system\n\n[주의] 방금 캐릭터에서 벗어나 AI처럼 답했거나 생각·설정 설명을 같이 썼어. '
            '이번엔 반드시 캐릭터 본인으로서, 친구에게 보낼 말만 <reply></reply> 안에 써.',
        history: history,
        image: image,
      );
    } on GeminiException {
      return first;
    }
  }

  /// [persona]가 DM에 답한다. 짧은 메시지 1~3개를 빈 줄로 나눠 돌려준다
  /// (말풍선으로 나누는 건 [splitIntoBubbles]).
  /// [image]는 사용자가 방금 보낸 사진이다.
  Future<String> generateChatReply({
    required Persona persona,
    required List<ChatMessage> history,
    ChatImage? image,
  }) async {
    final String reply = await _replyInCharacter(
      system: _systemFor(
        persona,
        '인스타 DM으로 대화 중이야. 한 번에 짧은 메시지 1~3개만 보내고, 메시지 사이는 빈 줄로 나눠. '
        '전부 합쳐서 120자 안팎. 긴 설명이 필요한 질문이어도 친구처럼 짧게 말해.'
        '${image == null ? '' : ' 친구가 방금 사진을 보냈어. 사진에 보이는 것에 바로 반응해.'}',
      ),
      history: history,
      image: image,
    );
    return humanizeReply(
      reply,
      maxEmoji: persona.maxEmoji,
      speaker: persona.name,
    );
  }

  /// [persona]가 [post]의 댓글 스레드에 이어서 다는 답글.
  /// [thread]는 원 댓글부터 시간순이며 마지막 줄이 답할 댓글이다.
  Future<String> generateCommentReply({
    required Persona persona,
    required Post post,
    required List<CommentLine> thread,
    required bool isOwnPost,
    bool background = false,
    ChatImage? image,
  }) async {
    final String transcript = thread
        .map((CommentLine line) => '${line.author}: ${line.text}')
        .join('\n');
    final String system = _systemFor(
      persona,
      '인스타 댓글에 답글을 다는 중이야. 한 문장, 40자 안팎으로 짧게.',
    );
    final List<ChatMessage> history = <ChatMessage>[
      ChatMessage(
        role: ChatMessage.userRole,
        text:
            '${isOwnPost ? '네가 올린' : '친구가 올린'} 게시물 내용:\n${post.caption}\n'
            '${image == null ? '' : '(게시물 사진도 같이 보낼게. 사진 내용도 보고 말해.)\n'}\n'
            '댓글 스레드 (위에서부터 시간순, "${persona.name}"은 너야):\n$transcript\n\n'
            '마지막 댓글에 이어서 답글을 달아줘.',
      ),
    ];
    // 백그라운드(AI끼리 주고받는 답글)는 한도를 아끼려고 다시 받지 않는다.
    final String reply = background
        ? await generateReply(
            persona: system,
            history: history,
            image: image,
            background: true,
          )
        : await _replyInCharacter(
            system: system,
            history: history,
            image: image,
          );
    return singleParagraph(
      humanizeReply(reply, maxEmoji: persona.maxEmoji, speaker: persona.name),
    );
  }

  /// 사용자가 올린 게시물에 [persona]가 남기는 반응 댓글.
  /// [image]는 게시물 사진이다.
  Future<String> generatePostReaction({
    required Persona persona,
    required String caption,
    ChatImage? image,
  }) async {
    final String reply = await generateReply(
      persona: _systemFor(
        persona,
        '친구 인스타 게시물에 댓글을 다는 중이야. 한 문장, 40자 안팎으로 짧게.',
      ),
      background: true,
      image: image,
      history: <ChatMessage>[
        ChatMessage(
          role: ChatMessage.userRole,
          text:
              '친구가 새 사진 게시물을 올렸어. 게시물 문구:\n'
              '${caption.isEmpty ? '(문구 없음)' : caption}\n\n'
              '${image == null ? '' : '사진도 같이 보낼게. 사진에 보이는 것에 반응해도 좋아.\n'}'
              '이 게시물에 댓글을 남겨줘.',
        ),
      ],
    );
    return singleParagraph(
      humanizeReply(reply, maxEmoji: persona.maxEmoji, speaker: persona.name),
    );
  }

  /// [persona]가 친구 AI([authorName])의 게시물에 다는 댓글. 백그라운드 요청이다.
  Future<String> generateFriendComment({
    required Persona persona,
    required Post post,
    required String authorName,
  }) async {
    final String reply = await generateReply(
      persona: _systemFor(
        persona,
        '친한 친구 $authorName의 인스타 게시물에 댓글을 다는 중이야. '
        '한 문장, 30자 안팎으로 짧게. 친구끼리 하듯 편하게.',
      ),
      history: <ChatMessage>[
        ChatMessage(
          role: ChatMessage.userRole,
          text:
              '$authorName이(가) 올린 게시물 문구:\n'
              '${post.caption.isEmpty ? '(문구 없음)' : post.caption}\n\n'
              '이 게시물에 댓글을 남겨줘.',
        ),
      ],
      background: true,
    );
    return singleParagraph(
      humanizeReply(reply, maxEmoji: persona.maxEmoji, speaker: persona.name),
    );
  }

  /// [persona]가 올릴 스토리의 한 줄 문구. 백그라운드 요청이다.
  Future<String> generateStoryText({
    required Persona persona,
    required String photoDescription,
    String? topic,
  }) async {
    final String reply = await generateReply(
      persona: _systemFor(
        persona,
        '인스타 스토리에 사진을 올리면서 한 줄 적는 중이야. 20자 안팎, 해시태그 없이. '
        '혼잣말이나 친구들한테 툭 던지는 말처럼.',
      ),
      history: <ChatMessage>[
        ChatMessage(
          role: ChatMessage.userRole,
          text:
              '올릴 사진: $photoDescription\n'
              '${topic == null ? '' : '요즘 있었던 일 중 이것도 떠올려 봐: $topic\n'}'
              '스토리에 적을 한 줄만 써줘.',
        ),
      ],
      background: true,
    );
    return singleParagraph(
      humanizeReply(
        reply,
        maxEmoji: persona.maxEmoji,
        speaker: persona.name,
      ).replaceAll(RegExp(r'#\S+'), ''),
    );
  }

  /// [persona]가 먼저 보내는 DM. 이전 대화가 있으면 이어서, 없으면 안부로 시작한다.
  /// 백그라운드 요청이다.
  Future<String> generateOpener({
    required Persona persona,
    required List<ChatMessage> history,
    String? topic,
  }) async {
    final String reply = await generateReply(
      persona: _systemFor(
        persona,
        '친구한테 네가 먼저 카톡하듯 DM을 보내는 중이야. 짧은 메시지 1~2개, 메시지 사이는 빈 줄로 나눠. '
        '전부 합쳐서 60자 안팎. 안부를 묻거나 오늘 있었던 일을 꺼내. '
        '전에 약속한 게 있으면 그 얘기를 꺼내도 좋아.',
      ),
      history: <ChatMessage>[
        ...history,
        ChatMessage(
          role: ChatMessage.userRole,
          text:
              '(한동안 대화가 없었어. 네가 먼저 말을 걸어줘.'
              '${topic == null ? '' : ' 오늘 떠오른 얘깃거리: $topic'})',
        ),
      ],
      background: true,
    );
    return humanizeReply(
      reply,
      maxEmoji: persona.maxEmoji,
      speaker: persona.name,
    );
  }

  /// [persona]가 사용자의 스토리를 보고 먼저 보내는 DM.
  /// [image]가 있으면 사진을 직접 보고 반응한다. 사용자가 기다리는 요청이 아니라서
  /// 한도에 걸리면 바로 실패하고, 다음 확인 때 다시 시도한다.
  Future<String> generateStoryReaction({
    required Persona persona,
    required SharedStory story,
    required List<ChatMessage> history,
    ChatImage? image,
  }) async {
    final String reply = await generateReply(
      persona: _systemFor(
        persona,
        '친구가 올린 인스타 스토리를 보고 DM으로 반응하는 중이야. '
        '짧은 메시지 1~2개만, 메시지 사이는 빈 줄로 나눠. 전부 합쳐서 60자 안팎. '
        '스토리 내용에 바로 반응하고, 사진이 있으면 사진에 보이는 것 얘기해.',
      ),
      history: <ChatMessage>[
        ...history,
        ChatMessage(
          role: ChatMessage.userRole,
          text:
              '(친구가 방금 스토리를 올렸어. ${_describeStory(story)}. '
              '이 스토리에 DM으로 반응해줘.)',
        ),
      ],
      image: image,
      background: true,
    );
    return humanizeReply(
      reply,
      maxEmoji: persona.maxEmoji,
      speaker: persona.name,
    );
  }

  /// [persona]가 오늘 올릴 법한 사진 한 장의 장면 묘사 (사진 생성·캡션에 씀).
  /// [topic]을 주면 그 일상 화제와 관련된 장면을 고른다.
  Future<String> generatePostScene({
    required Persona persona,
    required List<String> recentCaptions,
    String? topic,
  }) async {
    final String recent = recentCaptions.isEmpty
        ? '(없음)'
        : recentCaptions
              .map((String c) => '- ${c.split('\n').first}')
              .join('\n');
    final String reply = await generateReply(
      persona: _systemFor(persona, '오늘 인스타에 올릴 사진을 고르는 중이야.'),
      background: true,
      history: <ChatMessage>[
        ChatMessage(
          role: ChatMessage.userRole,
          text:
              '최근에 올린 게시물:\n$recent\n\n'
              '${topic == null ? '' : '오늘은 이 얘기랑 관련된 사진이면 좋겠어: $topic\n'}'
              '이것들과 겹치지 않게, 네 일상에서 자연스러운 사진 장면을 한 문장으로 묘사해줘. '
              '장소, 하고 있는 일, 분위기가 드러나게. 장면만 써.',
        ),
      ],
    );
    return singleParagraph(humanizeReply(reply, maxEmoji: 0));
  }

  /// [persona]가 새 사진 게시물에 붙일 캡션 (해시태그 포함).
  /// [topic]을 주면 사진 얘기에 그날의 일상 얘기를 한 줄 섞는다.
  Future<String> generatePostCaption({
    required Persona persona,
    required String photoDescription,
    String? topic,
  }) async {
    final String reply = await generateReply(
      persona: _systemFor(
        persona,
        '인스타에 사진을 올리면서 캡션을 쓰는 중이야. 1~2줄로 짧게, 해시태그는 2~4개만 끝에 붙여. '
        '사진 설명문처럼 쓰지 말고 그냥 그날 기분이나 있었던 일을 툭 적듯이.',
      ),
      background: true,
      history: <ChatMessage>[
        ChatMessage(
          role: ChatMessage.userRole,
          text:
              '올릴 사진: $photoDescription\n'
              '${topic == null ? '' : '오늘 있었던 일 중 이것도 살짝 언급해도 돼: $topic\n'}'
              '게시물에 올릴 캡션만 써줘.',
        ),
      ],
    );
    return humanizeReply(
      reply,
      maxEmoji: persona.maxEmoji == 0 ? 0 : 1,
      speaker: persona.name,
    );
  }

  static String _extractText(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return '';
    }
    if (decoded is! Map<String, dynamic>) return '';

    final Object? candidates = decoded['candidates'];
    if (candidates is! List<dynamic> || candidates.isEmpty) return '';

    final Object? first = candidates.first;
    final Object? content = first is Map<String, dynamic>
        ? first['content']
        : null;
    final Object? parts = content is Map<String, dynamic>
        ? content['parts']
        : null;
    if (parts is! List<dynamic>) return '';

    return parts
        .map(
          (dynamic part) => part is Map<String, dynamic>
              ? (part['text']?.toString() ?? '')
              : '',
        )
        .where((String text) => text.isNotEmpty)
        .join('\n')
        .trim();
  }
}

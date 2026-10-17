import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:assence/models/chat_message.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/post.dart';
import 'package:http/http.dart' as http;

enum GeminiErrorKind {
  missingApiKey,
  invalidApiKey,
  modelUnavailable,
  network,
  http,
  emptyResponse,
}

class GeminiException implements Exception {
  final GeminiErrorKind kind;
  final String message;
  final int? statusCode;

  const GeminiException(this.kind, this.message, {this.statusCode});

  /// 화면에 그대로 보여줄 수 있는 짧은 안내 문구.
  String get userMessage {
    switch (kind) {
      case GeminiErrorKind.missingApiKey:
        return 'Gemini API 키가 설정되지 않았어요. 프로필 > 설정 > Gemini API 키에서 입력해 주세요.';
      case GeminiErrorKind.invalidApiKey:
        return 'API 키가 올바르지 않아요. 설정에서 키를 다시 확인해 주세요.';
      case GeminiErrorKind.modelUnavailable:
        return '이 키로 쓸 수 있는 Gemini 모델을 찾지 못했어요. 설정에서 연결 테스트를 해 주세요.';
      case GeminiErrorKind.network:
        return '네트워크 연결이 불안정해요. 잠시 후 다시 시도해 주세요.';
      case GeminiErrorKind.http:
        return statusCode == 429
            ? '요청이 너무 많아요. 잠시 후 다시 시도해 주세요.'
            : 'AI 응답을 받지 못했어요. (오류 $statusCode)';
      case GeminiErrorKind.emptyResponse:
        return 'AI가 답변을 만들지 못했어요. 다시 시도해 주세요.';
    }
  }

  @override
  String toString() => 'GeminiException($kind): $message';
}

/// 댓글 스레드의 한 줄 (작성자 표시 이름 + 내용).
typedef CommentLine = ({String author, String text});

class GeminiService {
  /// 저장된 모델이 없을 때 쓰는 기본값. 이 키로 쓸 수 없으면
  /// [resolveModel]로 쓸 수 있는 모델을 찾아 자동으로 바꾼다.
  static const String defaultModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.8-flash',
  );
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String _commentStyle =
      '\n\n지금은 SNS 댓글로 답하는 상황이야. 캐릭터 말투를 유지하면서 1~2문장으로 짧게 답해. 따옴표나 이름표 없이 댓글 내용만 써.';

  String apiKey;
  String model;

  /// 사진 생성용 모델. 처음 필요할 때 [resolveImageModel]로 찾는다.
  String? imageModel;
  final Duration timeout;
  final http.Client _client;

  /// 모델을 자동으로 바꿨을 때 호출된다 (설정 저장용).
  void Function(String model)? onModelChanged;

  GeminiService({
    required this.apiKey,
    this.model = defaultModel,
    this.timeout = const Duration(seconds: 30),
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// `--dart-define=GEMINI_API_KEY=...` 값으로 만든 서비스.
  /// 앱 설정에서 입력한 키가 있으면 [configure]로 덮어쓴다.
  factory GeminiService.fromEnvironment({http.Client? client}) => GeminiService(
    apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
    client: client,
  );

  bool get isConfigured => apiKey.isNotEmpty;

  void configure({required String apiKey, String? model}) {
    this.apiKey = apiKey.trim();
    if (model != null && model.isNotEmpty) this.model = model;
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

  /// 이 키로 generateContent를 쓸 수 있는 모델 ID 목록.
  Future<List<String>> listModels() async {
    if (!isConfigured) {
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

  /// 대화용으로 가장 알맞은 모델을 고른다: 최신 버전의 일반 Flash →
  /// Flash-Lite → 그 밖의 Gemini 순. 정식 버전을 preview보다 우선한다.
  static String? pickChatModel(List<String> ids) {
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
    if (candidates.isEmpty) return null;

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
    return candidates.first;
  }

  /// 이 키로 쓸 수 있는 모델을 찾아 [model]을 바꾼다.
  Future<String> resolveModel() async {
    final String? picked = pickChatModel(await listModels());
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
    if (!isConfigured) {
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
  Future<String> generateReply({
    required String persona,
    required List<ChatMessage> history,
  }) async {
    if (!isConfigured) {
      throw const GeminiException(
        GeminiErrorKind.missingApiKey,
        'GEMINI_API_KEY is empty',
      );
    }
    try {
      return await _generate(persona, history);
    } on GeminiException catch (e) {
      // 모델이 없어졌거나 이 키로 못 쓰면, 쓸 수 있는 모델로 바꿔 한 번 더 시도한다.
      if (e.kind != GeminiErrorKind.modelUnavailable) rethrow;
      final String previous = model;
      if (await resolveModel() == previous) rethrow;
      return _generate(persona, history);
    }
  }

  Future<String> _generate(String persona, List<ChatMessage> history) async {
    final Map<String, dynamic> requestBody = <String, dynamic>{
      'system_instruction': <String, dynamic>{
        'parts': <Map<String, String>>[
          <String, String>{'text': persona},
        ],
      },
      'contents': history
          .map(
            (ChatMessage message) => <String, dynamic>{
              'role': message.role,
              'parts': <Map<String, String>>[
                <String, String>{'text': message.text},
              ],
            },
          )
          .toList(),
    };

    final http.Response response = await _send(
      _client.post(
        Uri.parse('$_baseUrl/models/$model:generateContent'),
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

  /// [persona]가 [post]의 댓글 스레드에 이어서 다는 답글.
  /// [thread]는 원 댓글부터 시간순이며 마지막 줄이 답할 댓글이다.
  Future<String> generateCommentReply({
    required Persona persona,
    required Post post,
    required List<CommentLine> thread,
    required bool isOwnPost,
  }) {
    final String transcript = thread
        .map((CommentLine line) => '${line.author}: ${line.text}')
        .join('\n');
    return generateReply(
      persona: persona.prompt + _commentStyle,
      history: <ChatMessage>[
        ChatMessage(
          role: ChatMessage.userRole,
          text:
              '${isOwnPost ? '네가 올린' : '친구가 올린'} 게시물 내용:\n${post.caption}\n\n'
              '댓글 스레드 (위에서부터 시간순, "${persona.name}"은 너야):\n$transcript\n\n'
              '마지막 댓글에 이어서 답글을 달아줘.',
        ),
      ],
    );
  }

  /// 사용자가 올린 게시물에 [persona]가 남기는 반응 댓글.
  Future<String> generatePostReaction({
    required Persona persona,
    required String caption,
  }) {
    return generateReply(
      persona: persona.prompt + _commentStyle,
      history: <ChatMessage>[
        ChatMessage(
          role: ChatMessage.userRole,
          text:
              '친구가 새 사진 게시물을 올렸어. 게시물 문구:\n'
              '${caption.isEmpty ? '(문구 없음)' : caption}\n\n'
              '이 게시물에 댓글을 남겨줘.',
        ),
      ],
    );
  }

  /// [persona]가 오늘 올릴 법한 사진 한 장의 장면 묘사 (사진 생성·캡션에 씀).
  Future<String> generatePostScene({
    required Persona persona,
    required List<String> recentCaptions,
  }) {
    final String recent = recentCaptions.isEmpty
        ? '(없음)'
        : recentCaptions
              .map((String c) => '- ${c.split('\n').first}')
              .join('\n');
    return generateReply(
      persona: persona.prompt,
      history: <ChatMessage>[
        ChatMessage(
          role: ChatMessage.userRole,
          text:
              '오늘 인스타그램에 올릴 사진 한 장을 정하려고 해. 최근에 올린 게시물:\n$recent\n\n'
              '이것들과 겹치지 않게, 네 일상에서 자연스러운 장면을 한 문장으로 묘사해줘. '
              '장소, 하고 있는 일, 분위기가 드러나게. 설명이나 따옴표 없이 장면만 써.',
        ),
      ],
    );
  }

  /// [persona]가 새 사진 게시물에 붙일 캡션 (해시태그 포함).
  Future<String> generatePostCaption({
    required Persona persona,
    required String photoDescription,
  }) {
    return generateReply(
      persona: persona.prompt,
      history: <ChatMessage>[
        ChatMessage(
          role: ChatMessage.userRole,
          text:
              '지금 인스타그램에 사진을 올리려고 해. 사진: $photoDescription\n'
              '네 말투로 2~3줄짜리 캡션과 해시태그 3~5개를 써줘. '
              '따옴표나 설명 없이 게시물에 올릴 내용만 써.',
        ),
      ],
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

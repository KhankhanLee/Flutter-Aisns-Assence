import 'dart:async';
import 'dart:convert';

import 'package:assence/models/chat_message.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/post.dart';
import 'package:http/http.dart' as http;

enum GeminiErrorKind { missingApiKey, network, http, emptyResponse }

class GeminiException implements Exception {
  final GeminiErrorKind kind;
  final String message;
  final int? statusCode;

  const GeminiException(this.kind, this.message, {this.statusCode});

  /// 화면에 그대로 보여줄 수 있는 짧은 안내 문구.
  String get userMessage {
    switch (kind) {
      case GeminiErrorKind.missingApiKey:
        return 'Gemini API 키가 설정되지 않았어요. --dart-define=GEMINI_API_KEY=... 로 실행해 주세요.';
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

class GeminiService {
  static const String defaultModel =
      String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-2.5-flash');
  static const String _commentStyle =
      '\n\n지금은 SNS 댓글로 답하는 상황이야. 캐릭터 말투를 유지하면서 1~2문장으로 짧게 답해. 따옴표나 이름표 없이 댓글 내용만 써.';

  final String apiKey;
  final String model;
  final Duration timeout;
  final http.Client _client;

  GeminiService({
    required this.apiKey,
    this.model = defaultModel,
    this.timeout = const Duration(seconds: 30),
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// `--dart-define=GEMINI_API_KEY=...` 값으로 만든 서비스.
  factory GeminiService.fromEnvironment({http.Client? client}) => GeminiService(
        apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
        client: client,
      );

  bool get isConfigured => apiKey.isNotEmpty;

  /// [persona]를 system instruction으로, [history]를 대화 맥락으로 답변을 만든다.
  Future<String> generateReply({
    required String persona,
    required List<ChatMessage> history,
  }) async {
    if (!isConfigured) {
      throw const GeminiException(
          GeminiErrorKind.missingApiKey, 'GEMINI_API_KEY is empty');
    }

    final Uri uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );

    final Map<String, dynamic> requestBody = <String, dynamic>{
      'system_instruction': <String, dynamic>{
        'parts': <Map<String, String>>[
          <String, String>{'text': persona}
        ]
      },
      'contents': history
          .map((ChatMessage message) => <String, dynamic>{
                'role': message.role,
                'parts': <Map<String, String>>[
                  <String, String>{'text': message.text}
                ],
              })
          .toList(),
    };

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode(requestBody),
          )
          .timeout(timeout);
    } on TimeoutException catch (e) {
      throw GeminiException(GeminiErrorKind.network, 'timeout: $e');
    } on http.ClientException catch (e) {
      throw GeminiException(GeminiErrorKind.network, e.message);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GeminiException(GeminiErrorKind.http, response.body,
          statusCode: response.statusCode);
    }

    // charset 헤더가 없으면 http 패키지는 Latin-1로 디코딩하므로 직접 UTF-8로 읽는다.
    final String text =
        _extractText(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (text.isEmpty) {
      throw const GeminiException(
          GeminiErrorKind.emptyResponse, 'no text in candidates');
    }
    return text;
  }

  /// 게시물 작성자 [persona]가 [commentText]에 다는 답글.
  Future<String> generateCommentReply({
    required Persona persona,
    required Post post,
    required String commentText,
  }) {
    return generateReply(
      persona: persona.prompt + _commentStyle,
      history: <ChatMessage>[
        ChatMessage(
          role: ChatMessage.userRole,
          text: '네가 올린 게시물 내용:\n${post.caption}\n\n'
              '팔로워가 남긴 댓글:\n$commentText\n\n'
              '이 댓글에 답글을 달아줘.',
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
          text: '친구가 새 사진 게시물을 올렸어. 게시물 문구:\n'
              '${caption.isEmpty ? '(문구 없음)' : caption}\n\n'
              '이 게시물에 댓글을 남겨줘.',
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
    final Object? content =
        first is Map<String, dynamic> ? first['content'] : null;
    final Object? parts =
        content is Map<String, dynamic> ? content['parts'] : null;
    if (parts is! List<dynamic>) return '';

    return parts
        .map((dynamic part) => part is Map<String, dynamic>
            ? (part['text']?.toString() ?? '')
            : '')
        .where((String text) => text.isNotEmpty)
        .join('\n')
        .trim();
  }
}

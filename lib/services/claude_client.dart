import 'dart:async';
import 'dart:convert';

import 'package:assence/models/chat_message.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:http/http.dart' as http;

/// 설정 화면에서 고를 수 있는 Claude 모델.
typedef ClaudeModelOption = ({String id, String label, String note});

/// Anthropic Messages API로 답변을 받는다. Dart용 공식 SDK가 없어 HTTP로 직접 호출한다.
class ClaudeClient {
  static const String defaultModel = 'claude-haiku-5-5';
  static const List<ClaudeModelOption> models = <ClaudeModelOption>[
    (id: 'claude-haiku-5-5', label: 'Haiku 5.5', note: '가장 저렴 · 월 1천원 안팎'),
    (id: 'claude-sonnet-5-5', label: 'Sonnet 5.5', note: '중간 · 월 2만원 안팎'),
    (id: 'claude-opus-5-5', label: 'Opus 5.5', note: '가장 똑똑함 · 월 4만원 안팎'),
  ];

  static const String _url = 'https://api.anthropic.com/v1/messages';

  String apiKey;
  String model;
  final http.Client _client;
  final Duration timeout;

  ClaudeClient({
    this.apiKey = '',
    this.model = defaultModel,
    required http.Client client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client;

  bool get isConfigured => apiKey.isNotEmpty;

  /// [messages]는 user로 시작해 user/model이 번갈아 와야 한다.
  /// [image]는 마지막 user 메시지에 붙는다.
  Future<String> generate({
    required String system,
    required List<ChatMessage> messages,
    ChatImage? image,
  }) async {
    if (!isConfigured) {
      throw const GeminiException(GeminiErrorKind.missingApiKey, 'no key');
    }
    final int lastUser = messages.lastIndexWhere((ChatMessage m) => m.isUser);
    final Map<String, dynamic> body = <String, dynamic>{
      'model': model,
      'max_tokens': 4096,
      'system': system,
      // 짧은 채팅이라 깊게 생각할 필요가 없다. 비용과 응답 시간을 줄인다.
      'output_config': <String, String>{'effort': 'low'},
      'messages': <dynamic>[
        for (int i = 0; i < messages.length; i++)
          <String, dynamic>{
            'role': messages[i].isUser ? 'user' : 'assistant',
            'content': <dynamic>[
              if (image != null && i == lastUser)
                <String, dynamic>{
                  'type': 'image',
                  'source': <String, String>{
                    'type': 'base64',
                    'media_type': image.mimeType,
                    'data': base64Encode(image.bytes),
                  },
                },
              <String, String>{'type': 'text', 'text': messages[i].text},
            ],
          },
      ],
    };

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_url),
            headers: <String, String>{
              'content-type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException catch (e) {
      throw GeminiException(GeminiErrorKind.network, 'timeout: $e');
    } on http.ClientException catch (e) {
      throw GeminiException(GeminiErrorKind.network, e.message);
    }

    final String text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _error(response.statusCode, text, response.headers);
    }
    final String reply = _extractText(text);
    if (reply.isEmpty) {
      throw GeminiException(GeminiErrorKind.emptyResponse, text);
    }
    return reply;
  }

  static GeminiException _error(
    int code,
    String body,
    Map<String, String> headers,
  ) {
    if (code == 401 || code == 403) {
      return GeminiException(
        GeminiErrorKind.invalidApiKey,
        body,
        statusCode: code,
      );
    }
    if (code == 404) {
      return GeminiException(
        GeminiErrorKind.modelUnavailable,
        body,
        statusCode: code,
      );
    }
    if (code == 429 || code == 529) {
      final int? seconds = int.tryParse(headers['retry-after'] ?? '');
      return GeminiException(
        GeminiErrorKind.rateLimited,
        body,
        statusCode: code,
        retryAfter: seconds == null ? null : Duration(seconds: seconds),
      );
    }
    if (body.contains('credit balance')) {
      return GeminiException(GeminiErrorKind.noCredit, body, statusCode: code);
    }
    return GeminiException(GeminiErrorKind.http, body, statusCode: code);
  }

  /// 응답의 text 블록만 이어 붙인다. 거절(refusal)이면 빈 문자열.
  static String _extractText(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return '';
    }
    if (decoded is! Map<String, dynamic>) return '';
    if (decoded['stop_reason'] == 'refusal') return '';
    final Object? content = decoded['content'];
    if (content is! List<dynamic>) return '';
    return content
        .whereType<Map<String, dynamic>>()
        .where((Map<String, dynamic> block) => block['type'] == 'text')
        .map((Map<String, dynamic> block) => block['text']?.toString() ?? '')
        .where((String text) => text.isNotEmpty)
        .join('\n')
        .trim();
  }
}

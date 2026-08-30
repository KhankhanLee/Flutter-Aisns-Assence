import 'dart:convert';

import 'package:assence/chat_models.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _modelName = 'gemini-1.5-flash';
  final String apiKey;
  final http.Client _client;

  // required 및 nullable Client(?) 적용
  GeminiService({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  Future<String> generateReply({
    required String persona,
    List<ChatMessage>? history, // nullable 처리
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY가 설정되지 않았습니다.');
    }

    final Uri uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent?key=$apiKey',
    );

    final Map<String, dynamic> requestBody = <String, dynamic>{
      'system_instruction': <String, dynamic>{
        'parts': <Map<String, String>>[
          <String, String>{'text': persona}
        ]
      },
      'contents': (history ?? <ChatMessage>[])
          .map((ChatMessage message) => <String, dynamic>{
                'role': message.role,
                'parts': <Map<String, String>>[
                  <String, String>{'text': message.text}
                ],
              })
          .toList(),
    };

    final http.Response response = await _client.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gemini API 호출 실패: ${response.statusCode} ${response.body}');
    }

    final Map<String, dynamic> decoded =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> candidates = decoded['candidates'] is List<dynamic>
        ? decoded['candidates'] as List<dynamic>
        : <dynamic>[];

    if (candidates.isEmpty) {
      return '응답을 생성하지 못했어요.';
    }

    final Map<String, dynamic> firstCandidate = candidates.first is Map<String, dynamic>
        ? candidates.first as Map<String, dynamic>
        : <String, dynamic>{};
    final Map<String, dynamic> content = firstCandidate['content'] is Map<String, dynamic>
        ? firstCandidate['content'] as Map<String, dynamic>
        : <String, dynamic>{};
    final List<dynamic> parts =
        content['parts'] is List<dynamic> ? content['parts'] as List<dynamic> : <dynamic>[];

    if (parts.isEmpty) {
      return '응답을 생성하지 못했어요.';
    }

    final String mergedText = parts
        .map((dynamic part) =>
            part is Map<String, dynamic> ? (part['text']?.toString() ?? '') : '')
        .where((String text) => text.isNotEmpty)
        .join('\n')
        .trim();

    return mergedText.isEmpty ? '응답을 생성하지 못했어요.' : mergedText;
  }
}

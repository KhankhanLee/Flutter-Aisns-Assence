import 'dart:convert';

import 'package:assence/data/seed_data.dart';
import 'package:assence/models/chat_message.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _candidateBody(List<String> parts) => jsonEncode(<String, dynamic>{
  'candidates': <dynamic>[
    <String, dynamic>{
      'content': <String, dynamic>{
        'parts': parts.map((String t) => <String, String>{'text': t}).toList(),
      },
    },
  ],
});

http.Response _okResponse(String body) =>
    http.Response.bytes(utf8.encode(body), 200);

void main() {
  final List<ChatMessage> history = <ChatMessage>[
    ChatMessage(role: ChatMessage.userRole, text: '안녕'),
  ];

  test('키는 헤더로 보내고 URL에는 넣지 않는다', () async {
    late http.Request captured;
    final GeminiService service = GeminiService(
      apiKey: 'secret-key',
      model: 'test-model',
      client: MockClient((http.Request request) async {
        captured = request;
        return _okResponse(_candidateBody(<String>['안녕하세요']));
      }),
    );

    final String reply = await service.generateReply(
      persona: 'p',
      history: history,
    );

    expect(reply, '안녕하세요');
    expect(captured.headers['x-goog-api-key'], 'secret-key');
    expect(captured.url.toString(), isNot(contains('secret-key')));
    expect(captured.url.path, endsWith('/models/test-model:generateContent'));

    final Map<String, dynamic> body =
        jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['system_instruction']['parts'][0]['text'], 'p');
    expect(body['contents'][0]['role'], 'user');
    expect(body['contents'][0]['parts'][0]['text'], '안녕');
  });

  test('여러 part는 줄바꿈으로 합친다', () async {
    final GeminiService service = GeminiService(
      apiKey: 'k',
      client: MockClient(
        (_) async => _okResponse(_candidateBody(<String>['첫 줄', '', '둘째 줄'])),
      ),
    );
    expect(
      await service.generateReply(persona: 'p', history: history),
      '첫 줄\n둘째 줄',
    );
  });

  test('키가 없으면 요청 없이 missingApiKey 예외', () async {
    bool called = false;
    final GeminiService service = GeminiService(
      apiKey: '',
      client: MockClient((_) async {
        called = true;
        return http.Response('', 200);
      }),
    );

    expect(service.isConfigured, isFalse);
    await expectLater(
      service.generateReply(persona: 'p', history: history),
      throwsA(
        isA<GeminiException>().having(
          (GeminiException e) => e.kind,
          'kind',
          GeminiErrorKind.missingApiKey,
        ),
      ),
    );
    expect(called, isFalse);
  });

  test('HTTP 오류는 상태 코드와 함께 http 예외', () async {
    final GeminiService service = GeminiService(
      apiKey: 'k',
      client: MockClient((_) async => http.Response('{"error":{}}', 429)),
    );

    await expectLater(
      service.generateReply(persona: 'p', history: history),
      throwsA(
        isA<GeminiException>()
            .having((GeminiException e) => e.kind, 'kind', GeminiErrorKind.http)
            .having((GeminiException e) => e.statusCode, 'statusCode', 429),
      ),
    );
  });

  test('후보가 비었거나 JSON이 깨지면 emptyResponse 예외', () async {
    for (final String body in <String>['{"candidates":[]}', 'not json', '{}']) {
      final GeminiService service = GeminiService(
        apiKey: 'k',
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        service.generateReply(persona: 'p', history: history),
        throwsA(
          isA<GeminiException>().having(
            (GeminiException e) => e.kind,
            'kind',
            GeminiErrorKind.emptyResponse,
          ),
        ),
        reason: body,
      );
    }
  });

  test('네트워크 예외는 network 예외로 바뀐다', () async {
    final GeminiService service = GeminiService(
      apiKey: 'k',
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      service.generateReply(persona: 'p', history: history),
      throwsA(
        isA<GeminiException>().having(
          (GeminiException e) => e.kind,
          'kind',
          GeminiErrorKind.network,
        ),
      ),
    );
  });

  test('댓글 답글 프롬프트에 게시물 캡션과 댓글이 들어간다', () async {
    late Map<String, dynamic> body;
    final GeminiService service = GeminiService(
      apiKey: 'k',
      client: MockClient((http.Request request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return _okResponse(_candidateBody(<String>['고마워요!']));
      }),
    );

    final String reply = await service.generateCommentReply(
      persona: seedPersonas.first,
      post: buildSeedPosts(DateTime(2026)).first,
      commentText: '라떼 맛있어 보여요',
    );

    expect(reply, '고마워요!');
    final String systemText =
        body['system_instruction']['parts'][0]['text'] as String;
    expect(systemText, startsWith(seedPersonas.first.prompt));
    final String userText = body['contents'][0]['parts'][0]['text'] as String;
    expect(userText, contains('라떼 맛있어 보여요'));
    expect(userText, contains('#감성카페'));
  });
}

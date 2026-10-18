import 'dart:convert';
import 'dart:typed_data';

import 'package:assence/data/seed_data.dart';
import 'package:assence/models/chat_message.dart';
import 'package:assence/models/persona.dart';
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
      client: MockClient((_) async => http.Response('{"error":{}}', 500)),
    );

    await expectLater(
      service.generateReply(persona: 'p', history: history),
      throwsA(
        isA<GeminiException>()
            .having((GeminiException e) => e.kind, 'kind', GeminiErrorKind.http)
            .having((GeminiException e) => e.statusCode, 'statusCode', 500),
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
      thread: <CommentLine>[
        (author: '사용자', text: '라떼 맛있어 보여요'),
        (author: '하연', text: '고마워요 ☕️'),
        (author: '사용자', text: '어디 카페예요?'),
      ],
      isOwnPost: true,
    );

    expect(reply, '고마워요!');
    final String systemText =
        body['system_instruction']['parts'][0]['text'] as String;
    expect(systemText, contains(seedPersonas.first.prompt));
    final String userText = body['contents'][0]['parts'][0]['text'] as String;
    expect(userText, contains('라떼 맛있어 보여요'));
    // 스레드 전체가 순서대로 들어가야 AI가 대화를 이어갈 수 있다.
    expect(
      userText.indexOf('사용자: 라떼'),
      lessThan(userText.indexOf('사용자: 어디 카페예요?')),
    );
    expect(userText, contains('하연: 고마워요'));
    expect(userText, contains('#감성카페'));
  });

  group('모델 자동 선택', () {
    test('최신 일반 Flash를 정식 버전 우선으로 고른다', () {
      expect(
        GeminiService.pickChatModel(<String>[
          'gemini-2.5-flash',
          'gemini-3.8-flash',
          'gemini-3.9-flash-preview-11-2026',
          'gemini-3.5-flash-lite',
          'gemini-3.8-flash-image',
          'gemini-3.1-pro-preview',
          'text-embedding-004',
        ]),
        'gemini-3.8-flash',
      );
      // Flash가 없으면 Flash-Lite, 그것도 없으면 다른 Gemini
      expect(
        GeminiService.pickChatModel(<String>[
          'gemini-3.5-flash-lite',
          'gemini-3.1-pro',
        ]),
        'gemini-3.5-flash-lite',
      );
      expect(
        GeminiService.pickChatModel(<String>['gemini-3.1-pro']),
        'gemini-3.1-pro',
      );
      expect(GeminiService.pickChatModel(<String>['embedding-001']), isNull);
    });

    test('모델이 없어졌으면 쓸 수 있는 모델을 찾아 한 번 더 시도한다', () async {
      final List<String> calls = <String>[];
      String? changed;
      final GeminiService service = GeminiService(
        apiKey: 'k',
        model: 'gemini-2.5-flash',
        client: MockClient((http.Request request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.method == 'GET') {
            return _okResponse(
              jsonEncode(<String, dynamic>{
                'models': <dynamic>[
                  <String, dynamic>{
                    'name': 'models/gemini-3.8-flash',
                    'supportedGenerationMethods': <String>['generateContent'],
                  },
                  <String, dynamic>{
                    'name': 'models/text-embedding-004',
                    'supportedGenerationMethods': <String>['embedContent'],
                  },
                ],
              }),
            );
          }
          if (request.url.path.contains('gemini-2.5-flash')) {
            return http.Response(
              '{"error":{"message":"This model is no longer available."}}',
              404,
            );
          }
          return _okResponse(_candidateBody(<String>['안녕!']));
        }),
      )..onModelChanged = (String m) => changed = m;

      final String reply = await service.generateReply(
        persona: 'p',
        history: history,
      );

      expect(reply, '안녕!');
      expect(service.model, 'gemini-3.8-flash');
      expect(changed, 'gemini-3.8-flash');
      expect(calls, <String>[
        'POST /v1beta/models/gemini-2.5-flash:generateContent',
        'GET /v1beta/models',
        'POST /v1beta/models/gemini-3.8-flash:generateContent',
      ]);
    });

    test('잘못된 키는 invalidApiKey로 구분한다', () async {
      final GeminiService service = GeminiService(
        apiKey: 'bad',
        client: MockClient(
          (_) async => http.Response(
            '{"error":{"status":"INVALID_ARGUMENT","details":[{"reason":"API_KEY_INVALID"}]}}',
            400,
          ),
        ),
      );
      await expectLater(
        service.generateReply(persona: 'p', history: history),
        throwsA(
          isA<GeminiException>().having(
            (GeminiException e) => e.kind,
            'kind',
            GeminiErrorKind.invalidApiKey,
          ),
        ),
      );
    });
  });

  group('사진 생성', () {
    test('이미지 모델은 Flash 계열을 정식 버전 우선으로 고른다', () {
      expect(
        GeminiService.pickImageModel(<String>[
          'gemini-3.8-flash',
          'gemini-3.1-flash-image',
          'gemini-3.5-flash-image-preview',
          'gemini-3-pro-image-preview',
        ]),
        'gemini-3.1-flash-image',
      );
      expect(
        GeminiService.pickImageModel(<String>['gemini-3.8-flash']),
        isNull,
      );
    });

    test('참고 사진을 함께 보내고 응답의 이미지 데이터를 꺼낸다', () async {
      late Map<String, dynamic> body;
      final List<int> png = <int>[0x89, 0x50, 0x4e, 0x47, 1, 2, 3];
      final GeminiService service = GeminiService(
        apiKey: 'k',
        client: MockClient((http.Request request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return _okResponse(
            jsonEncode(<String, dynamic>{
              'candidates': <dynamic>[
                <String, dynamic>{
                  'content': <String, dynamic>{
                    'parts': <dynamic>[
                      <String, String>{'text': '여기 사진이에요'},
                      <String, dynamic>{
                        'inlineData': <String, String>{
                          'mimeType': 'image/png',
                          'data': base64Encode(png),
                        },
                      },
                    ],
                  },
                },
              ],
            }),
          );
        }),
      )..imageModel = 'gemini-3.1-flash-image';

      final List<int> image = await service.generateImage(
        prompt: '카페 사진',
        reference: Uint8List.fromList(<int>[9, 9]),
      );

      expect(image, png);
      final List<dynamic> parts = body['contents'][0]['parts'] as List<dynamic>;
      expect(parts.first['inline_data']['data'], base64Encode(<int>[9, 9]));
      expect(parts.last['text'], '카페 사진');
      expect(body['generationConfig']['responseModalities'], contains('IMAGE'));
    });

    test('이미지가 없는 응답은 emptyResponse', () async {
      final GeminiService service = GeminiService(
        apiKey: 'k',
        client: MockClient(
          (_) async => _okResponse(_candidateBody(<String>['글만 있어요'])),
        ),
      )..imageModel = 'gemini-3.1-flash-image';
      await expectLater(
        service.generateImage(prompt: 'p'),
        throwsA(
          isA<GeminiException>().having(
            (GeminiException e) => e.kind,
            'kind',
            GeminiErrorKind.emptyResponse,
          ),
        ),
      );
    });
  });

  group('사람 같은 말투', () {
    test('DM은 프로필·공통 규칙·지금 시각을 보내고, 연달아 온 말풍선은 합쳐 보낸다', () async {
      late Map<String, dynamic> body;
      final GeminiService service = GeminiService(
        apiKey: 'k',
        now: () => DateTime(2026, 10, 16, 21, 30), // 금요일 밤
        client: MockClient((http.Request request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return _okResponse(
            _candidateBody(<String>[
              '지은: **헐 그거?**\n\n- 나도 요즘 그거 봐 😂😂\n\n너는?',
            ]),
          );
        }),
      );
      final Persona jieun = seedPersonas.firstWhere(
        (Persona p) => p.id == 'jieun',
      );

      final String reply = await service.generateChatReply(
        persona: jieun,
        history: <ChatMessage>[
          ChatMessage(role: ChatMessage.userRole, text: '뭐해'),
          ChatMessage(role: ChatMessage.modelRole, text: '그냥 있지'),
          ChatMessage(role: ChatMessage.modelRole, text: '넌?'),
          ChatMessage(role: ChatMessage.userRole, text: '요즘 뭐 봐?'),
        ],
      );

      // 마크다운·이름표·목록 기호·이모지(지은은 0개)가 빠진다.
      expect(reply, '헐 그거?\n\n나도 요즘 그거 봐\n\n너는?');

      final String system =
          body['system_instruction']['parts'][0]['text'] as String;
      expect(system, contains(jieun.prompt));
      expect(system, contains('마크다운을 쓰지 마'));
      expect(system, contains('이모지는 쓰지 마'));
      expect(system, contains('10월 16일 금요일 저녁 21시쯤'));
      expect(body['generationConfig']['temperature'], 1.0);

      final List<dynamic> contents = body['contents'] as List<dynamic>;
      expect(contents.map((dynamic c) => c['role']), <String>[
        'user',
        'model',
        'user',
      ]);
      expect(contents[1]['parts'][0]['text'], '그냥 있지\n넌?');
    });

    test('댓글 답글은 한 문단으로 정리한다', () async {
      final GeminiService service = GeminiService(
        apiKey: 'k',
        client: MockClient(
          (_) async =>
              _okResponse(_candidateBody(<String>['"고마워!\n다음에 같이 가자 ✨🔥"'])),
        ),
      );
      final Persona hayeon = seedPersonas.first;
      final String reply = await service.generateCommentReply(
        persona: hayeon,
        post: buildSeedPosts(DateTime(2026)).first,
        thread: <CommentLine>[(author: '사용자', text: '예뻐요')],
        isOwnPost: true,
      );
      // 하연은 이모지 1개까지
      expect(reply, '고마워! 다음에 같이 가자 ✨');
    });
  });
}

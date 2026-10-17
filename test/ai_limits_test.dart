import 'dart:convert';
import 'dart:typed_data';

import 'package:assence/data/seed_data.dart';
import 'package:assence/models/chat_message.dart';
import 'package:assence/services/claude_client.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, [int status = 200, Map<String, String>? h]) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: h ?? <String, String>{},
    );

http.Response _geminiText(String text) => _json(<String, dynamic>{
  'candidates': <dynamic>[
    <String, dynamic>{
      'content': <String, dynamic>{
        'parts': <dynamic>[
          <String, String>{'text': text},
        ],
      },
    },
  ],
});

/// Gemini 429 응답 본문. [daily]면 하루 한도.
http.Response _quota({bool daily = false, String delay = '7s'}) =>
    _json(<String, dynamic>{
      'error': <String, dynamic>{
        'code': 429,
        'status': 'RESOURCE_EXHAUSTED',
        'details': <dynamic>[
          <String, dynamic>{
            '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
            'violations': <dynamic>[
              <String, String>{
                'quotaId': daily
                    ? 'GenerateRequestsPerDayPerProjectPerModel-FreeTier'
                    : 'GenerateRequestsPerMinutePerProjectPerModel-FreeTier',
              },
            ],
          },
          <String, String>{
            '@type': 'type.googleapis.com/google.rpc.RetryInfo',
            'retryDelay': delay,
          },
        ],
      },
    }, 429);

http.Response _models(List<String> ids) => _json(<String, dynamic>{
  'models': <dynamic>[
    for (final String id in ids)
      <String, dynamic>{
        'name': 'models/$id',
        'supportedGenerationMethods': <String>['generateContent'],
      },
  ],
});

http.Response _claudeText(String text) => _json(<String, dynamic>{
  'content': <dynamic>[
    <String, String>{'type': 'thinking', 'thinking': ''},
    <String, String>{'type': 'text', 'text': text},
  ],
  'stop_reason': 'end_turn',
});

String _modelOf(http.Request r) =>
    RegExp(r'models/([^:]+):').firstMatch(r.url.path)?.group(1) ?? '';

void main() {
  final List<ChatMessage> history = <ChatMessage>[
    ChatMessage(role: ChatMessage.userRole, text: '안녕'),
  ];

  group('Gemini 한도(429) 대응', () {
    test('429 본문에서 다시 시도할 시간과 하루 한도 여부를 읽는다', () async {
      final GeminiService service = GeminiService(
        apiKey: 'k',
        client: MockClient((http.Request r) async {
          if (r.method == 'GET') return _models(<String>[]);
          return _quota(daily: true, delay: '34.5s');
        }),
      );
      await expectLater(
        service.generateReply(persona: 'p', history: history),
        throwsA(
          isA<GeminiException>()
              .having(
                (GeminiException e) => e.kind,
                'kind',
                GeminiErrorKind.rateLimited,
              )
              .having((GeminiException e) => e.daily, 'daily', isTrue)
              .having(
                (GeminiException e) => e.retryAfter,
                'retryAfter',
                const Duration(milliseconds: 34500),
              )
              .having(
                (GeminiException e) => e.userMessage,
                'userMessage',
                contains('오늘'),
              ),
        ),
      );
    });

    test('기본 모델이 한도에 걸리면 같은 키의 다음 모델로 답하고, 기본 모델은 그대로 둔다', () async {
      final List<String> used = <String>[];
      final GeminiService service = GeminiService(
        apiKey: 'k',
        model: 'gemini-3.8-flash',
        client: MockClient((http.Request r) async {
          if (r.method == 'GET') {
            return _models(<String>[
              'gemini-3.8-flash',
              'gemini-3.8-flash-lite',
              'gemma-4-27b-it',
            ]);
          }
          used.add(_modelOf(r));
          return _modelOf(r) == 'gemini-3.8-flash'
              ? _quota(daily: true)
              : _geminiText('대체 모델 답');
        }),
      );

      expect(
        await service.generateReply(persona: 'p', history: history),
        '대체 모델 답',
      );
      expect(used, <String>['gemini-3.8-flash', 'gemini-3.8-flash-lite']);
      expect(service.model, 'gemini-3.8-flash');
      expect(service.activeGeminiModel, 'gemini-3.8-flash-lite');

      // 쉬는 중인 기본 모델은 건너뛰고 바로 대체 모델로 보낸다.
      used.clear();
      await service.generateReply(persona: 'p', history: history);
      expect(used, <String>['gemini-3.8-flash-lite']);
    });

    test('Gemini가 모두 막히면 Gemma로 보내고, 설정은 첫 user 메시지에 붙인다', () async {
      final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
      final GeminiService service = GeminiService(
        apiKey: 'k',
        model: 'gemini-3.8-flash',
        client: MockClient((http.Request r) async {
          if (r.method == 'GET') {
            return _models(<String>['gemini-3.8-flash', 'gemma-4-27b-it']);
          }
          if (_modelOf(r).startsWith('gemini')) return _quota(daily: true);
          bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
          return _geminiText('젬마 답');
        }),
      );

      expect(
        await service.generateReply(persona: '캐릭터 설정', history: history),
        '젬마 답',
      );
      final Map<String, dynamic> body = bodies.single;
      expect(body.containsKey('system_instruction'), isFalse);
      final String firstText =
          ((body['contents'] as List<dynamic>).first['parts'] as List<dynamic>)
                  .last['text']
              as String;
      expect(firstText, contains('캐릭터 설정'));
      expect(firstText, contains('안녕'));
    });

    test('백그라운드 요청은 한도에 걸려도 다른 모델로 넘어가지 않는다', () async {
      final List<String> used = <String>[];
      final GeminiService service = GeminiService(
        apiKey: 'k',
        model: 'gemini-3.8-flash',
        client: MockClient((http.Request r) async {
          if (r.method == 'GET') {
            return _models(<String>[
              'gemini-3.8-flash',
              'gemini-3.8-flash-lite',
            ]);
          }
          used.add(_modelOf(r));
          return _quota();
        }),
      );

      for (int i = 0; i < 2; i++) {
        await expectLater(
          service.generateReply(
            persona: 'p',
            history: history,
            background: true,
          ),
          throwsA(isA<GeminiException>()),
        );
      }
      // 두 번째는 기본 모델이 쉬는 중이라 요청조차 보내지 않는다.
      expect(used, <String>['gemini-3.8-flash']);
    });

    test('다른 모델이 없고 잠깐만 기다리면 되면 기다렸다 다시 보낸다', () async {
      final List<Duration> waits = <Duration>[];
      int calls = 0;
      final GeminiService service = GeminiService(
        apiKey: 'k',
        model: 'gemini-3.8-flash',
        sleep: (Duration d) async => waits.add(d),
        client: MockClient((http.Request r) async {
          if (r.method == 'GET') return _models(<String>['gemini-3.8-flash']);
          calls++;
          return calls == 1 ? _quota(delay: '7s') : _geminiText('기다린 답');
        }),
      );

      expect(
        await service.generateReply(persona: 'p', history: history),
        '기다린 답',
      );
      expect(waits, <Duration>[const Duration(seconds: 7)]);
    });

    test('모델 순서: Flash → Flash-Lite → 그 밖의 Gemini → Gemma(최신·큰 것 우선)', () {
      expect(
        GeminiService.rankChatModels(<String>[
          'gemma-3-4b-it',
          'gemini-3.1-pro',
          'gemma-4-27b-it',
          'gemini-3.8-flash-lite',
          'gemma-4-2b-it',
          'gemini-3.8-flash',
          'gemma-4-embedding',
        ]),
        <String>[
          'gemini-3.8-flash',
          'gemini-3.8-flash-lite',
          'gemini-3.1-pro',
          'gemma-4-27b-it',
          'gemma-4-2b-it',
          'gemma-3-4b-it',
        ],
      );
    });
  });

  group('Claude', () {
    test('Messages API 형식으로 보내고 text 블록만 읽는다', () async {
      late http.Request captured;
      final GeminiService service = GeminiService(
        apiKey: '',
        client: MockClient((http.Request r) async {
          captured = r;
          return _claudeText('클로드 답');
        }),
      );
      service.claude.apiKey = 'sk-ant-test';
      service.provider = AiProvider.claude;
      expect(service.isConfigured, isTrue);

      final String reply = await service.generateReply(
        persona: '캐릭터 설정',
        history: <ChatMessage>[
          ChatMessage(role: ChatMessage.userRole, text: '안녕'),
          ChatMessage(role: ChatMessage.modelRole, text: '응 안녕'),
          ChatMessage(role: ChatMessage.modelRole, text: '뭐해?'),
          ChatMessage(role: ChatMessage.userRole, text: '이거 봐'),
        ],
        image: (
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          mimeType: 'image/jpeg',
        ),
      );

      expect(reply, '클로드 답');
      expect(captured.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(captured.headers['x-api-key'], 'sk-ant-test');
      expect(captured.headers['anthropic-version'], '2023-06-01');
      final Map<String, dynamic> body =
          jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['model'], ClaudeClient.defaultModel);
      expect(body['system'], '캐릭터 설정');
      expect(body.containsKey('temperature'), isFalse);
      expect(body['output_config'], <String, String>{'effort': 'low'});
      final List<dynamic> messages = body['messages'] as List<dynamic>;
      expect(messages.map((dynamic m) => m['role']).toList(), <String>[
        'user',
        'assistant',
        'user',
      ]);
      // 연달아 온 말풍선은 합쳐서 보낸다.
      expect(messages[1]['content'].last['text'], '응 안녕\n뭐해?');
      // 사진은 마지막 user 메시지에 붙는다.
      expect(messages[2]['content'].first['type'], 'image');
      expect(messages[2]['content'].first['source']['data'], 'AQID');
    });

    test('거절이나 빈 응답은 emptyResponse, 오류 코드는 알맞은 종류로 바뀐다', () async {
      Future<GeminiErrorKind> kindFor(http.Response response) async {
        final ClaudeClient client = ClaudeClient(
          apiKey: 'k',
          client: MockClient((_) async => response),
        );
        try {
          await client.generate(system: 's', messages: history);
        } on GeminiException catch (e) {
          return e.kind;
        }
        fail('예외가 나야 한다');
      }

      expect(
        await kindFor(
          _json(<String, dynamic>{
            'content': <dynamic>[],
            'stop_reason': 'refusal',
          }),
        ),
        GeminiErrorKind.emptyResponse,
      );
      expect(
        await kindFor(_json(<String, dynamic>{}, 401)),
        GeminiErrorKind.invalidApiKey,
      );
      expect(
        await kindFor(
          _json(<String, dynamic>{
            'error': <String, String>{
              'message': 'Your credit balance is too low',
            },
          }, 400),
        ),
        GeminiErrorKind.noCredit,
      );

      final ClaudeClient limited = ClaudeClient(
        apiKey: 'k',
        client: MockClient(
          (_) async => _json(<String, dynamic>{}, 429, <String, String>{
            'retry-after': '12',
          }),
        ),
      );
      await expectLater(
        limited.generate(system: 's', messages: history),
        throwsA(
          isA<GeminiException>()
              .having(
                (GeminiException e) => e.kind,
                'kind',
                GeminiErrorKind.rateLimited,
              )
              .having(
                (GeminiException e) => e.retryAfter,
                'retryAfter',
                const Duration(seconds: 12),
              ),
        ),
      );
    });

    test('두 AI 키가 다 있으면 한도에 걸렸을 때 다른 AI가 대신 답한다', () async {
      final GeminiService service = GeminiService(
        apiKey: 'gemini-key',
        model: 'gemini-3.8-flash',
        client: MockClient((http.Request r) async {
          if (r.url.host == 'api.anthropic.com') return _claudeText('클로드가 대신');
          if (r.method == 'GET') return _models(<String>['gemini-3.8-flash']);
          return _quota(daily: true);
        }),
      );
      service.claude.apiKey = 'claude-key';

      expect(
        await service.generateReply(persona: 'p', history: history),
        '클로드가 대신',
      );
      // 백그라운드 요청은 다른 AI로 넘어가지 않는다.
      await expectLater(
        service.generateReply(persona: 'p', history: history, background: true),
        throwsA(isA<GeminiException>()),
      );
    });
  });

  test('스토리 반응: 사진과 스토리 맥락을 보내고, DM 기록이 상대 메시지로 시작해도 user로 시작한다', () async {
    late Map<String, dynamic> body;
    final GeminiService service = GeminiService(
      apiKey: 'k',
      client: MockClient((http.Request r) async {
        body = jsonDecode(r.body) as Map<String, dynamic>;
        return _geminiText('**와** 거기 어디야?');
      }),
    );
    final SharedStory story = SharedStory(
      authorId: 'me',
      imagePath: '/photos/beach.jpg',
      text: '바다 왔다',
      createdAt: DateTime(2026, 10, 17, 12),
    );

    final String reply = await service.generateStoryReaction(
      persona: seedPersonas.first,
      story: story,
      history: <ChatMessage>[
        ChatMessage(
          role: ChatMessage.modelRole,
          text: '저번에 보낸 말',
          story: story,
        ),
      ],
      image: (bytes: Uint8List.fromList(<int>[9]), mimeType: 'image/jpeg'),
    );

    expect(reply, '와 거기 어디야?');
    final List<dynamic> contents = body['contents'] as List<dynamic>;
    expect(contents.first['role'], 'user');
    expect(contents.first['parts'].last['text'], contains('바다 왔다'));
    expect(contents.last['role'], 'user');
    expect(
      contents.last['parts'].first['inline_data']['mime_type'],
      'image/jpeg',
    );
  });
}

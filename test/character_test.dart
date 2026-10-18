import 'package:assence/data/seed_data.dart';
import 'package:assence/models/chat_message.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/utils/humanize.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// 차례대로 정해진 답을 돌려주는 Gemini. null이면 한도 초과로 실패한다.
class _ScriptedGemini extends FakeGemini {
  final List<String?> replies;

  _ScriptedGemini(this.replies);

  @override
  Future<String> generateReply({
    required String persona,
    required List<ChatMessage> history,
    ChatImage? image,
    bool background = false,
  }) async {
    await super.generateReply(
      persona: persona,
      history: history,
      image: image,
      background: background,
    );
    final String? reply = replies.removeAt(0);
    if (reply == null) {
      throw const GeminiException(GeminiErrorKind.rateLimited, 'quota');
    }
    return reply;
  }
}

void main() {
  final List<ChatMessage> history = <ChatMessage>[
    ChatMessage(role: ChatMessage.userRole, text: '내일 만나자'),
  ];

  test('AI라고 스스로 말하는 표현만 캐릭터 이탈로 본다', () {
    expect(breaksCharacter('미안 나는 AI라서 실제로 만날 수는 없어'), isTrue);
    expect(breaksCharacter('저는 AI 언어 모델이에요'), isTrue);
    expect(breaksCharacter('요즘 AI 툴 리뷰하느라 마감 지옥이야 ㅋㅋ'), isFalse);
    expect(breaksCharacter('좋아 내일 몇 시?'), isFalse);
  });

  test('DM 지시문에 롤플레이 설정과 약속·만남 규칙이 들어간다', () async {
    final FakeGemini gemini = FakeGemini(reply: '좋아!');
    await gemini.generateChatReply(
      persona: seedPersonas.first,
      history: history,
    );
    final String system = gemini.personas.single;
    expect(system, startsWith('[앱 설정]'));
    expect(system, contains('롤플레이'));
    expect(system, contains('만나자, 같이 있어줘'));
    expect(system, contains('약속한 건 기억'));
    expect(system, contains(seedPersonas.first.prompt));
  });

  test('캐릭터를 벗어난 답이 오면 한 번만 다시 받는다', () async {
    final _ScriptedGemini gemini = _ScriptedGemini(<String?>[
      '미안, 나는 AI라서 실제로 만날 수는 없어',
      '헐 좋아 내일 몇 시에 볼까?',
    ]);
    final String reply = await gemini.generateChatReply(
      persona: seedPersonas.first,
      history: history,
    );
    expect(reply, '헐 좋아 내일 몇 시에 볼까?');
    expect(gemini.personas, hasLength(2));
    expect(gemini.personas.last, contains('[주의]'));
  });

  test('다시 받다가 실패하면 처음 답을 쓴다', () async {
    final _ScriptedGemini gemini = _ScriptedGemini(<String?>[
      '나는 AI라서 못 가',
      null,
    ]);
    final String reply = await gemini.generateChatReply(
      persona: seedPersonas.first,
      history: history,
    );
    expect(reply, '나는 AI라서 못 가');
    expect(gemini.personas, hasLength(2));
  });

  test('평범한 답이면 다시 요청하지 않는다', () async {
    final FakeGemini gemini = FakeGemini(reply: '좋아 내일 봐');
    await gemini.generateChatReply(
      persona: seedPersonas.first,
      history: history,
    );
    expect(gemini.personas, hasLength(1));
  });
}

import 'dart:convert';
import 'dart:math';

import 'package:assence/data/seed_data.dart';
import 'package:assence/models/chat_message.dart';
import 'package:assence/models/story.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/state/ai_settings_store.dart';
import 'package:assence/state/chat_store.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/state/story_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'test_helpers.dart';

void main() {
  group('내 스토리 반응', () {
    test('올리면 각 친구가 활동 시간에 맞춰 만료 전에 보고, DM은 많아야 한 명이 보낸다', () async {
      for (int seed = 0; seed < 30; seed++) {
        DateTime now = DateTime(2026, 10, 17, 13);
        final StoryStore store = StoryStore(
          await openTestStore(),
          now: () => now,
          random: Random(seed),
        );
        final Story story = store.addMyStory(imagePath: '', text: '점심 맛집');

        expect(store.viewersOf(story), isEmpty, reason: '올리자마자 본 사람은 없다');
        for (final StoryView view in story.views) {
          expect(view.at.isAfter(story.createdAt), isTrue);
          expect(view.at.isBefore(story.createdAt.add(Story.lifetime)), isTrue);
          expect(personaHabits[view.personaId]!.isActiveAt(view.at), isTrue);
        }
        expect(
          story.views.where((StoryView v) => v.replyAt != null).length,
          lessThanOrEqualTo(1),
        );

        now = now.add(const Duration(hours: 23));
        expect(store.viewersOf(story).length, story.views.length);
      }
    });

    test('DM 차례가 되면 dueReplies에 나오고, 보낸 뒤에는 다시 나오지 않으며 저장된다', () async {
      DateTime now = DateTime(2026, 10, 17, 13);
      final LocalStore local = await openTestStore();
      // DM을 보내는 일정이 생기는 seed를 찾는다.
      late StoryStore store;
      late Story story;
      for (int seed = 0; ; seed++) {
        store = StoryStore(local, now: () => now, random: Random(seed));
        story = store.addMyStory(imagePath: '', text: '오늘 하늘');
        if (story.views.any((StoryView v) => v.replyAt != null)) break;
      }
      final StoryView replier = story.views.firstWhere(
        (StoryView v) => v.replyAt != null,
      );
      expect(store.dueReplies(), isEmpty);

      now = replier.replyAt!;
      expect(store.dueReplies().single.view.personaId, replier.personaId);
      store.markReplied(replier);
      expect(store.dueReplies(), isEmpty);

      final Story reopened = StoryStore(
        local,
        now: () => now,
      ).myActiveStories.firstWhere((Story s) => s.id == story.id);
      expect(reopened.views.length, story.views.length);
      expect(
        reopened.views
            .firstWhere((StoryView v) => v.personaId == replier.personaId)
            .replied,
        isTrue,
      );
    });

    test('예전에 저장된 스토리(조회 정보 없음)도 읽힌다', () async {
      final LocalStore local = await openTestStore(<String, Object>{
        'my_stories': jsonEncode(<dynamic>[
          <String, String>{
            'id': 'old',
            'authorId': 'me',
            'imagePath': '',
            'text': '옛날 스토리',
            'createdAt': DateTime.now().toIso8601String(),
          },
        ]),
      });
      final StoryStore store = StoryStore(local);
      expect(store.myActiveStories.single.views, isEmpty);
    });

    test('친구 스토리 좋아요는 눌렀다 취소할 수 있고 다시 열어도 유지된다', () async {
      final LocalStore local = await openTestStore();
      final StoryStore store = StoryStore(local);
      store.toggleLike('hayeon_story');
      expect(store.isLiked('hayeon_story'), isTrue);
      expect(StoryStore(local).isLiked('hayeon_story'), isTrue);
      store.toggleLike('hayeon_story');
      expect(StoryStore(local).isLiked('hayeon_story'), isFalse);
    });
  });

  group('스토리 DM', () {
    Future<(ChatStore, FakeGemini)> chatStore() async {
      final FakeGemini gemini = FakeGemini(reply: '와 어디야?\n\n나도 가고 싶다');
      final LocalStore local = await openTestStore();
      final ChatStore chat = ChatStore(local, gemini, PersonaStore(local))
        ..bubbleGap = (() => Duration.zero)
        ..imageLoader = ((String path) async => null);
      return (chat, gemini);
    }

    final Story myStory = Story(
      id: 's1',
      authorId: 'me',
      imagePath: '',
      text: '바다 왔다',
      createdAt: DateTime.now(),
    );

    test('친구가 내 스토리를 보고 먼저 DM을 보내면 스토리가 붙고 안 읽음으로 표시된다', () async {
      final (ChatStore chat, FakeGemini gemini) = await chatStore();

      expect(await chat.receiveStoryReaction('hayeon', myStory), isTrue);

      final List<ChatMessage> history = chat.historyOf('hayeon');
      expect(history.map((ChatMessage m) => m.text), <String>[
        '와 어디야?',
        '나도 가고 싶다',
      ]);
      expect(history.first.story?.text, '바다 왔다');
      expect(history.last.story, isNull);
      expect(chat.isUnread('hayeon'), isTrue);
      expect(gemini.backgrounds.single, isTrue);
      expect(gemini.requests.single.last.text, contains('바다 왔다'));
    });

    test('실패하면 오류를 띄우지 않고 false를 돌려준다', () async {
      final (ChatStore chat, FakeGemini gemini) = await chatStore();
      gemini.error = const GeminiException(
        GeminiErrorKind.rateLimited,
        'quota',
      );
      expect(await chat.receiveStoryReaction('hayeon', myStory), isFalse);
      expect(chat.historyOf('hayeon'), isEmpty);
      expect(chat.errorOf('hayeon'), isNull);
    });

    test('친구 스토리에 답장하면 스토리 정보가 함께 저장된다', () async {
      final (ChatStore chat, _) = await chatStore();
      final Story hayeonStory = buildSeedPersonaStories(DateTime.now()).first;
      await chat.send('hayeon', '여기 어디예요?', story: hayeonStory);
      final ChatMessage sent = chat.historyOf('hayeon').first;
      expect(sent.text, '여기 어디예요?');
      expect(sent.story?.authorId, 'hayeon');
      expect(
        ChatMessage.fromJson(sent.toJson()).story?.imagePath,
        hayeonStory.imagePath,
      );
    });
  });

  group('AI 연결 설정', () {
    Future<http.Response> claudeOk(http.Request r) async => http.Response.bytes(
      utf8.encode(
        jsonEncode(<String, dynamic>{
          'content': <dynamic>[
            <String, String>{'type': 'text', 'text': '안녕하세요, 클로드예요'},
          ],
        }),
      ),
      200,
    );

    test('Claude 키를 저장하면 Claude를 쓰고, 다시 열어도 키·모델·선택이 유지된다', () async {
      final LocalStore local = await openTestStore();
      GeminiService service() =>
          GeminiService(apiKey: '', client: MockClient(claudeOk));
      final GeminiService gemini = service();
      final AiSettingsStore ai = AiSettingsStore(local, gemini);

      await ai.setClaudeModel('claude-sonnet-5-5');
      final String reply = await ai.saveAndTest(
        ' sk-ant-key-1234 ',
        provider: AiProvider.claude,
      );
      expect(reply, '안녕하세요, 클로드예요');
      expect(ai.provider, AiProvider.claude);
      expect(ai.isConfigured, isTrue);
      expect(ai.model, 'claude-sonnet-5-5');
      expect(ai.maskedKey, isNot(contains('key')));

      final GeminiService reopened = service();
      final AiSettingsStore again = AiSettingsStore(local, reopened);
      expect(again.provider, AiProvider.claude);
      expect(reopened.claude.apiKey, 'sk-ant-key-1234');
      expect(reopened.claude.model, 'claude-sonnet-5-5');

      await ai.clearKey(provider: AiProvider.claude);
      expect(ai.isConfigured, isFalse);
    });

    test('Claude 키 테스트가 실패하면 원래 AI와 키로 되돌린다', () async {
      final LocalStore local = await openTestStore();
      final GeminiService gemini = GeminiService(
        apiKey: 'gemini-key',
        client: MockClient((_) async => http.Response('{}', 401)),
      );
      final AiSettingsStore ai = AiSettingsStore(local, gemini);

      await expectLater(
        ai.saveAndTest('bad', provider: AiProvider.claude),
        throwsA(isA<GeminiException>()),
      );
      expect(ai.provider, AiProvider.gemini);
      expect(gemini.claude.apiKey, isEmpty);
      expect(gemini.apiKey, 'gemini-key');
    });
  });
}

import 'dart:convert';

import 'package:assence/data/seed_data.dart';
import 'package:assence/state/ai_settings_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:assence/app.dart';
import 'package:assence/models/app_notification.dart';
import 'package:assence/models/chat_message.dart';
import 'package:assence/models/comment.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/post.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/models/story.dart';
import 'package:assence/state/feed_store.dart';
import 'package:assence/state/story_store.dart';
import 'package:assence/state/user_profile_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// 같은 SharedPreferences로 앱을 다시 띄운 것처럼 스토어를 새로 만든다.
Future<AppStores> reopen(FakeGemini gemini) async =>
    AppStores.create(LocalStore(await SharedPreferences.getInstance()), gemini);

void main() {
  group('FeedStore', () {
    test('좋아요 토글은 카운트를 늘렸다 줄인다', () async {
      final AppStores stores = await createTestStores(FakeGemini());
      final Post post = stores.feed.posts.first;
      final int before = post.likes;

      stores.feed.toggleLike(post.id);
      expect(post.likes, before + 1);
      expect(post.likedByMe, isTrue);

      stores.feed.toggleLike(post.id);
      expect(post.likes, before);
      expect(post.likedByMe, isFalse);
    });

    test('페르소나 게시물에 댓글을 달면 작성자 답글과 알림이 생긴다', () async {
      final FakeGemini gemini = FakeGemini(reply: '고마워요!');
      final AppStores stores = await createTestStores(gemini);
      final Post post = stores.feed.posts.first;

      final Future<void> done = stores.feed.addComment(post.id, '  예뻐요  ');
      // 내 댓글은 응답을 기다리지 않고 바로 보인다.
      expect(post.comments.single.text, '예뻐요');
      expect(stores.feed.isReplyPending(post.comments.single.id), isTrue);
      await done;

      expect(post.comments, hasLength(2));
      final Comment reply = post.comments.last;
      expect(reply.authorId, post.authorId);
      expect(reply.parentId, post.comments.first.id);
      expect(reply.text, '고마워요!');
      expect(
        gemini.personas.single,
        contains(stores.personas.byId(post.authorId)!.prompt),
      );

      expect(stores.notifications.unreadCount, 1);
      expect(
        stores.notifications.items.single.type,
        NotificationType.commentReply,
      );
      stores.notifications.markAllRead();
      expect(stores.notifications.unreadCount, 0);
    });

    test('답글 실패는 기록하고, 다시 시도하면 답글이 달린다', () async {
      final FakeGemini gemini = FakeGemini(
        error: const GeminiException(GeminiErrorKind.network, 'offline'),
      );
      final AppStores stores = await createTestStores(gemini);
      final Post post = stores.feed.posts.first;

      await stores.feed.addComment(post.id, '안녕');
      final Comment mine = post.comments.single;
      expect(stores.feed.replyErrorOf(mine.id), isNotNull);

      gemini.error = null;
      await stores.feed.retryReply(mine.id);
      expect(stores.feed.replyErrorOf(mine.id), isNull);
      expect(post.comments, hasLength(2));
    });

    test('내 게시물을 올리면 맨 위에 추가되고 페르소나 반응이 달린다', () async {
      final AppStores stores = await createTestStores(
        FakeGemini(reply: '멋져요!'),
      );

      final Future<void> done = stores.feed.addPost(
        imagePath: '/tmp/me.jpg',
        caption: '첫 게시물',
      );
      final Post mine = stores.feed.posts.first;
      expect(mine.authorId, myUserId);
      await done;

      expect(mine.comments, hasLength(2));
      expect(
        mine.comments.map((Comment c) => c.authorId).toSet(),
        hasLength(2),
      );
      expect(stores.notifications.unreadCount, 2);
      expect(stores.feed.postsBy(myUserId), <Post>[mine]);
    });

    test('키가 없으면 내 게시물은 올라가지만 반응은 생략된다', () async {
      final AppStores stores = await createTestStores(
        FakeGemini(configured: false),
      );
      await stores.feed.addPost(imagePath: '/tmp/me.jpg', caption: '');
      expect(stores.feed.posts.first.comments, isEmpty);
      expect(stores.notifications.unreadCount, 0);
    });

    test('검색은 캡션·해시태그·이름·계정명을 본다', () async {
      final FeedStore feed = (await createTestStores(FakeGemini())).feed;
      expect(feed.search(''), hasLength(feed.posts.length));
      expect(feed.search('#러닝').single.id, 'seed_suyeon_running');
      expect(
        feed.search('나은').map((Post p) => p.authorId),
        everyElement('naeun'),
      );
      expect(feed.search('JIEUN_creative'), hasLength(2));
      expect(feed.search('존재하지않는검색어'), isEmpty);
    });

    test('좋아요·댓글·북마크는 앱을 다시 열어도 유지된다', () async {
      final FakeGemini gemini = FakeGemini(reply: '답글');
      final AppStores first = await createTestStores(gemini);
      final String postId = first.feed.posts.first.id;
      first.feed.toggleLike(postId);
      first.feed.toggleBookmark(postId);
      await first.feed.addComment(postId, '댓글');

      final AppStores second = await reopen(gemini);
      final Post restored = second.feed.byId(postId)!;
      expect(restored.likedByMe, isTrue);
      expect(restored.bookmarked, isTrue);
      expect(restored.comments.map((Comment c) => c.text), <String>[
        '댓글',
        '답글',
      ]);
      expect(second.feed.bookmarkedPosts.single.id, postId);
      expect(second.notifications.items, hasLength(1));
    });
  });

  group('ChatStore', () {
    test('답변을 받으면 history에 user/model 순서로 쌓인다', () async {
      final FakeGemini gemini = FakeGemini(reply: '반가워요');
      final AppStores stores = await createTestStores(gemini);

      await stores.chat.send('hayeon', '안녕');

      expect(
        stores.chat.historyOf('hayeon').map((ChatMessage m) => m.role),
        <String>['user', 'model'],
      );
      // 캐릭터 프로필 뒤에 공통 말투 규칙과 DM 상황 설명이 붙는다.
      final String system = gemini.personas.single;
      expect(system, contains(stores.personas.byId('hayeon')!.prompt));
      expect(system, contains('[말투 규칙]'));
      expect(system, contains('DM'));
      expect(stores.chat.historyOf('suyeon'), isEmpty);
    });

    test('실패해도 에러 문구는 history에 들어가지 않고, 재시도로 이어진다', () async {
      final FakeGemini gemini = FakeGemini(
        error: const GeminiException(
          GeminiErrorKind.http,
          '{}',
          statusCode: 500,
        ),
      );
      final AppStores stores = await createTestStores(gemini);

      await stores.chat.send('hayeon', '안녕');
      expect(stores.chat.historyOf('hayeon').single.isUser, isTrue);
      expect(stores.chat.errorOf('hayeon'), contains('500'));

      gemini.error = null;
      await stores.chat.retry('hayeon');
      expect(stores.chat.errorOf('hayeon'), isNull);
      expect(
        stores.chat.historyOf('hayeon').map((ChatMessage m) => m.text),
        <String>['안녕', 'AI 답변'],
      );
      // 재시도 요청에는 에러 문구가 섞이지 않은 history가 간다.
      expect(gemini.requests.last.single.text, '안녕');
    });

    test('대화와 커스텀 캐릭터는 앱을 다시 열어도 유지된다', () async {
      final FakeGemini gemini = FakeGemini();
      final AppStores first = await createTestStores(gemini);
      final Persona custom = first.personas.addCustom(
        name: '민서',
        prompt: '패션 에디터야',
      );
      await first.chat.send(custom.id, '옷 추천해줘');

      final AppStores second = await reopen(gemini);
      expect(second.personas.byId(custom.id)?.name, '민서');
      expect(second.chat.historyOf(custom.id), hasLength(2));

      second.chat.clearHistory(custom.id);
      second.personas.removeCustom(custom.id);
      final AppStores third = await reopen(gemini);
      expect(third.personas.byId(custom.id), isNull);
      expect(third.chat.historyOf(custom.id), isEmpty);
    });
  });

  group('StoryStore', () {
    test('내 스토리는 저장되고 24시간이 지나면 보이지 않는다', () async {
      DateTime now = DateTime(2026, 3, 1, 9);
      final LocalStore local = await openTestStore();
      final StoryStore first = StoryStore(local, now: () => now);
      first.addMyStory(imagePath: '', text: '  좋은 아침  ');
      expect(first.myActiveStories.single.text, '좋은 아침');

      now = now.add(const Duration(hours: 23));
      final StoryStore reopened = StoryStore(local, now: () => now);
      expect(reopened.myActiveStories, hasLength(1));

      now = now.add(const Duration(hours: 2));
      expect(reopened.myActiveStories, isEmpty);
    });

    test('카테고리 순서대로 페르소나 스토리를 돌려준다', () async {
      final StoryStore store = StoryStore(await openTestStore());
      expect(
        store
            .storiesOf(<String>['naeun', 'hayeon'])
            .map((Story s) => s.authorId),
        <String>['naeun', 'hayeon'],
      );
    });
  });

  group('UserProfileStore', () {
    test('계정명 규칙을 검사한다', () {
      String? check(String h) =>
          UserProfileStore.validateHandle(h, <String>['hayeon_daily']);
      expect(check('dldbswo_05'), isNull);
      expect(check('a.b_c'), isNull);
      expect(check(''), isNotNull);
      expect(check('Upper'), isNotNull);
      expect(check('공백 있음'), isNotNull);
      expect(check('.dot'), isNotNull);
      expect(check('dot.'), isNotNull);
      expect(check('a' * 31), isNotNull);
      expect(check('hayeon_daily'), isNotNull);
    });

    test('수정한 프로필은 다시 열어도 유지되고, 빈 이름은 기본값이 된다', () async {
      final LocalStore local = await openTestStore();
      UserProfileStore(
        local,
      ).update(handle: ' new_me ', name: '  ', bio: ' 안녕 ');
      final UserProfileStore reopened = UserProfileStore(local);
      expect(reopened.handle, 'new_me');
      expect(reopened.name, UserProfileStore.defaultName);
      expect(reopened.bio, '안녕');
    });
  });

  group('AI 상호작용', () {
    test('내 게시물의 AI 댓글에 답글을 달면 그 AI가 스레드로 이어서 답한다', () async {
      final FakeGemini gemini = FakeGemini(reply: '사진 너무 예뻐요!');
      final AppStores stores = await createTestStores(gemini);
      await stores.feed.addPost(imagePath: '/tmp/me.jpg', caption: '여행 사진');
      final Post mine = stores.feed.posts.first;
      final Comment aiComment = mine.comments.first;
      // 내 게시물에 내가 단 일반 댓글에는 아무도 답하지 않는다.
      await stores.feed.addComment(mine.id, '혼잣말');
      expect(mine.comments.last.authorId, myUserId);

      gemini.reply = '제주도 맞죠?';
      await stores.feed.addComment(mine.id, '고마워요!', replyToId: aiComment.id);

      final Comment myReply = mine.comments[mine.comments.length - 2];
      final Comment aiReply = mine.comments.last;
      expect(myReply.parentId, aiComment.id);
      expect(aiReply.authorId, aiComment.authorId);
      expect(aiReply.parentId, aiComment.id);
      expect(aiReply.replyToId, myReply.id);
      expect(aiReply.text, '제주도 맞죠?');
      // 스레드 맥락(AI의 첫 댓글 → 내 답글)이 프롬프트에 들어간다.
      final String prompt = gemini.requests.last.single.text;
      expect(prompt, contains('사진 너무 예뻐요!'));
      expect(prompt, contains('사용자: 고마워요!'));
      expect(prompt, contains('친구가 올린'));
    });

    test('페르소나 답글에 다시 답하면 대화가 같은 스레드로 이어진다', () async {
      final FakeGemini gemini = FakeGemini(reply: '첫 답글');
      final AppStores stores = await createTestStores(gemini);
      final Post post = stores.feed.byId('seed_hayeon_cafe')!;

      await stores.feed.addComment(post.id, '어디예요?');
      final Comment firstReply = post.comments.last;
      gemini.reply = '두 번째 답글';
      await stores.feed.addComment(
        post.id,
        '가보고 싶어요',
        replyToId: firstReply.id,
      );

      final Comment root = post.comments.first;
      expect(
        post.comments.skip(1).map((Comment c) => c.parentId),
        everyElement(root.id),
      );
      expect(post.comments.last.text, '두 번째 답글');
      expect(post.comments.last.authorId, 'hayeon');
      final String prompt = gemini.requests.last.single.text;
      expect(prompt, contains('하연: 첫 답글'));
      expect(prompt, contains('네가 올린'));
    });

    test('페르소나가 사진을 골라 캡션을 쓰고 새 게시물을 올린다', () async {
      final FakeGemini gemini = FakeGemini(reply: '오늘의 기록 #일상');
      final AppStores stores = await createTestStores(gemini);
      final String lastAuthor = stores.feed.posts.first.authorId;

      final Post? post = await stores.feed.createPersonaPost();

      expect(post, isNotNull);
      expect(stores.feed.posts.first, same(post));
      expect(post!.authorId, isNot(lastAuthor));
      expect(post.caption, '오늘의 기록 #일상');
      expect(
        personaPhotos[post.authorId]!.map((PersonaPhoto p) => p.path),
        contains(post.imagePath),
      );
      expect(stores.notifications.items.first.type, NotificationType.newPost);
      expect(stores.feed.isCreatingPost, isFalse);
    });
  });

  group('AiSettingsStore', () {
    GeminiService service(Future<http.Response> Function(http.Request) h) =>
        GeminiService(apiKey: '', client: MockClient(h));

    Future<http.Response> fakeApi(http.Request request) async {
      if (request.headers['x-goog-api-key'] != 'good-key') {
        return http.Response('{"error":{"message":"API key not valid"}}', 400);
      }
      if (request.method == 'GET') {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode(<String, dynamic>{
              'models': <dynamic>[
                <String, dynamic>{
                  'name': 'models/gemini-3.8-flash',
                  'supportedGenerationMethods': <String>['generateContent'],
                },
              ],
            }),
          ),
          200,
        );
      }
      return http.Response.bytes(
        utf8.encode(
          '{"candidates":[{"content":{"parts":[{"text":"안녕하세요!"}]}}]}',
        ),
        200,
      );
    }

    test('키를 저장하면 모델을 찾고 응답을 확인한 뒤 다시 열어도 유지된다', () async {
      final LocalStore local = await openTestStore();
      final GeminiService gemini = service(fakeApi);
      final AiSettingsStore ai = AiSettingsStore(local, gemini);
      expect(ai.isConfigured, isFalse);

      final String reply = await ai.saveAndTest('  good-key  ');
      expect(reply, '안녕하세요!');
      expect(ai.isConfigured, isTrue);
      expect(ai.model, 'gemini-3.8-flash');
      expect(ai.maskedKey, isNot(contains('good-key')));

      final GeminiService reopened = service(fakeApi);
      AiSettingsStore(local, reopened);
      expect(reopened.apiKey, 'good-key');
      expect(reopened.model, 'gemini-3.8-flash');

      await ai.clearKey();
      expect(ai.isConfigured, isFalse);
    });

    test('잘못된 키는 저장하지 않고 이전 상태로 되돌린다', () async {
      final LocalStore local = await openTestStore();
      final GeminiService gemini = service(fakeApi);
      final AiSettingsStore ai = AiSettingsStore(local, gemini);

      await expectLater(
        ai.saveAndTest('bad-key'),
        throwsA(
          isA<GeminiException>().having(
            (GeminiException e) => e.kind,
            'kind',
            GeminiErrorKind.invalidApiKey,
          ),
        ),
      );
      expect(ai.isConfigured, isFalse);
      expect(ai.isTesting, isFalse);
      final GeminiService reopened = service(fakeApi);
      AiSettingsStore(local, reopened);
      expect(reopened.apiKey, isEmpty);
    });
  });

  group('사람 같은 DM', () {
    test('빈 줄로 나뉜 답장은 말풍선 여러 개로 저장되고, 다음 요청에서는 합쳐진다', () async {
      final FakeGemini gemini = FakeGemini(
        reply: '**아 그거?**\n\n나 요즘 그거 진짜 빠졌잖아\n\n너는 요즘 뭐 해?',
      );
      final AppStores stores = await createTestStores(gemini);
      stores.chat.bubbleGap = () => Duration.zero;

      await stores.chat.send('jieun', '요즘 관심사가 뭔데?');

      expect(
        stores.chat.historyOf('jieun').map((ChatMessage m) => m.text),
        <String>['요즘 관심사가 뭔데?', '아 그거?', '나 요즘 그거 진짜 빠졌잖아', '너는 요즘 뭐 해?'],
      );

      gemini.reply = 'ㅋㅋ';
      await stores.chat.send('jieun', '나는 그냥 집');
      // 저장된 말풍선이 그대로 서비스에 넘어간다 (합치기는 GeminiService가 한다).
      final List<ChatMessage> sent = gemini.requests.last;
      expect(sent.map((ChatMessage m) => m.role), <String>[
        'user',
        'model',
        'model',
        'model',
        'user',
      ]);
    });
  });
}

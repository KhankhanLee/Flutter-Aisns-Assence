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
        startsWith(stores.personas.byId(post.authorId)!.prompt),
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
      expect(gemini.personas.single, stores.personas.byId('hayeon')!.prompt);
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
}

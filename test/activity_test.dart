import 'dart:math';

import 'package:assence/app.dart';
import 'package:assence/data/seed_data.dart';
import 'package:assence/models/chat_message.dart';
import 'package:assence/models/comment.dart';
import 'package:assence/models/post.dart';
import 'package:assence/models/story.dart';
import 'package:assence/services/background.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/services/notification_service.dart';
import 'package:assence/state/activity_runner.dart';
import 'package:assence/state/ai_budget.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// 띄운 알림을 기록만 하는 가짜.
class _RecordingNotifier implements Notifier {
  final List<({ActivityEvent event, String name})> shown =
      <({ActivityEvent event, String name})>[];

  @override
  Future<void> show({
    required ActivityEvent event,
    required String personaName,
  }) async => shown.add((event: event, name: personaName));
}

void main() {
  group('하루 AI 예산', () {
    test('하루 상한까지만 쓰고, 다음 날 다시 쓸 수 있다', () async {
      DateTime now = DateTime(2026, 10, 18, 10);
      final AiBudget budget = AiBudget(await openTestStore(), now: () => now);
      for (int i = 0; i < AiBudget.dailyLimit; i++) {
        expect(budget.trySpend(), isTrue);
      }
      expect(budget.trySpend(), isFalse);
      expect(budget.hasRoom, isFalse);
      now = now.add(const Duration(days: 1));
      expect(budget.trySpend(), isTrue);
    });
  });

  group('AI 친구끼리 반응', () {
    Future<(AppStores, Post, DateTime Function(), void Function(Duration))>
    postWithComments() async {
      for (int seed = 0; ; seed++) {
        DateTime now = DateTime(2026, 10, 18, 12);
        final AppStores stores = AppStores.create(
          await openTestStore(),
          FakeGemini(reply: '와 분위기 좋다'),
          now: () => now,
          random: Random(seed),
        );
        final Post post = (await stores.feed.createPersonaPost(
          personaId: 'hayeon',
          at: now,
        ))!;
        if (post.friendReactions.any((FriendReaction r) => r.comment)) {
          return (stores, post, () => now, (Duration d) => now = now.add(d));
        }
      }
    }

    test('게시물을 올리면 다른 친구들의 반응 일정이 활동 시간 안에 잡힌다', () async {
      final (_, Post post, _, _) = await postWithComments();
      expect(
        post.friendReactions.map((FriendReaction r) => r.personaId),
        isNot(contains('hayeon')),
      );
      expect(
        post.friendReactions.where((FriendReaction r) => r.comment).length,
        lessThanOrEqualTo(2),
      );
      for (final FriendReaction r in post.friendReactions) {
        expect(r.at.isAfter(post.createdAt), isTrue);
        expect(personaHabits[r.personaId]!.isActiveAt(r.at), isTrue);
      }
    });

    test('시각이 지나면 좋아요가 보이고 댓글이 달리며, 주인 답글은 스레드로 붙는다', () async {
      final (
        AppStores stores,
        Post post,
        DateTime Function() now,
        void Function(Duration) advance,
      ) = await postWithComments();
      final List<FriendReaction> planned = List<FriendReaction>.of(
        post.friendReactions,
      );
      expect(post.friendLikersAt(now()), isEmpty);
      expect(await stores.feed.runFriendReactions(budget: stores.budget), 0);

      for (int hour = 0; hour < 40; hour++) {
        advance(const Duration(hours: 1));
        await stores.feed.runFriendReactions(budget: stores.budget);
      }

      expect(
        post.friendLikersAt(now()).toSet(),
        planned
            .where((FriendReaction r) => r.liked)
            .map((FriendReaction r) => r.personaId)
            .toSet(),
      );
      final Set<String> commenters = planned
          .where((FriendReaction r) => r.comment)
          .map((FriendReaction r) => r.personaId)
          .toSet();
      final List<Comment> friendComments = post.comments
          .where((Comment c) => c.parentId == null)
          .toList();
      expect(friendComments.map((Comment c) => c.authorId).toSet(), commenters);
      for (final Comment reply in post.comments.where(
        (Comment c) => c.parentId != null,
      )) {
        expect(reply.authorId, 'hayeon');
        expect(
          commenters,
          contains(
            post.comments
                .firstWhere((Comment c) => c.id == reply.replyToId)
                .authorId,
          ),
        );
      }
      expect(
        post.friendReactions.where((FriendReaction r) => r.comment && !r.done),
        isEmpty,
      );
    });

    test('저장했다 다시 열어도 반응 일정이 남아 있다', () async {
      final LocalStore local = await openTestStore();
      final DateTime now = DateTime(2026, 10, 18, 12);
      final AppStores stores = AppStores.create(
        local,
        FakeGemini(),
        now: () => now,
        random: Random(3),
      );
      final Post post = (await stores.feed.createPersonaPost(
        personaId: 'suyeon',
        at: now,
      ))!;
      final Post reopened = AppStores.create(
        local,
        FakeGemini(),
        now: () => now,
      ).feed.byId(post.id)!;
      expect(reopened.friendReactions.length, post.friendReactions.length);
    });
  });

  group('AI 친구 스토리', () {
    test('처음엔 시드 스토리로 시작하고, 예정 시각이 되면 자기 사진으로 새 스토리를 올린다', () async {
      final LocalStore local = await openTestStore();
      DateTime now = DateTime(2026, 10, 18, 12);
      final FakeGemini gemini = FakeGemini(reply: '오늘 라떼 맛집 발견');
      final AppStores stores = AppStores.create(
        local,
        gemini,
        now: () => now,
        random: Random(1),
      );
      expect(
        stores.stories.storiesOf(<String>['hayeon']).single.id,
        'hayeon_story',
      );

      now = stores.stories.nextStoryTimes['hayeon']!.add(
        const Duration(minutes: 1),
      );
      final List<Story> posted = await stores.stories.runScheduledStories(
        gemini: gemini,
        personas: stores.personas.all,
        budget: stores.budget,
      );
      final Story story = posted.firstWhere(
        (Story s) => s.authorId == 'hayeon',
      );
      expect(story.text, '오늘 라떼 맛집 발견');
      expect(
        personaPhotos['hayeon']!.map((PersonaPhoto p) => p.path),
        contains(story.imagePath),
      );
      expect(gemini.backgrounds.last, isTrue);
      expect(stores.stories.nextStoryTimes['hayeon']!.isAfter(now), isTrue);

      // 다시 열어도 남아 있고, 하루가 지나면 사라진다.
      now = now.add(const Duration(hours: 1));
      final AppStores reopened = AppStores.create(
        local,
        gemini,
        now: () => now,
      );
      expect(
        reopened.stories.storiesOf(<String>['hayeon']).map((Story s) => s.id),
        contains(story.id),
      );
      now = now.add(const Duration(days: 1));
      expect(reopened.stories.storiesOf(<String>['hayeon']), isEmpty);
    });

    test('문구를 못 받으면 올리지 않고 한 시간 뒤로 미룬다', () async {
      DateTime now = DateTime(2026, 10, 18, 12);
      final FakeGemini gemini = FakeGemini(
        error: const GeminiException(GeminiErrorKind.rateLimited, 'quota'),
      );
      final AppStores stores = AppStores.create(
        await openTestStore(),
        gemini,
        now: () => now,
        random: Random(1),
      );
      now = stores.stories.nextStoryTimes['hayeon']!.add(
        const Duration(minutes: 1),
      );
      final List<Story> posted = await stores.stories.runScheduledStories(
        gemini: gemini,
        personas: stores.personas.all,
        budget: stores.budget,
      );
      expect(posted.where((Story s) => s.authorId == 'hayeon'), isEmpty);
      expect(
        stores.stories.nextStoryTimes['hayeon'],
        now.add(const Duration(hours: 1)),
      );
    });
  });

  group('AI 친구가 먼저 DM', () {
    Future<(AppStores, void Function(DateTime))> storesAt(
      DateTime start,
    ) async {
      DateTime now = start;
      final AppStores stores = AppStores.create(
        await openTestStore(),
        FakeGemini(reply: '뭐해?\n\n나 오늘 보리 병원 다녀왔어'),
        now: () => now,
        random: Random(2),
      );
      stores.chat.bubbleGap = () => Duration.zero;
      return (stores, (DateTime t) => now = t);
    }

    test('예정 시각이 되면 먼저 말을 걸고, 안 읽음으로 표시된다', () async {
      final (AppStores stores, void Function(DateTime) setNow) = await storesAt(
        DateTime(2026, 10, 18, 12),
      );
      final DateTime due = stores.chat.nextOpenerTimes['hayeon']!;
      setNow(due.add(const Duration(minutes: 1)));

      final List<String> sent = await stores.chat.runOpeners(
        budget: stores.budget,
      );
      expect(sent, contains('hayeon'));
      expect(
        stores.chat.historyOf('hayeon').map((ChatMessage m) => m.text),
        <String>['뭐해?', '나 오늘 보리 병원 다녀왔어'],
      );
      expect(stores.chat.isUnread('hayeon'), isTrue);
      expect(stores.chat.nextOpenerTimes['hayeon']!.isAfter(due), isTrue);
    });

    test('답하지 않은 메시지가 있으면 또 보내지 않는다', () async {
      final (AppStores stores, void Function(DateTime) setNow) = await storesAt(
        DateTime(2026, 10, 18, 12),
      );
      setNow(
        stores.chat.nextOpenerTimes['hayeon']!.add(const Duration(minutes: 1)),
      );
      await stores.chat.runOpeners(budget: stores.budget);
      final int count = stores.chat.historyOf('hayeon').length;

      setNow(
        stores.chat.nextOpenerTimes['hayeon']!.add(const Duration(minutes: 1)),
      );
      expect(
        await stores.chat.runOpeners(budget: stores.budget),
        isNot(contains('hayeon')),
      );
      expect(stores.chat.historyOf('hayeon').length, count);
    });
  });

  group('활동 실행과 폰 알림', () {
    test('runDue는 새 게시물과 먼저 보낸 DM을 이벤트로 돌려준다', () async {
      DateTime now = DateTime(2026, 10, 18, 12);
      final AppStores stores = AppStores.create(
        await openTestStore(),
        FakeGemini(reply: '오늘 날씨 좋다'),
        now: () => now,
        random: Random(4),
      );
      stores.chat.bubbleGap = () => Duration.zero;
      // 일주일 뒤면 모두 할 차례가 된다.
      now = now.add(const Duration(days: 7));

      final List<ActivityEvent> events = await stores.runner.runDue();
      final Set<ActivityKind> kinds = events
          .map((ActivityEvent e) => e.kind)
          .toSet();
      expect(
        kinds,
        containsAll(<ActivityKind>[ActivityKind.newPost, ActivityKind.dm]),
      );
      for (final ActivityEvent e in events) {
        if (e.kind == ActivityKind.dm) expect(e.target, 'chat:${e.personaId}');
        if (e.kind == ActivityKind.newPost) {
          expect(e.target, startsWith('post:'));
        }
      }
    });

    test('백그라운드 작업은 알림을 켠 종류만 띄우고, 앱이 떠 있으면 건너뛴다', () async {
      final LocalStore local = await openTestStore();
      final DateTime start = DateTime(2026, 10, 18, 12);
      // 처음 실행: 일정만 잡힌다.
      final AppStores first = AppStores.create(
        local,
        FakeGemini(),
        now: () => start,
        random: Random(5),
      );
      final _RecordingNotifier notifier = _RecordingNotifier();
      final DateTime later = start.add(const Duration(days: 7));
      final GeminiService gemini = FakeGemini(reply: '오늘 날씨 좋다');

      // 알림이 꺼져 있으면 아무것도 하지 않는다.
      expect(
        await BackgroundActivity.run(
          local: local,
          gemini: gemini,
          notifier: notifier,
          now: () => later,
        ),
        0,
      );

      first.notificationSettings.update(enabled: true, activity: false);
      // 앱이 화면에 떠 있으면 건너뛴다.
      await AppPresence.markForeground(local, later);
      expect(
        await BackgroundActivity.run(
          local: local,
          gemini: gemini,
          notifier: notifier,
          now: () => later,
        ),
        0,
      );

      await AppPresence.markBackground(local);
      final int shown = await BackgroundActivity.run(
        local: local,
        gemini: gemini,
        notifier: notifier,
        now: () => later,
      );
      expect(shown, greaterThan(0));
      expect(
        notifier.shown.map(
          (({ActivityEvent event, String name}) s) => s.event.kind,
        ),
        everyElement(
          isIn(<ActivityKind>[ActivityKind.dm, ActivityKind.storyDm]),
        ),
      );
      expect(
        seedPersonas.map((p) => p.name),
        contains(notifier.shown.first.name),
      );
      expect(local.readJson(BackgroundActivity.revisionKey), 1);
    });

    test('알림 문구', () {
      const ActivityEvent dm = ActivityEvent(
        kind: ActivityKind.storyDm,
        personaId: 'hayeon',
        text: '어디야?',
      );
      expect(notificationText(dm, '하연'), (
        title: '하연',
        body: '회원님의 스토리에 답장: 어디야?',
      ));
    });
  });
}

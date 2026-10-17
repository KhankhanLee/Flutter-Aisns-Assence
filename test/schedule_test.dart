import 'dart:math';

import 'package:assence/data/seed_data.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/post.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/services/post_image_source.dart';
import 'package:assence/state/feed_store.dart';
import 'package:assence/state/notification_store.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/state/post_schedule.dart';
import 'package:assence/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

class FakeImageSource implements PostImageSource {
  @override
  bool isEnabled = true;
  Object? error;
  final List<String> scenes = <String>[];

  @override
  Future<String> create({
    required Persona persona,
    required String scene,
  }) async {
    scenes.add(scene);
    final Object? e = error;
    if (e != null) throw e;
    return '/data/ai_posts/${persona.id}_${scenes.length}.png';
  }
}

/// 시계를 마음대로 돌릴 수 있는 FeedStore.
class Harness {
  DateTime now;
  final FakeGemini gemini;
  final LocalStore local;
  final FakeImageSource? images;
  late FeedStore feed;

  Harness._(this.now, this.gemini, this.local, this.images) {
    feed = build();
  }

  static Future<Harness> create({
    FakeGemini? gemini,
    FakeImageSource? images,
    DateTime? start,
  }) async => Harness._(
    start ?? DateTime(2026, 10, 17, 12),
    gemini ?? FakeGemini(reply: '오늘의 기록 #일상'),
    await openTestStore(),
    images,
  );

  /// 같은 저장소로 앱을 다시 연 것처럼 새 FeedStore를 만든다.
  FeedStore build() => FeedStore(
    local,
    gemini,
    PersonaStore(local),
    NotificationStore(local),
    imageSource: images,
    random: Random(7),
    now: () => now,
  );

  List<Post> personaPostsSince(DateTime since) => feed.posts
      .where((Post p) => p.authorId != myUserId && p.createdAt.isAfter(since))
      .toList();
}

void main() {
  group('PostingHabit', () {
    test('평균 간격의 60~140% 뒤, 활동 시간대 안에서 다음 시각을 고른다', () {
      const PostingHabit habit = PostingHabit(
        postsPerWeek: 2,
        startHour: 21,
        endHour: 26,
      );
      final Random random = Random(1);
      final DateTime from = DateTime(2026, 10, 1, 22);
      for (int i = 0; i < 200; i++) {
        final DateTime next = habit.nextAfter(from, random);
        final Duration gap = next.difference(from);
        expect(gap.inHours, greaterThanOrEqualTo((84 * 0.6).floor()));
        // 시간대 맞추느라 하루 안쪽으로 더 밀릴 수 있다.
        expect(gap.inHours, lessThanOrEqualTo((84 * 1.4).ceil() + 24));
        expect(habit.isActiveAt(next), isTrue, reason: '$next');
      }
    });

    test('자정을 넘기는 시간대를 처리한다', () {
      const PostingHabit night = PostingHabit(
        postsPerWeek: 2,
        startHour: 21,
        endHour: 26,
      );
      expect(night.isActiveAt(DateTime(2026, 1, 1, 23)), isTrue);
      expect(night.isActiveAt(DateTime(2026, 1, 1, 1)), isTrue);
      expect(night.isActiveAt(DateTime(2026, 1, 1, 2)), isFalse);
      expect(night.isActiveAt(DateTime(2026, 1, 1, 15)), isFalse);
      final DateTime moved = night.fitActiveHours(
        DateTime(2026, 1, 1, 15),
        Random(3),
      );
      expect(moved.isAfter(DateTime(2026, 1, 1, 21)), isTrue);
      expect(night.isActiveAt(moved), isTrue);
    });

    test('모든 페르소나는 하루 1번 이하, 일주일 2번 이상 올린다', () {
      for (final PostingHabit habit in personaHabits.values) {
        expect(habit.postsPerWeek, inInclusiveRange(2, 7));
      }
      expect(personaHabits.keys.toSet(), personaPhotos.keys.toSet());
    });
  });

  group('예약 게시', () {
    test('처음 열면 모든 페르소나가 미래 시각으로 예약되고 바로 올리지 않는다', () async {
      final Harness h = await Harness.create();
      expect(h.feed.nextPostTimes.keys.toSet(), personaHabits.keys.toSet());

      final int before = h.feed.posts.length;
      expect(await h.feed.runScheduledPosts(), 0);
      expect(h.feed.posts.length, before);
    });

    test('2주 동안 매시간 확인해도 각 페르소나는 습관대로만 올린다', () async {
      final Harness h = await Harness.create();
      final DateTime start = h.now;
      for (int hour = 0; hour < 24 * 14; hour++) {
        h.now = start.add(Duration(hours: hour));
        await h.feed.runScheduledPosts();
      }

      final List<Post> posts = h.personaPostsSince(start);
      for (final MapEntry<String, PostingHabit> habit
          in personaHabits.entries) {
        final List<Post> mine =
            posts.where((Post p) => p.authorId == habit.key).toList()
              ..sort((Post a, Post b) => a.createdAt.compareTo(b.createdAt));
        final double perWeek = mine.length / 2;
        expect(
          perWeek,
          inInclusiveRange(
            habit.value.postsPerWeek * 0.5,
            habit.value.postsPerWeek * 1.5,
          ),
          reason: '${habit.key}: ${mine.length}개',
        );
        for (int i = 1; i < mine.length; i++) {
          // 같은 캐릭터가 짧은 시간에 연달아 올리지 않는다.
          expect(
            mine[i].createdAt.difference(mine[i - 1].createdAt).inHours,
            greaterThanOrEqualTo(12),
          );
        }
        for (final Post p in mine) {
          expect(habit.value.isActiveAt(p.createdAt), isTrue);
        }
      }
    });

    test('오래 안 열었다 열어도 한 번에 최대 2개만 올리고 나머지는 미룬다', () async {
      final Harness h = await Harness.create();
      final DateTime start = h.now;
      h.now = start.add(const Duration(days: 10));

      expect(await h.feed.runScheduledPosts(), FeedStore.maxPostsPerCheck);
      expect(h.personaPostsSince(start), hasLength(FeedStore.maxPostsPerCheck));
      // 다음 확인 때 밀린 페르소나가 또 한꺼번에 올리지 않도록 모두 미래로 미뤄졌다.
      for (final DateTime next in h.feed.nextPostTimes.values) {
        expect(next.isAfter(h.now), isTrue);
      }
      expect(await h.feed.runScheduledPosts(), 0);
    });

    test('예정 시각으로 기록되고 피드에서 시간 순서를 지킨다', () async {
      final Harness h = await Harness.create();
      final MapEntry<String, DateTime> first = h.feed.nextPostTimes.entries
          .reduce(
            (MapEntry<String, DateTime> a, MapEntry<String, DateTime> b) =>
                a.value.isBefore(b.value) ? a : b,
          );
      h.now = first.value.add(const Duration(hours: 3));

      await h.feed.runScheduledPosts();

      final Post post = h.feed.posts.firstWhere(
        (Post p) =>
            p.authorId == first.key &&
            p.createdAt.isAfter(DateTime(2026, 10, 17, 12)),
      );
      expect(post.createdAt, first.value);
      final List<DateTime> times = h.feed.posts
          .map((Post p) => p.createdAt)
          .toList();
      for (int i = 1; i < times.length; i++) {
        expect(times[i].isAfter(times[i - 1]), isFalse);
      }
    });

    test('키가 없으면 올리지 않고, 실패하면 한 시간 뒤 다시 시도한다', () async {
      final Harness noKey = await Harness.create(
        gemini: FakeGemini(configured: false),
      );
      noKey.now = noKey.now.add(const Duration(days: 5));
      expect(await noKey.feed.runScheduledPosts(), 0);

      final FakeGemini failing = FakeGemini(
        error: const GeminiException(
          GeminiErrorKind.http,
          'quota',
          statusCode: 429,
        ),
      );
      final Harness h = await Harness.create(gemini: failing);
      h.now = h.now.add(const Duration(days: 5));
      expect(await h.feed.runScheduledPosts(), 0);
      expect(
        h.feed.nextPostTimes.values.where(
          (DateTime t) => t == h.now.add(const Duration(hours: 1)),
        ),
        hasLength(1),
      );
    });

    test('일정은 앱을 다시 열어도 유지된다', () async {
      final Harness h = await Harness.create();
      final Map<String, DateTime> before = Map<String, DateTime>.of(
        h.feed.nextPostTimes,
      );
      expect(h.build().nextPostTimes, before);
    });

    test('formatTimeUntil', () {
      final DateTime now = DateTime(2026, 10, 17, 12);
      expect(formatTimeUntil(now, now: now), '곧');
      expect(
        formatTimeUntil(now.add(const Duration(minutes: 40)), now: now),
        '40분 후',
      );
      expect(
        formatTimeUntil(now.add(const Duration(hours: 5)), now: now),
        '5시간 후',
      );
      expect(formatTimeUntil(DateTime(2026, 10, 18, 15), now: now), '내일 오후 3시');
      expect(formatTimeUntil(DateTime(2026, 10, 20, 15), now: now), '3일 후');
    });
  });

  group('AI 사진 생성', () {
    test('켜져 있으면 장면을 정해 새 사진으로 올리고 캡션도 그 장면으로 쓴다', () async {
      final FakeImageSource images = FakeImageSource();
      final FakeGemini gemini = FakeGemini(reply: '한강 노을 아래 러닝');
      final Harness h = await Harness.create(gemini: gemini, images: images);

      final Post? post = await h.feed.createPersonaPost(personaId: 'suyeon');

      expect(post!.imagePath, '/data/ai_posts/suyeon_1.png');
      expect(images.scenes.single, '한강 노을 아래 러닝');
      // 마지막 요청(캡션)에 장면 묘사가 들어간다.
      expect(gemini.requests.last.single.text, contains('한강 노을 아래 러닝'));
    });

    test('사진 생성이 실패하면 기존 사진으로 올리고 한동안 다시 시도하지 않는다', () async {
      final FakeImageSource images = FakeImageSource()
        ..error = Exception('quota');
      final Harness h = await Harness.create(images: images);

      final Post? first = await h.feed.createPersonaPost(personaId: 'naeun');
      expect(
        personaPhotos['naeun']!.map((PersonaPhoto p) => p.path),
        contains(first!.imagePath),
      );
      expect(images.scenes, hasLength(1));

      await h.feed.createPersonaPost(personaId: 'naeun');
      expect(images.scenes, hasLength(1), reason: '재시도 대기 중');

      h.now = h.now.add(FeedStore.imageRetryDelay);
      images.error = null;
      final Post? third = await h.feed.createPersonaPost(personaId: 'naeun');
      expect(third!.imagePath, startsWith('/data/ai_posts/'));
    });

    test('꺼져 있으면 사진을 만들지 않는다', () async {
      final FakeImageSource images = FakeImageSource()..isEnabled = false;
      final Harness h = await Harness.create(images: images);
      await h.feed.createPersonaPost(personaId: 'jieun');
      expect(images.scenes, isEmpty);
    });
  });
}

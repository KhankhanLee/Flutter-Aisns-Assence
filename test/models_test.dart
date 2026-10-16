import 'package:assence/data/seed_data.dart';
import 'package:assence/models/app_notification.dart';
import 'package:assence/models/comment.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/post.dart';
import 'package:assence/models/story.dart';
import 'package:assence/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JSON 왕복', () {
    test('Post와 Comment', () {
      final Post post = Post(
        id: 'p1',
        authorId: 'hayeon',
        imagePath: 'images/Hayeon/Cafe.jpg',
        caption: '캡션',
        createdAt: DateTime.utc(2026, 1, 2, 3),
        likes: 5,
        likedByMe: true,
        bookmarked: true,
        comments: <Comment>[
          Comment(
            id: 'c1',
            postId: 'p1',
            authorId: myUserId,
            text: '댓글',
            createdAt: DateTime.utc(2026, 1, 2, 4),
          ),
          Comment(
            id: 'c2',
            postId: 'p1',
            authorId: 'hayeon',
            text: '답글',
            createdAt: DateTime.utc(2026, 1, 2, 5),
            parentId: 'c1',
          ),
        ],
      );

      final Post copy = Post.fromJson(post.toJson());
      expect(copy.toJson(), post.toJson());
      expect(copy.comments[1].parentId, 'c1');
    });

    test('Persona, Story, AppNotification', () {
      const Persona persona = Persona(
        id: 'custom_1',
        name: '민서',
        handle: 'minseo',
        bio: '패션',
        prompt: '프롬프트',
        isCustom: true,
      );
      expect(Persona.fromJson(persona.toJson()).toJson(), persona.toJson());

      final Story story = Story(
        id: 's1',
        authorId: myUserId,
        imagePath: '/tmp/a.jpg',
        text: '안녕',
        createdAt: DateTime.utc(2026),
      );
      expect(Story.fromJson(story.toJson()).toJson(), story.toJson());

      final AppNotification n = AppNotification(
        id: 'n1',
        type: NotificationType.commentReply,
        personaId: 'hayeon',
        postId: 'p1',
        text: '답글',
        createdAt: DateTime.utc(2026),
      );
      expect(AppNotification.fromJson(n.toJson()).toJson(), n.toJson());
    });
  });

  test('시드 게시물과 스토리는 모두 존재하는 페르소나를 가리킨다', () {
    final Set<String> ids = seedPersonas.map((Persona p) => p.id).toSet();
    final DateTime now = DateTime(2026);
    expect(
      buildSeedPosts(now).map((Post p) => p.authorId),
      everyElement(isIn(ids)),
    );
    expect(
      buildSeedPersonaStories(now).map((Story s) => s.authorId),
      everyElement(isIn(ids)),
    );
    for (final StoryCategory category in storyCategories) {
      expect(category.personaIds, everyElement(isIn(ids)));
    }
  });

  test('스토리는 24시간 뒤 만료된다', () {
    final DateTime created = DateTime(2026, 1, 1, 12);
    final Story story = Story(
      id: 's',
      authorId: 'me',
      imagePath: '',
      text: '',
      createdAt: created,
    );
    expect(story.isActive(created.add(const Duration(hours: 23))), isTrue);
    expect(story.isActive(created.add(const Duration(hours: 24))), isFalse);
  });

  test('formatCount와 formatTimeAgo', () {
    expect(formatCount(0), '0');
    expect(formatCount(999), '999');
    expect(formatCount(1240), '1,240');
    expect(formatCount(1234567), '1,234,567');

    final DateTime now = DateTime(2026, 5, 10, 12);
    expect(formatTimeAgo(now, now: now), '방금 전');
    expect(
      formatTimeAgo(now.subtract(const Duration(minutes: 5)), now: now),
      '5분 전',
    );
    expect(
      formatTimeAgo(now.subtract(const Duration(hours: 3)), now: now),
      '3시간 전',
    );
    expect(
      formatTimeAgo(now.subtract(const Duration(days: 2)), now: now),
      '2일 전',
    );
    expect(formatTimeAgo(DateTime(2026, 4, 1), now: now), '2026.4.1');
  });

  test('newId는 연속 호출해도 겹치지 않는다', () {
    final Set<String> ids = List<String>.generate(
      100,
      (_) => newId('x'),
    ).toSet();
    expect(ids.length, 100);
  });
}

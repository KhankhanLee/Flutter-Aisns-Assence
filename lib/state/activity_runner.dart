import 'package:assence/app.dart';
import 'package:assence/models/app_notification.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/story.dart';
import 'package:assence/state/story_store.dart';

/// 알림으로 보여줄 만한 AI 친구의 활동 종류.
enum ActivityKind {
  /// 먼저 보낸 DM.
  dm,

  /// 내 스토리를 보고 보낸 DM.
  storyDm,

  /// 내 댓글이나 게시물에 단 댓글·답글.
  comment,

  /// 새 게시물.
  newPost,

  /// 새 스토리.
  friendStory,
}

class ActivityEvent {
  final ActivityKind kind;
  final String personaId;
  final String text;

  /// 알림을 누르면 갈 곳: `chat:<personaId>` 또는 `post:<postId>`. 없으면 홈.
  final String? target;

  const ActivityEvent({
    required this.kind,
    required this.personaId,
    required this.text,
    this.target,
  });
}

/// AI 친구들이 알아서 하는 활동을 한 번에 처리한다. 앱이 켜져 있을 때는 홈 화면이
/// 주기적으로, 앱이 닫혀 있을 때는 백그라운드 작업이 부른다.
class ActivityRunner {
  final AppStores stores;
  bool _running = false;

  ActivityRunner(this.stores);

  /// 할 차례가 된 활동을 처리하고, 새로 생긴 일을 돌려준다.
  /// 이미 실행 중이면 아무것도 하지 않는다.
  Future<List<ActivityEvent>> runDue() async {
    if (_running || !stores.ai.isConfigured) return <ActivityEvent>[];
    _running = true;
    final List<ActivityEvent> events = <ActivityEvent>[];
    final Set<String> seenNotifications = <String>{
      for (final AppNotification n in stores.notifications.items) n.id,
    };
    try {
      // 1. 예약 게시물 (알림 목록에 새 게시물 알림이 생긴다)
      await stores.feed.runScheduledPosts();

      // 2. 내 스토리를 본 친구의 DM
      for (final DueStoryReply due in stories.dueReplies()) {
        final bool sent = await stores.chat.receiveStoryReaction(
          due.view.personaId,
          due.story,
        );
        if (!sent) break;
        stories.markReplied(due.view);
        events.add(_dmEvent(ActivityKind.storyDm, due.view.personaId));
      }

      // 3. 먼저 보내는 DM
      for (final String id in await stores.chat.runOpeners(
        budget: stores.budget,
      )) {
        events.add(_dmEvent(ActivityKind.dm, id));
      }

      // 4. 친구 스토리
      final List<Story> newStories = await stories.runScheduledStories(
        gemini: stores.gemini,
        personas: stores.personas.all,
        budget: stores.budget,
      );
      for (final Story story in newStories) {
        events.add(
          ActivityEvent(
            kind: ActivityKind.friendStory,
            personaId: story.authorId,
            text: story.text.isEmpty ? '새 스토리를 올렸어요' : story.text,
          ),
        );
      }

      // 5. AI 친구끼리 댓글
      await stores.feed.runFriendReactions(budget: stores.budget);
    } finally {
      _running = false;
    }

    // 이번에 새로 생긴 알림(새 게시물, 내 게시물·댓글에 단 댓글)도 알린다.
    for (final AppNotification n in stores.notifications.items.reversed) {
      if (seenNotifications.contains(n.id)) continue;
      events.add(
        ActivityEvent(
          kind: n.type == NotificationType.newPost
              ? ActivityKind.newPost
              : ActivityKind.comment,
          personaId: n.personaId,
          text: n.text,
          target: 'post:${n.postId}',
        ),
      );
    }
    return events;
  }

  StoryStore get stories => stores.stories;

  ActivityEvent _dmEvent(ActivityKind kind, String personaId) {
    final String text =
        stores.chat.lastMessageOf(personaId)?.text ?? '메시지를 보냈어요';
    return ActivityEvent(
      kind: kind,
      personaId: personaId,
      text: text,
      target: 'chat:$personaId',
    );
  }

  /// 알림 제목에 쓸 이름.
  String nameOf(String personaId) {
    final Persona? persona = stores.personas.byId(personaId);
    return persona?.name ?? personaId;
  }
}

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:assence/data/seed_data.dart';
import 'package:assence/models/app_notification.dart';
import 'package:assence/models/comment.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/post.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/image_bytes.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/services/post_image_source.dart';
import 'package:assence/state/ai_budget.dart';
import 'package:assence/state/notification_store.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/state/post_schedule.dart';
import 'package:assence/utils/format.dart';

class FeedStore extends ChangeNotifier {
  static const String _storageKey = 'posts';
  static const String _scheduleKey = 'persona_next_post';
  static const int _reactionCount = 2;

  /// 한 번 확인할 때 올리는 최대 게시물 수. 오래 앱을 안 열어도 한꺼번에 몰리지 않게 한다.
  static const int maxPostsPerCheck = 2;

  /// AI 친구끼리 반응: 친구 게시물에 좋아요를 누를 확률, 댓글을 달 확률,
  /// 게시물당 댓글 수 상한, 게시물 주인이 그 댓글에 답글을 달 확률.
  static const double friendLikeChance = 0.7;
  static const double friendCommentChance = 0.35;
  static const int maxFriendComments = 2;
  static const double ownerReplyChance = 0.4;

  /// 한 번 확인할 때 다는 AI 친구 댓글 수 상한.
  static const int maxFriendCommentsPerCheck = 2;

  /// 사진 생성이 실패하면 이 시간 동안은 시도하지 않고 기존 사진을 쓴다.
  static const Duration imageRetryDelay = Duration(hours: 12);

  final LocalStore _local;
  final GeminiService _gemini;
  final PersonaStore _personas;
  final NotificationStore _notifications;
  final PostImageSource? _imageSource;
  final Random _random;
  final DateTime Function() _now;

  final List<Post> _posts = <Post>[]; // 최신순
  final Set<String> _pendingReplies = <String>{}; // 답글을 기다리는 댓글 ID
  final Map<String, String> _failedReplies =
      <String, String>{}; // 댓글 ID → 안내 문구
  bool _creatingPost = false;
  bool _checkingSchedule = false;

  /// 페르소나 ID → 다음 게시 예정 시각.
  final Map<String, DateTime> _nextPostAt = <String, DateTime>{};
  DateTime? _imageDisabledUntil;

  /// 게시물 사진을 AI 요청용으로 읽는다. 테스트에서는 바꿔 끼운다.
  Future<ChatImage?> Function(String path) imageLoader = loadChatImage;

  FeedStore(
    this._local,
    this._gemini,
    this._personas,
    this._notifications, {
    PostImageSource? imageSource,
    Random? random,
    DateTime Function()? now,
  }) : _imageSource = imageSource,
       _random = random ?? Random(),
       _now = now ?? DateTime.now {
    final Object? saved = _local.readJson(_storageKey);
    if (saved is List<dynamic>) {
      _posts.addAll(
        saved.map(
          (dynamic json) => Post.fromJson(json as Map<String, dynamic>),
        ),
      );
    } else {
      _posts.addAll(buildSeedPosts(_now()));
    }

    final Object? schedule = _local.readJson(_scheduleKey);
    if (schedule is Map<String, dynamic>) {
      schedule.forEach((String id, dynamic time) {
        _nextPostAt[id] = DateTime.parse(time as String);
      });
    }
    // 일정이 없는 페르소나는 마지막 게시물(없으면 지금)을 기준으로 다음 게시 시각을 정한다.
    for (final MapEntry<String, PostingHabit> habit in personaHabits.entries) {
      _nextPostAt.putIfAbsent(
        habit.key,
        () => habit.value.nextAfter(
          postsBy(habit.key).firstOrNull?.createdAt ?? _now(),
          _random,
        ),
      );
    }
    _saveSchedule();
  }

  /// 페르소나가 새 게시물을 쓰는 중인지 (피드 새로고침 표시용).
  bool get isCreatingPost => _creatingPost;

  List<Post> get posts => List<Post>.unmodifiable(_posts);

  List<Post> postsBy(String authorId) =>
      _posts.where((Post p) => p.authorId == authorId).toList();

  List<Post> get bookmarkedPosts =>
      _posts.where((Post p) => p.bookmarked).toList();

  Post? byId(String id) {
    for (final Post post in _posts) {
      if (post.id == id) return post;
    }
    return null;
  }

  /// 캡션·해시태그·작성자 이름/계정으로 검색. 빈 검색어면 전체.
  List<Post> search(String query) {
    final String q = query.trim().toLowerCase().replaceFirst('#', '');
    if (q.isEmpty) return posts;
    return _posts.where((Post post) {
      final Persona? author = _personas.byId(post.authorId);
      return post.caption.toLowerCase().contains(q) ||
          (author != null &&
              (author.name.toLowerCase().contains(q) ||
                  author.handle.toLowerCase().contains(q)));
    }).toList();
  }

  bool isReplyPending(String commentId) => _pendingReplies.contains(commentId);

  String? replyErrorOf(String commentId) => _failedReplies[commentId];

  void toggleLike(String postId) {
    final Post? post = byId(postId);
    if (post == null) return;
    post.likedByMe = !post.likedByMe;
    post.likes += post.likedByMe ? 1 : -1;
    _changed();
  }

  void toggleBookmark(String postId) {
    final Post? post = byId(postId);
    if (post == null) return;
    post.bookmarked = !post.bookmarked;
    _changed();
  }

  Comment? _commentById(Post post, String? id) {
    if (id == null) return null;
    for (final Comment c in post.comments) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 내 댓글을 단다. [replyToId]를 주면 그 댓글의 스레드에 답글로 붙는다.
  /// 페르소나가 답할 차례면 Gemini로 답글을 받아온다.
  /// 댓글은 첫 await 전에 추가되므로 호출 직후 화면에 바로 보인다.
  Future<void> addComment(
    String postId,
    String text, {
    String? replyToId,
  }) async {
    final Post? post = byId(postId);
    final String trimmed = text.trim();
    if (post == null || trimmed.isEmpty) return;

    final Comment? target = _commentById(post, replyToId);
    final Comment comment = Comment(
      id: newId('comment'),
      postId: postId,
      authorId: myUserId,
      text: trimmed,
      createdAt: DateTime.now(),
      // 스레드는 한 단계로만 들여쓴다: 답글의 답글도 원 댓글 아래에 붙는다.
      parentId: target == null ? null : (target.parentId ?? target.id),
      replyToId: target?.id,
    );
    post.comments.add(comment);
    _changed();

    await _replyTo(post, comment);
  }

  Future<void> retryReply(String commentId) async {
    for (final Post post in _posts) {
      final Comment? comment = _commentById(post, commentId);
      if (comment != null) return _replyTo(post, comment);
    }
  }

  /// 내 댓글에 답할 페르소나. 페르소나 댓글에 답글을 달았으면 그 페르소나,
  /// 아니면 게시물 주인 페르소나. 내 게시물에 내가 단 일반 댓글이면 null.
  Persona? _responderFor(Post post, Comment comment) {
    final Comment? target = _commentById(post, comment.replyToId);
    if (target != null && target.authorId != myUserId) {
      return _personas.byId(target.authorId);
    }
    return _personas.byId(post.authorId);
  }

  List<CommentLine> _threadUntil(Post post, Comment comment) {
    final String rootId = comment.parentId ?? comment.id;
    String name(String authorId) => authorId == myUserId
        ? '사용자'
        : (_personas.byId(authorId)?.name ?? '알 수 없음');
    return <CommentLine>[
      for (final Comment c in post.comments)
        if ((c.id == rootId || c.parentId == rootId) &&
            !c.createdAt.isAfter(comment.createdAt))
          (author: name(c.authorId), text: c.text),
    ];
  }

  Future<void> _replyTo(Post post, Comment comment) async {
    final Persona? responder = _responderFor(post, comment);
    if (responder == null || _pendingReplies.contains(comment.id)) return;

    _pendingReplies.add(comment.id);
    _failedReplies.remove(comment.id);
    notifyListeners();

    try {
      // 내 게시물은 AI가 사진을 직접 보고 말하게 한다
      // (페르소나 게시물은 사진 내용이 이미 캡션에 들어 있다).
      final String text = await _gemini.generateCommentReply(
        persona: responder,
        post: post,
        thread: _threadUntil(post, comment),
        isOwnPost: post.authorId == responder.id,
        image: post.authorId == myUserId
            ? await imageLoader(post.imagePath)
            : null,
      );
      post.comments.add(
        Comment(
          id: newId('comment'),
          postId: post.id,
          authorId: responder.id,
          text: text,
          createdAt: DateTime.now(),
          parentId: comment.parentId ?? comment.id,
          replyToId: comment.id,
        ),
      );
      _notifications.add(
        type: NotificationType.commentReply,
        personaId: responder.id,
        postId: post.id,
        text: text,
      );
    } on GeminiException catch (e) {
      _failedReplies[comment.id] = e.userMessage;
    } finally {
      _pendingReplies.remove(comment.id);
      _changed();
    }
  }

  /// 페르소나별 다음 게시 예정 시각 (설정 화면 표시용).
  Map<String, DateTime> get nextPostTimes =>
      Map<String, DateTime>.unmodifiable(_nextPostAt);

  /// 게시 예정 시각이 지난 페르소나가 새 게시물을 올린다.
  /// 앱을 열거나 다시 돌아왔을 때, 피드를 새로고침할 때 부른다.
  /// 한 번에 [maxPostsPerCheck]개까지만 올리고, 밀린 나머지는 몇 시간 뒤로 미룬다.
  /// 올린 게시물 수를 돌려준다. 실패는 조용히 넘기고 나중에 다시 시도한다.
  Future<int> runScheduledPosts() async {
    if (!_gemini.isConfigured || _checkingSchedule) return 0;
    _checkingSchedule = true;
    int posted = 0;
    try {
      final DateTime now = _now();
      final List<MapEntry<String, DateTime>> due =
          _nextPostAt.entries
              .where((MapEntry<String, DateTime> e) => !e.value.isAfter(now))
              .toList()
            ..sort(
              (MapEntry<String, DateTime> a, MapEntry<String, DateTime> b) =>
                  a.value.compareTo(b.value),
            );

      for (final MapEntry<String, DateTime> entry in due) {
        final PostingHabit habit = personaHabits[entry.key]!;
        if (posted >= maxPostsPerCheck) {
          // 한꺼번에 몰리지 않게 남은 페르소나는 몇 시간 뒤로 미룬다.
          _nextPostAt[entry.key] = habit.fitActiveHours(
            now.add(Duration(minutes: 60 + _random.nextInt(5 * 60))),
            _random,
          );
          continue;
        }
        // 앱을 안 연 사이에 올린 것처럼 예정 시각으로 기록한다 (너무 오래됐으면 최근으로).
        final DateTime postedAt = now.difference(entry.value).inHours < 24
            ? entry.value
            : now.subtract(Duration(minutes: _random.nextInt(120)));
        try {
          final Post? post = await createPersonaPost(
            personaId: entry.key,
            at: postedAt,
          );
          // 다른 게시물을 만드는 중이라 못 올렸으면 다음 확인 때 다시 시도한다.
          if (post == null) continue;
          posted++;
          final DateTime next = habit.nextAfter(postedAt, _random);
          _nextPostAt[entry.key] = next.isAfter(now)
              ? next
              : habit.nextAfter(now, _random);
        } on GeminiException {
          // 할당량 초과나 네트워크 문제일 수 있으니 한 시간 뒤 다시 시도하고 이번엔 멈춘다.
          _nextPostAt[entry.key] = now.add(const Duration(hours: 1));
          break;
        }
      }
    } finally {
      _checkingSchedule = false;
      _saveSchedule();
    }
    return posted;
  }

  /// [personaId]가 새 게시물을 올린다. 사진 생성이 켜져 있으면 Gemini로 새 사진을
  /// 만들고, 아니면(또는 실패하면) 그 페르소나의 기존 사진 중에서 고른다.
  /// [personaId]를 안 주면 가장 최근 작성자를 피해서 고른다.
  /// 캡션 생성에 실패하면 [GeminiException]을 그대로 던진다.
  Future<Post?> createPersonaPost({String? personaId, DateTime? at}) async {
    if (_creatingPost) return null;
    final String? lastAuthor = _posts
        .where((Post p) => p.authorId != myUserId)
        .firstOrNull
        ?.authorId;
    final List<String> candidates = personaPhotos.keys
        .where(
          (String id) => personaId == null ? id != lastAuthor : id == personaId,
        )
        .toList();
    if (candidates.isEmpty) return null;
    final Persona? persona = _personas.byId(
      candidates[_random.nextInt(candidates.length)],
    );
    if (persona == null) return null;

    _creatingPost = true;
    notifyListeners();
    try {
      // 컨셉 얘기만 올리지 않도록, 절반쯤은 그 사람의 다른 일상 화제를 섞는다.
      final String? topic = persona.lifeTopics.isNotEmpty && _random.nextBool()
          ? persona.lifeTopics[_random.nextInt(persona.lifeTopics.length)]
          : null;
      final PersonaPhoto photo =
          await _generatedPhoto(persona, topic) ?? _pickExistingPhoto(persona);
      final String caption = await _gemini.generatePostCaption(
        persona: persona,
        photoDescription: photo.description,
        topic: topic,
      );
      final DateTime createdAt = at ?? _now();
      final Post post = Post(
        id: newId('post'),
        authorId: persona.id,
        imagePath: photo.path,
        caption: caption,
        createdAt: createdAt,
        likes: 50 + _random.nextInt(450),
        friendReactions: _planFriendReactions(persona.id, createdAt),
      );
      _insertByTime(post);
      _notifications.add(
        type: NotificationType.newPost,
        personaId: persona.id,
        postId: post.id,
        text: caption.split('\n').first,
      );
      return post;
    } finally {
      _creatingPost = false;
      _changed();
    }
  }

  /// 다른 AI 친구들이 이 게시물을 언제 보고, 좋아요·댓글을 남길지 정한다.
  /// 각자 활동 시간 안에서 30분~6시간 뒤에 본다.
  List<FriendReaction> _planFriendReactions(String authorId, DateTime from) {
    final List<FriendReaction> plan = <FriendReaction>[];
    int comments = 0;
    for (final Persona friend in seedPersonas) {
      if (friend.id == authorId) continue;
      final bool liked = _random.nextDouble() < friendLikeChance;
      final bool comment =
          comments < maxFriendComments &&
          _random.nextDouble() < friendCommentChance;
      if (!liked && !comment) continue;
      if (comment) comments++;
      DateTime at = from.add(Duration(minutes: 30 + _random.nextInt(330)));
      final PostingHabit? habit = personaHabits[friend.id];
      if (habit != null) at = habit.fitActiveHours(at, _random);
      plan.add(
        FriendReaction(
          personaId: friend.id,
          at: at,
          liked: liked,
          comment: comment,
        ),
      );
    }
    return plan;
  }

  /// 시각이 지난 AI 친구 댓글(과 게시물 주인의 답글)을 단다. 단 댓글 수를 돌려준다.
  /// 좋아요는 시각이 지나면 화면에 바로 보이므로 여기서 할 일이 없다.
  /// 요청이 실패하거나 오늘 예산을 다 썼으면 다음 확인 때 다시 시도한다.
  Future<int> runFriendReactions({required AiBudget budget}) async {
    if (!_gemini.isConfigured) return 0;
    final DateTime now = _now();
    int added = 0;
    for (final Post post in List<Post>.of(_posts)) {
      if (now.difference(post.createdAt) > const Duration(days: 2)) continue;
      for (final FriendReaction r in List<FriendReaction>.of(
        post.friendReactions,
      )) {
        if (r.done || !r.comment || r.at.isAfter(now)) continue;
        if (added >= maxFriendCommentsPerCheck || !budget.trySpend()) {
          return added;
        }
        final Persona? persona = _personas.byId(r.personaId);
        final Persona? author = _personas.byId(post.authorId);
        if (persona == null || author == null) {
          r.done = true;
          continue;
        }
        try {
          final Comment comment = await _friendComment(
            post,
            r,
            persona,
            author,
          );
          post.comments.add(comment);
          r.done = true;
          added++;
          // 친구 댓글에는 가끔 게시물 주인이 답글을 단다.
          if (r.replyToCommentId == null &&
              _random.nextDouble() < ownerReplyChance) {
            final PostingHabit? habit = personaHabits[author.id];
            DateTime at = now.add(Duration(minutes: 10 + _random.nextInt(110)));
            if (habit != null) at = habit.fitActiveHours(at, _random);
            post.friendReactions.add(
              FriendReaction(
                personaId: author.id,
                at: at,
                comment: true,
                replyToCommentId: comment.id,
              ),
            );
          }
          _changed();
        } on GeminiException {
          return added;
        }
      }
    }
    return added;
  }

  Future<Comment> _friendComment(
    Post post,
    FriendReaction r,
    Persona persona,
    Persona author,
  ) async {
    final Comment? target = _commentById(post, r.replyToCommentId);
    if (target == null) {
      return Comment(
        id: newId('comment'),
        postId: post.id,
        authorId: persona.id,
        text: await _gemini.generateFriendComment(
          persona: persona,
          post: post,
          authorName: author.name,
        ),
        createdAt: _now(),
      );
    }
    final String rootId = target.parentId ?? target.id;
    return Comment(
      id: newId('comment'),
      postId: post.id,
      authorId: persona.id,
      text: await _gemini.generateCommentReply(
        persona: persona,
        post: post,
        thread: _threadUntil(post, target),
        isOwnPost: post.authorId == persona.id,
        background: true,
      ),
      createdAt: _now(),
      parentId: rootId,
      replyToId: target.id,
    );
  }

  /// 사진 생성이 켜져 있으면 오늘의 장면을 정해 사진을 만든다. 안 되면 null.
  Future<PersonaPhoto?> _generatedPhoto(Persona persona, String? topic) async {
    final PostImageSource? source = _imageSource;
    final DateTime? disabledUntil = _imageDisabledUntil;
    if (source == null || !source.isEnabled) return null;
    if (disabledUntil != null && _now().isBefore(disabledUntil)) return null;
    try {
      final String scene = await _gemini.generatePostScene(
        persona: persona,
        recentCaptions: postsBy(
          persona.id,
        ).take(3).map((Post p) => p.caption).toList(),
        topic: topic,
      );
      final String path = await source.create(persona: persona, scene: scene);
      return (path: path, description: scene);
    } catch (_) {
      // 이미지 모델이 없거나 유료라 막혔거나, 저장에 실패한 경우: 한동안은 기존 사진을 쓴다.
      _imageDisabledUntil = _now().add(imageRetryDelay);
      return null;
    }
  }

  /// 기존 사진 중에서, 이 페르소나가 가장 최근에 쓴 사진은 피해서 고른다.
  PersonaPhoto _pickExistingPhoto(Persona persona) {
    final List<PersonaPhoto> pool = personaPhotos[persona.id]!;
    final String? lastPhoto = postsBy(persona.id).firstOrNull?.imagePath;
    final List<PersonaPhoto> choices = pool
        .where((PersonaPhoto p) => p.path != lastPhoto)
        .toList();
    final List<PersonaPhoto> from = choices.isEmpty ? pool : choices;
    return from[_random.nextInt(from.length)];
  }

  /// 피드는 최신순이므로 예정 시각으로 기록된 게시물도 시간 순서에 맞게 넣는다.
  void _insertByTime(Post post) {
    final int index = _posts.indexWhere(
      (Post p) => p.createdAt.isBefore(post.createdAt),
    );
    _posts.insert(index == -1 ? _posts.length : index, post);
  }

  void _saveSchedule() => _local.writeJson(
    _scheduleKey,
    _nextPostAt.map(
      (String id, DateTime time) =>
          MapEntry<String, String>(id, time.toIso8601String()),
    ),
  );

  /// 내 게시물을 올리고, 페르소나 몇 명이 반응 댓글을 단다.
  /// 게시물은 첫 await 전에 피드에 추가된다.
  Future<void> addPost({
    required String imagePath,
    required String caption,
  }) async {
    final Post post = Post(
      id: newId('post'),
      authorId: myUserId,
      imagePath: imagePath,
      caption: caption.trim(),
      createdAt: DateTime.now(),
    );
    _posts.insert(0, post);
    _changed();

    final List<Persona> reactors = List<Persona>.of(seedPersonas)
      ..shuffle(_random);
    final ChatImage? photo = await imageLoader(post.imagePath);
    for (final Persona persona in reactors.take(_reactionCount)) {
      try {
        final String text = await _gemini.generatePostReaction(
          persona: persona,
          caption: post.caption,
          image: photo,
        );
        post.comments.add(
          Comment(
            id: newId('comment'),
            postId: post.id,
            authorId: persona.id,
            text: text,
            createdAt: DateTime.now(),
          ),
        );
        post.likes += 1;
        _notifications.add(
          type: NotificationType.postReaction,
          personaId: persona.id,
          postId: post.id,
          text: text,
        );
        _changed();
      } on GeminiException {
        // 반응 댓글은 부가 기능이라 실패해도 조용히 넘어간다.
        // 키가 없는 경우는 피드 상단 배너로 안내한다.
      }
    }
  }

  void _changed() {
    _local.writeJson(_storageKey, _posts.map((Post p) => p.toJson()).toList());
    notifyListeners();
  }
}

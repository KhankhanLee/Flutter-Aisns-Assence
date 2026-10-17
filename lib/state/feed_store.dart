import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:assence/data/seed_data.dart';
import 'package:assence/models/app_notification.dart';
import 'package:assence/models/comment.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/post.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/state/notification_store.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/utils/format.dart';

class FeedStore extends ChangeNotifier {
  static const String _storageKey = 'posts';
  static const int _reactionCount = 2;

  /// 마지막 페르소나 게시물이 이보다 오래되면 앱을 열 때 새 게시물을 올린다.
  static const Duration autoPostInterval = Duration(hours: 3);

  final LocalStore _local;
  final GeminiService _gemini;
  final PersonaStore _personas;
  final NotificationStore _notifications;
  final Random _random;

  final List<Post> _posts = <Post>[]; // 최신순
  final Set<String> _pendingReplies = <String>{}; // 답글을 기다리는 댓글 ID
  final Map<String, String> _failedReplies =
      <String, String>{}; // 댓글 ID → 안내 문구
  bool _creatingPost = false;

  FeedStore(
    this._local,
    this._gemini,
    this._personas,
    this._notifications, {
    Random? random,
  }) : _random = random ?? Random() {
    final Object? saved = _local.readJson(_storageKey);
    if (saved is List<dynamic>) {
      _posts.addAll(
        saved.map(
          (dynamic json) => Post.fromJson(json as Map<String, dynamic>),
        ),
      );
    } else {
      _posts.addAll(buildSeedPosts(DateTime.now()));
    }
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
      final String text = await _gemini.generateCommentReply(
        persona: responder,
        post: post,
        thread: _threadUntil(post, comment),
        isOwnPost: post.authorId == responder.id,
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

  /// 페르소나가 사진 한 장을 골라 Gemini로 캡션을 쓰고 새 게시물을 올린다.
  /// [personaId]를 안 주면 가장 최근 작성자를 피해서 고른다.
  /// 실패하면 [GeminiException]을 그대로 던진다.
  Future<Post?> createPersonaPost({String? personaId}) async {
    if (_creatingPost) return null;
    final String? lastAuthor = _latestPersonaPost()?.authorId;
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

    // 같은 사진이 연달아 올라오지 않게, 이 페르소나가 가장 최근에 쓴 사진은 피한다.
    final List<PersonaPhoto> pool = personaPhotos[persona.id]!;
    final String? lastPhoto = postsBy(persona.id).firstOrNull?.imagePath;
    final List<PersonaPhoto> choices = pool
        .where((PersonaPhoto p) => p.path != lastPhoto)
        .toList();
    final PersonaPhoto photo =
        (choices.isEmpty ? pool : choices)[_random.nextInt(
          choices.isEmpty ? pool.length : choices.length,
        )];

    _creatingPost = true;
    notifyListeners();
    try {
      final String caption = await _gemini.generatePostCaption(
        persona: persona,
        photoDescription: photo.description,
      );
      final Post post = Post(
        id: newId('post'),
        authorId: persona.id,
        imagePath: photo.path,
        caption: caption,
        createdAt: DateTime.now(),
        likes: 50 + _random.nextInt(450),
      );
      _posts.insert(0, post);
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

  /// 키가 있고 마지막 페르소나 게시물이 [autoPostInterval]보다 오래됐으면
  /// 새 게시물을 하나 올린다. 실패해도 조용히 넘어간다 (앱 시작 시 호출).
  Future<void> maybeAutoPost({DateTime? now}) async {
    if (!_gemini.isConfigured) return;
    final Post? latest = _latestPersonaPost();
    final DateTime current = now ?? DateTime.now();
    if (latest != null &&
        current.difference(latest.createdAt) < autoPostInterval) {
      return;
    }
    try {
      await createPersonaPost();
    } on GeminiException {
      // 자동 게시는 부가 기능이라 실패해도 알리지 않는다.
    }
  }

  Post? _latestPersonaPost() {
    for (final Post post in _posts) {
      if (post.authorId != myUserId) return post;
    }
    return null;
  }

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
    for (final Persona persona in reactors.take(_reactionCount)) {
      try {
        final String text = await _gemini.generatePostReaction(
          persona: persona,
          caption: post.caption,
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

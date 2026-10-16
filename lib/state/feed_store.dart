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

  final LocalStore _local;
  final GeminiService _gemini;
  final PersonaStore _personas;
  final NotificationStore _notifications;
  final Random _random;

  final List<Post> _posts = <Post>[]; // 최신순
  final Set<String> _pendingReplies = <String>{}; // 답글을 기다리는 댓글 ID
  final Map<String, String> _failedReplies =
      <String, String>{}; // 댓글 ID → 안내 문구

  FeedStore(
    this._local,
    this._gemini,
    this._personas,
    this._notifications, {
    Random? random,
  }) : _random = random ?? Random() {
    final Object? saved = _local.readJson(_storageKey);
    if (saved is List<dynamic>) {
      _posts.addAll(saved
          .map((dynamic json) => Post.fromJson(json as Map<String, dynamic>)));
    } else {
      _posts.addAll(buildSeedPosts(DateTime.now()));
    }
  }

  bool get isConfigured => _gemini.isConfigured;

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

  /// 내 댓글을 달고, 게시물 주인이 페르소나면 AI 답글을 받아온다.
  /// 댓글은 첫 await 전에 추가되므로 호출 직후 화면에 바로 보인다.
  Future<void> addComment(String postId, String text) async {
    final Post? post = byId(postId);
    final String trimmed = text.trim();
    if (post == null || trimmed.isEmpty) return;

    final Comment comment = Comment(
      id: newId('comment'),
      postId: postId,
      authorId: myUserId,
      text: trimmed,
      createdAt: DateTime.now(),
    );
    post.comments.add(comment);
    _changed();

    if (_personas.byId(post.authorId) != null) {
      await _replyTo(post, comment);
    }
  }

  Future<void> retryReply(String commentId) async {
    for (final Post post in _posts) {
      for (final Comment comment in post.comments) {
        if (comment.id == commentId) return _replyTo(post, comment);
      }
    }
  }

  /// 내 게시물을 올리고, 페르소나 몇 명이 반응 댓글을 단다.
  /// 게시물은 첫 await 전에 피드에 추가된다.
  Future<void> addPost(
      {required String imagePath, required String caption}) async {
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
            persona: persona, caption: post.caption);
        post.comments.add(Comment(
          id: newId('comment'),
          postId: post.id,
          authorId: persona.id,
          text: text,
          createdAt: DateTime.now(),
        ));
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

  Future<void> _replyTo(Post post, Comment comment) async {
    final Persona? author = _personas.byId(post.authorId);
    if (author == null || _pendingReplies.contains(comment.id)) return;

    _pendingReplies.add(comment.id);
    _failedReplies.remove(comment.id);
    notifyListeners();

    try {
      final String text = await _gemini.generateCommentReply(
        persona: author,
        post: post,
        commentText: comment.text,
      );
      post.comments.add(Comment(
        id: newId('comment'),
        postId: post.id,
        authorId: author.id,
        text: text,
        createdAt: DateTime.now(),
        parentId: comment.id,
      ));
      _notifications.add(
        type: NotificationType.commentReply,
        personaId: author.id,
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

  void _changed() {
    _local.writeJson(_storageKey, _posts.map((Post p) => p.toJson()).toList());
    notifyListeners();
  }
}

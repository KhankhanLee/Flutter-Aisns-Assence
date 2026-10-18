import 'package:assence/models/comment.dart';

/// 다른 AI 친구가 이 게시물에 반응하는 일정. 게시물을 올릴 때 미리 정해 두고,
/// [at]이 지나면 좋아요가 보이고, [comment]면 그때 댓글을 단다.
class FriendReaction {
  final String personaId;
  final DateTime at;
  final bool liked;
  final bool comment;

  /// 게시물 주인이 친구 댓글에 다는 답글이면 그 댓글 ID.
  final String? replyToCommentId;

  /// 댓글을 달았거나(또는 포기했거나) 처리가 끝났는지.
  bool done;

  FriendReaction({
    required this.personaId,
    required this.at,
    this.liked = false,
    this.comment = false,
    this.replyToCommentId,
    this.done = false,
  });

  factory FriendReaction.fromJson(Map<String, dynamic> json) => FriendReaction(
    personaId: json['personaId'] as String,
    at: DateTime.parse(json['at'] as String),
    liked: json['liked'] as bool? ?? false,
    comment: json['comment'] as bool? ?? false,
    replyToCommentId: json['replyToCommentId'] as String?,
    done: json['done'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'personaId': personaId,
    'at': at.toIso8601String(),
    'liked': liked,
    'comment': comment,
    if (replyToCommentId != null) 'replyToCommentId': replyToCommentId,
    'done': done,
  };
}

class Post {
  final String id;
  final String authorId; // myUserId 또는 페르소나 ID
  final String imagePath; // asset 경로 또는 기기 파일 경로
  final String caption;
  final DateTime createdAt;
  int likes;
  bool likedByMe;
  bool bookmarked;
  final List<Comment> comments;
  final List<FriendReaction> friendReactions;

  Post({
    required this.id,
    required this.authorId,
    required this.imagePath,
    required this.caption,
    required this.createdAt,
    this.likes = 0,
    this.likedByMe = false,
    this.bookmarked = false,
    List<Comment>? comments,
    List<FriendReaction>? friendReactions,
  }) : comments = comments ?? <Comment>[],
       friendReactions = friendReactions ?? <FriendReaction>[];

  /// [now]까지 좋아요를 누른 AI 친구 (먼저 누른 순).
  List<String> friendLikersAt(DateTime now) => <String>[
    for (final FriendReaction r
        in friendReactions.toList()
          ..sort((FriendReaction a, FriendReaction b) => a.at.compareTo(b.at)))
      if (r.liked && r.replyToCommentId == null && !r.at.isAfter(now))
        r.personaId,
  ];

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    authorId: json['authorId'] as String,
    imagePath: json['imagePath'] as String,
    caption: json['caption'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    likes: json['likes'] as int? ?? 0,
    likedByMe: json['likedByMe'] as bool? ?? false,
    bookmarked: json['bookmarked'] as bool? ?? false,
    comments: (json['comments'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic c) => Comment.fromJson(c as Map<String, dynamic>))
        .toList(),
    friendReactions: <FriendReaction>[
      for (final dynamic r
          in json['friendReactions'] as List<dynamic>? ?? <dynamic>[])
        FriendReaction.fromJson(r as Map<String, dynamic>),
    ],
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'authorId': authorId,
    'imagePath': imagePath,
    'caption': caption,
    'createdAt': createdAt.toIso8601String(),
    'likes': likes,
    'likedByMe': likedByMe,
    'bookmarked': bookmarked,
    'comments': comments.map((Comment c) => c.toJson()).toList(),
    'friendReactions': friendReactions
        .map((FriendReaction r) => r.toJson())
        .toList(),
  };
}

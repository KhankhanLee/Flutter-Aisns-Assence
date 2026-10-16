import 'package:assence/models/comment.dart';

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
  }) : comments = comments ?? <Comment>[];

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
      };
}

class Comment {
  final String id;
  final String postId;
  final String authorId; // myUserId 또는 페르소나 ID
  final String text;
  final DateTime createdAt;
  final String? parentId; // 답글이면 스레드의 원 댓글 ID
  final String? replyToId; // 답글을 단 바로 그 댓글 ID (AI가 누구에게 답할지 정할 때 씀)

  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.text,
    required this.createdAt,
    this.parentId,
    this.replyToId,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] as String,
    postId: json['postId'] as String,
    authorId: json['authorId'] as String,
    text: json['text'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    parentId: json['parentId'] as String?,
    replyToId: json['replyToId'] as String?,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'postId': postId,
    'authorId': authorId,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'parentId': parentId,
    'replyToId': replyToId,
  };
}

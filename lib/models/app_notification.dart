enum NotificationType { commentReply, postReaction, newPost }

class AppNotification {
  final String id;
  final NotificationType type;
  final String personaId;
  final String postId;
  final String text;
  final DateTime createdAt;
  bool read;

  AppNotification({
    required this.id,
    required this.type,
    required this.personaId,
    required this.postId,
    required this.text,
    required this.createdAt,
    this.read = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: NotificationType.values.byName(json['type'] as String),
        personaId: json['personaId'] as String,
        postId: json['postId'] as String,
        text: json['text'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        read: json['read'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type.name,
    'personaId': personaId,
    'postId': postId,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
  };
}

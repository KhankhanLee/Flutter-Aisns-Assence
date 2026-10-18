/// DM에서 함께 보여주는 스토리 (스토리에 답장하거나, 내 스토리를 보고 보낸 메시지).
/// 스토리는 24시간 뒤 사라지므로 필요한 내용만 따로 저장해 둔다.
class SharedStory {
  final String authorId; // myUserId 또는 페르소나 ID
  final String imagePath; // 빈 문자열이면 글만 있는 스토리
  final String text;
  final DateTime createdAt;

  const SharedStory({
    required this.authorId,
    required this.imagePath,
    required this.text,
    required this.createdAt,
  });

  factory SharedStory.fromJson(Map<String, dynamic> json) => SharedStory(
    authorId: json['authorId'] as String,
    imagePath: json['imagePath'] as String,
    text: json['text'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'authorId': authorId,
    'imagePath': imagePath,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };
}

class ChatMessage {
  static const String userRole = 'user';
  static const String modelRole = 'model';

  final String role; // Gemini API 역할: 'user' 또는 'model'
  final String text;
  final DateTime createdAt;

  /// 이 메시지가 답하는 스토리. 없으면 일반 메시지.
  final SharedStory? story;

  /// 함께 보낸 사진(기기 파일 경로). 사진만 보냈으면 [text]는 빈 문자열.
  final String? imagePath;

  ChatMessage({
    required this.role,
    required this.text,
    DateTime? createdAt,
    this.story,
    this.imagePath,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isUser => role == userRole;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: json['role'] as String,
    text: json['text'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    story: json['story'] is Map<String, dynamic>
        ? SharedStory.fromJson(json['story'] as Map<String, dynamic>)
        : null,
    imagePath: json['imagePath'] as String?,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    if (story != null) 'story': story!.toJson(),
    if (imagePath != null) 'imagePath': imagePath,
  };
}

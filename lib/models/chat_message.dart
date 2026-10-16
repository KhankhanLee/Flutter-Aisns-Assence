class ChatMessage {
  static const String userRole = 'user';
  static const String modelRole = 'model';

  final String role; // Gemini API 역할: 'user' 또는 'model'
  final String text;
  final DateTime createdAt;

  ChatMessage({required this.role, required this.text, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();

  bool get isUser => role == userRole;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: json['role'] as String,
    text: json['text'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };
}

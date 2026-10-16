import 'package:flutter/widgets.dart';

class Story {
  static const Duration lifetime = Duration(hours: 24);

  final String id;
  final String authorId; // myUserId 또는 페르소나 ID
  final String imagePath; // asset 경로 또는 기기 파일 경로. 빈 문자열이면 텍스트 스토리
  final String text;
  final DateTime createdAt;

  const Story({
    required this.id,
    required this.authorId,
    required this.imagePath,
    required this.text,
    required this.createdAt,
  });

  bool isActive(DateTime now) => now.difference(createdAt) < lifetime;

  factory Story.fromJson(Map<String, dynamic> json) => Story(
        id: json['id'] as String,
        authorId: json['authorId'] as String,
        imagePath: json['imagePath'] as String,
        text: json['text'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'authorId': authorId,
        'imagePath': imagePath,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// 스토리 바에 표시되는 페르소나 묶음 (예: 공감 친구, 성장 코치).
class StoryCategory {
  final String id;
  final String title;
  final IconData icon;
  final List<String> personaIds;

  const StoryCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.personaIds,
  });
}

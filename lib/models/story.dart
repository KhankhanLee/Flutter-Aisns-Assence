import 'package:flutter/widgets.dart';
import 'package:assence/models/chat_message.dart';

/// 내 스토리를 페르소나가 보는 일정. 스토리를 올릴 때 미리 정해 두고,
/// [at]이 지나면 "본 사람" 목록에 나타난다.
class StoryView {
  final String personaId;
  final DateTime at;
  final bool liked;

  /// 이 시각이 지나면 스토리를 보고 DM을 보낸다. null이면 DM을 보내지 않는다.
  DateTime? replyAt;
  bool replied;

  StoryView({
    required this.personaId,
    required this.at,
    this.liked = false,
    this.replyAt,
    this.replied = false,
  });

  factory StoryView.fromJson(Map<String, dynamic> json) => StoryView(
    personaId: json['personaId'] as String,
    at: DateTime.parse(json['at'] as String),
    liked: json['liked'] as bool? ?? false,
    replyAt: json['replyAt'] == null
        ? null
        : DateTime.parse(json['replyAt'] as String),
    replied: json['replied'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'personaId': personaId,
    'at': at.toIso8601String(),
    'liked': liked,
    if (replyAt != null) 'replyAt': replyAt!.toIso8601String(),
    'replied': replied,
  };
}

class Story {
  static const Duration lifetime = Duration(hours: 24);

  final String id;
  final String authorId; // myUserId 또는 페르소나 ID
  final String imagePath; // asset 경로 또는 기기 파일 경로. 빈 문자열이면 텍스트 스토리
  final String text;
  final DateTime createdAt;

  /// 내 스토리를 볼 페르소나 (아직 안 본 사람도 포함). 페르소나 스토리는 비어 있다.
  final List<StoryView> views;

  const Story({
    required this.id,
    required this.authorId,
    required this.imagePath,
    required this.text,
    required this.createdAt,
    this.views = const <StoryView>[],
  });

  bool isActive(DateTime now) => now.difference(createdAt) < lifetime;

  /// DM에 함께 저장할 스토리 정보.
  SharedStory toShared() => SharedStory(
    authorId: authorId,
    imagePath: imagePath,
    text: text,
    createdAt: createdAt,
  );

  factory Story.fromJson(Map<String, dynamic> json) => Story(
    id: json['id'] as String,
    authorId: json['authorId'] as String,
    imagePath: json['imagePath'] as String,
    text: json['text'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    views: <StoryView>[
      for (final dynamic v in json['views'] as List<dynamic>? ?? <dynamic>[])
        StoryView.fromJson(v as Map<String, dynamic>),
    ],
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'authorId': authorId,
    'imagePath': imagePath,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'views': views.map((StoryView v) => v.toJson()).toList(),
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

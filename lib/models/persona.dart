/// 앱 사용자 자신을 가리키는 작성자 ID.
const String myUserId = 'me';

/// AI 페르소나. 게시물·스토리·채팅·댓글이 모두 [id]로 이 객체를 참조한다.
class Persona {
  final String id;
  final String name;
  final String handle; // SNS 계정명 (예: hayeon_daily)
  final String bio; // 프로필 한 줄 소개
  final String prompt; // Gemini system instruction
  final String? avatarPath; // asset 경로. 커스텀 캐릭터는 null
  final bool isCustom;

  /// 한 번 답할 때 쓸 수 있는 이모지 수. 이모지를 거의 안 쓰는 사람은 0.
  final int maxEmoji;

  /// 컨셉 말고도 이 사람이 자주 얘기하는 일상 화제. 게시물·대화가 한 주제로만 흐르지 않게 한다.
  final List<String> lifeTopics;

  const Persona({
    required this.id,
    required this.name,
    required this.handle,
    required this.bio,
    required this.prompt,
    this.avatarPath,
    this.isCustom = false,
    this.maxEmoji = 0,
    this.lifeTopics = const <String>[],
  });

  factory Persona.fromJson(Map<String, dynamic> json) => Persona(
    id: json['id'] as String,
    name: json['name'] as String,
    handle: json['handle'] as String,
    bio: json['bio'] as String,
    prompt: json['prompt'] as String,
    avatarPath: json['avatarPath'] as String?,
    isCustom: json['isCustom'] as bool? ?? false,
    maxEmoji: json['maxEmoji'] as int? ?? 0,
    lifeTopics: (json['lifeTopics'] as List<dynamic>? ?? <dynamic>[])
        .cast<String>(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'handle': handle,
    'bio': bio,
    'prompt': prompt,
    'avatarPath': avatarPath,
    'isCustom': isCustom,
    'maxEmoji': maxEmoji,
    'lifeTopics': lifeTopics,
  };
}

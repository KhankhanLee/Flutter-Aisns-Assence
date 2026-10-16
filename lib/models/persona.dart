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

  const Persona({
    required this.id,
    required this.name,
    required this.handle,
    required this.bio,
    required this.prompt,
    this.avatarPath,
    this.isCustom = false,
  });

  factory Persona.fromJson(Map<String, dynamic> json) => Persona(
    id: json['id'] as String,
    name: json['name'] as String,
    handle: json['handle'] as String,
    bio: json['bio'] as String,
    prompt: json['prompt'] as String,
    avatarPath: json['avatarPath'] as String?,
    isCustom: json['isCustom'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'handle': handle,
    'bio': bio,
    'prompt': prompt,
    'avatarPath': avatarPath,
    'isCustom': isCustom,
  };
}

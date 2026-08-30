class ChatMessage {
  final String role; // 'user' 또는 'model'
  final String text;

  ChatMessage({required this.role, required this.text});
}

class CharacterChatNode {
  final String id;
  final String name;
  final String persona;
  final String bio; // SNS 프로필용 한 줄 소개
  final bool isCustom; // 사용자가 직접 만든 노드인지 여부
  final List<ChatMessage> history;

  CharacterChatNode({
    required this.id,
    required this.name,
    required this.persona,
    required this.bio,
    this.isCustom = false,
    List<ChatMessage>? history,
  }) : history = history ?? <ChatMessage>[];

  void addUserMessage(String text) {
    history.add(ChatMessage(role: 'user', text: text));
  }

  void addModelMessage(String text) {
    history.add(ChatMessage(role: 'model', text: text));
  }
}
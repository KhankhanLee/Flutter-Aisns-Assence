class ChatMessage {
  final String role;
  final String text;

  ChatMessage(this.role, this.text);
}

class CharacterChatNode {
  final String id;
  final String name;
  final String persona;
  final List<ChatMessage> history;

  CharacterChatNode(
    this.id, 
    this.name, 
    this.persona, 
    {List<ChatMessage>? history}
  ) : history = history ?? <ChatMessage>[];

  void addUserMessage(String text) {
    history.add(ChatMessage('user', text));
  }

  void addModelMessage(String text) {
    history.add(ChatMessage('model', text));
  }
}

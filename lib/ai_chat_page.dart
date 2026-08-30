import 'package:assence/chat_models.dart';
import 'package:assence/gemini_service.dart';
import 'package:flutter/material.dart';

class AiChatPage extends StatefulWidget {
  @override
  _AiChatPageState createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final GeminiService _geminiService =
      GeminiService(apiKey: const String.fromEnvironment('GEMINI_API_KEY'));
  final TextEditingController _controller = TextEditingController();

  final Map<String, CharacterChatNode> _characterNodes =
      <String, CharacterChatNode>{
    'friend': CharacterChatNode(
      'friend',
      '공감 친구',
      '사용자의 감정을 따뜻하게 공감하고 짧고 명확한 조언을 제공하는 친구처럼 대화해.',
    ),
    'coach': CharacterChatNode(
      'coach',
      '성장 코치',
      '실행 가능한 단계 중심으로 답변하고 사용자가 바로 행동할 수 있게 도와줘.',
    ),
    'creative': CharacterChatNode(
      'creative',
      '크리에이티브 메이트',
      '창의적인 아이디어를 다양하게 제안하고, 필요하면 간단히 정리해줘.',
    ),
  };

  String _selectedCharacterId = 'friend';
  bool _isLoading = false;

  // 1. Map 조회 결과 뒤에 ! 추가
  CharacterChatNode get _selectedNode => _characterNodes[_selectedCharacterId]!;

  Future<void> _sendMessage() async {
    final String userText = _controller.text.trim();
    if (userText.isEmpty || _isLoading) return;

    setState(() {
      _selectedNode.addUserMessage(userText);
      _controller.clear();
      _isLoading = true;
    });

    try {
      final String reply = await _geminiService.generateReply(
        persona: _selectedNode.persona,
        history: _selectedNode.history,
      );
      setState(() {
        _selectedNode.addModelMessage(reply);
      });
    } catch (e) {
      setState(() {
        _selectedNode.addModelMessage('에러가 발생했어요: $e');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final CharacterChatNode node = _selectedNode;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assence AI Chat'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: <Widget>[
                const Text('캐릭터'),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedCharacterId,
                    items: _characterNodes.values
                        .map(
                          (CharacterChatNode chatNode) => DropdownMenuItem<String>(
                            value: chatNode.id,
                            child: Text(chatNode.name),
                          ),
                        )
                        .toList(),
                    // 2. String? 타입 명시 및 null 처리
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          _selectedCharacterId = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              itemCount: node.history.length,
              itemBuilder: (BuildContext context, int index) {
                final ChatMessage message = node.history[index];
                final bool isUser = message.role == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(message.text),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 10.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

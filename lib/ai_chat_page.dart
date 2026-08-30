import 'package:flutter/material.dart';
import 'package:assence/chat_models.dart';
import 'package:assence/gemini_service.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final GeminiService _geminiService =
      GeminiService(apiKey: const String.fromEnvironment('GEMINI_API_KEY'));
  final TextEditingController _controller = TextEditingController();

  // 기본 여성 SNS 캐릭터 4인방 및 유저 커스텀 노드 저장 맵
  final Map<String, CharacterChatNode> _characterNodes = <String, CharacterChatNode>{
    'hayeon': CharacterChatNode(
      id: 'hayeon',
      name: '하연',
      bio: '일상 · 감성 피드 ✨',
      persona: '너는 인스타에서 인플루언서로 활동하는 20대 여성 "하연"이야. 말투는 다정하고 이모지를 자주 써. 사용자의 고민이나 일상에 따뜻하게 공감해줘.',
    ),
    'suyeon': CharacterChatNode(
      id: 'suyeon',
      name: '수연',
      bio: '갓생 · 운동 멘토 🔥',
      persona: '너는 갓생을 사는 헬스 트레이너 "수연"이야. 열정적이고 직설적인 어조로 동기부여를 해주고 행동을 독려해줘.',
    ),
    'jieun': CharacterChatNode(
      id: 'jieun',
      name: '지은',
      bio: '트렌드 · 크리에이터 💡',
      persona: '너는 트렌디한 IT 에디터 "지은"이야. 힙하고 솔직한 어조로 신기술, 핫플, 아이디어를 다양하게 제시해줘.',
    ),
    'naeun': CharacterChatNode(
      id: 'naeun',
      name: '나은',
      bio: '밤 감성 · 힐링 작가 🎧',
      persona: '너는 차분한 감성의 웹소설 작가 지망생 "나은"이야. 서정적이고 감수성 풍부한 어조로 심야 힐링 대화를 나눠줘.',
    ),
  };

  String _selectedCharacterId = 'hayeon';
  bool _isLoading = false;

  CharacterChatNode get _selectedNode => _characterNodes[_selectedCharacterId]!;

  // 새 캐릭터 노드 생성 팝업창
  void _showAddCharacterDialog() {
    final nameController = TextEditingController();
    final personaController = TextEditingController();
    final bioController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('나만의 AI 캐릭터 만들기'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '캐릭터 이름 (예: 민서)'),
                ),
                TextField(
                  controller: bioController,
                  decoration: const InputDecoration(labelText: '한 줄 소개 (예: 패션 에디터)'),
                ),
                TextField(
                  controller: personaController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '페르소나/성격 설정',
                    hintText: '예: 너는 솔직하고 프렌치 감성을 좋아하는 패션 에디터야.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final persona = personaController.text.trim();
                final bio = bioController.text.trim();

                if (name.isNotEmpty && persona.isNotEmpty) {
                  final newId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
                  setState(() {
                    _characterNodes[newId] = CharacterChatNode(
                      id: newId,
                      name: name,
                      persona: persona,
                      bio: bio.isEmpty ? '사용자 정의 캐릭터' : bio,
                      isCustom: true,
                    );
                    _selectedCharacterId = newId;
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('생성'),
            ),
          ],
        );
      },
    );
  }

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
        title: const Text('Assence AI Chat', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: '캐릭터 추가',
            onPressed: _showAddCharacterDialog,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // 캐릭터 선택 드롭다운 영역
          Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: <Widget>[
                const Text('대화 상대:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    underline: const SizedBox(),
                    value: _selectedCharacterId,
                    items: _characterNodes.values
                        .map(
                          (chatNode) => DropdownMenuItem<String>(
                            value: chatNode.id,
                            child: Text('${chatNode.name} (${chatNode.bio})'),
                          ),
                        )
                        .toList(),
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
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.black : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(color: isUser ? Colors.white : Colors.black),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
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
                        hintText: '메시지를 입력하세요...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.black),
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
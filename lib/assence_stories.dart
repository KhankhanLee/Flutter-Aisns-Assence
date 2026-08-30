import 'package:flutter/material.dart';
import 'package:assence/ai_chat_page.dart';

class AssenceStories extends StatelessWidget {
  const AssenceStories({super.key});

  @override
  Widget build(BuildContext context) {
    // AI 페르소나 데이터 리스트
    final List<Map<String, String>> aiCharacters = [
      {'name': '내 스토리', 'role': 'user'},
      {'name': '공감 친구', 'role': 'friend'},
      {'name': '성장 코치', 'role': 'coach'},
      {'name': '크리에이티브', 'role': 'creative'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                "AI 페르소나",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Row(
                children: <Widget>[
                  Icon(Icons.play_arrow, size: 18),
                  SizedBox(width: 2),
                  Text("모두 보기", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          const SizedBox(height: 10),
          // Height를 고정하여 Layout Overflow 방지
          SizedBox(
            height: 80.0,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: aiCharacters.length,
              itemBuilder: (context, index) {
                final character = aiCharacters[index];
                final bool isUser = index == 0;

                return GestureDetector(
                  onTap: () {
                    if (!isUser) {
                      // AI 캐릭터 클릭 시 해당 AI와 대화하는 채팅방으로 이동
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AiChatPage()),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: <Widget>[
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: isUser ? Colors.grey[300] : Colors.blue[100],
                              child: Icon(
                                isUser ? Icons.person : Icons.smart_toy,
                                color: isUser ? Colors.grey[600] : Colors.blue,
                              ),
                            ),
                            if (isUser)
                              const CircleAvatar(
                                backgroundColor: Colors.blueAccent,
                                radius: 9.0,
                                child: Icon(Icons.add, size: 12.0, color: Colors.white),
                              )
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          character['name']!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

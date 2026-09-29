import 'package:flutter/material.dart';
import 'package:assence/story_pages.dart';
import 'package:assence/story_schema.dart';

class AssenceStories extends StatelessWidget {
  const AssenceStories({super.key});

  @override
  Widget build(BuildContext context) {
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
              itemCount: storyEntries.length,
              itemBuilder: (context, index) {
                final entry = storyEntries[index];
                final bool isUser = entry.type == StoryEntryType.myStory;

                return GestureDetector(
                  onTap: () {
                    if (isUser) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MyStoryCameraPage()),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PersonaStoryFeedPage(entry: entry)),
                    );
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
                                isUser ? Icons.person : entry.icon,
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
                          entry.title,
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

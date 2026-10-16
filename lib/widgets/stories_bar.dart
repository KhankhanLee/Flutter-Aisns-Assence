import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/data/seed_data.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/story.dart';
import 'package:assence/pages/story/story_category_page.dart';
import 'package:assence/pages/story/story_upload_page.dart';
import 'package:assence/pages/story/story_viewer_page.dart';
import 'package:assence/state/story_store.dart';

/// 피드 상단 스토리 영역: 내 스토리 + 페르소나 카테고리.
class StoriesBar extends StatelessWidget {
  const StoriesBar({super.key});

  void _openViewer(BuildContext context, List<Story> stories) {
    if (stories.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => StoryViewerPage(stories: stories),
    ));
  }

  void _openCamera(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const MyStoryCameraPage(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final StoryStore store = context.watch<StoryStore>();
    final List<Story> mine = store.myActiveStories;
    final List<Story> all =
        store.storiesOf(seedPersonas.map((Persona p) => p.id).toList());

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'AI 페르소나',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              InkWell(
                onTap: () => _openViewer(context, all),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.play_arrow, size: 18),
                    SizedBox(width: 2),
                    Text('모두 보기',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 84.0,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                _StoryCircle(
                  title: '내 스토리',
                  icon: Icons.person,
                  hasStory: mine.isNotEmpty,
                  showAdd: true,
                  onTap: () => mine.isEmpty
                      ? _openCamera(context)
                      : _openViewer(context, mine),
                  onAdd: () => _openCamera(context),
                ),
                for (final StoryCategory category in storyCategories)
                  _StoryCircle(
                    title: category.title,
                    icon: category.icon,
                    hasStory: store.storiesOf(category.personaIds).isNotEmpty,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StoryCategoryPage(category: category),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryCircle extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool hasStory;
  final bool showAdd;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const _StoryCircle({
    required this.title,
    required this.icon,
    required this.hasStory,
    required this.onTap,
    this.showAdd = false,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          children: <Widget>[
            Stack(
              alignment: Alignment.bottomRight,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasStory
                        ? const LinearGradient(colors: <Color>[
                            Color(0xfff58529),
                            Color(0xffdd2a7b)
                          ])
                        : null,
                    color: hasStory ? null : Colors.grey[300],
                  ),
                  child: CircleAvatar(
                    radius: 27,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.blue[50],
                      child: Icon(icon, color: Colors.blue),
                    ),
                  ),
                ),
                if (showAdd)
                  GestureDetector(
                    onTap: onAdd,
                    child: const CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      radius: 9.0,
                      child: Icon(Icons.add, size: 12.0, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

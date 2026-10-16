import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/story.dart';
import 'package:assence/pages/story/story_viewer_page.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/state/story_store.dart';
import 'package:assence/widgets/app_image.dart';

/// 카테고리(공감 친구 등)에 속한 페르소나 스토리 목록.
class StoryCategoryPage extends StatelessWidget {
  final StoryCategory category;

  const StoryCategoryPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final List<Story> stories =
        context.watch<StoryStore>().storiesOf(category.personaIds);
    final PersonaStore personas = context.watch<PersonaStore>();

    return Scaffold(
      appBar: AppBar(title: Text(category.title)),
      body: stories.isEmpty
          ? const Center(child: Text('지금은 올라온 스토리가 없어요.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: stories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final Story story = stories[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StoryViewerPage(
                          stories: stories, initialIndex: index),
                    ),
                  ),
                  child: Ink(
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      image: DecorationImage(
                        image: appImageProvider(story.imagePath),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.black.withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        '${personas.byId(story.authorId)?.name ?? ''} · ${story.text}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

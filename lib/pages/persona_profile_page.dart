import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/post.dart';
import 'package:assence/navigation.dart';
import 'package:assence/state/feed_store.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/widgets/author_avatar.dart';
import 'package:assence/widgets/post_grid.dart';

class PersonaProfilePage extends StatelessWidget {
  final String personaId;

  const PersonaProfilePage({super.key, required this.personaId});

  @override
  Widget build(BuildContext context) {
    final Persona? persona = context.watch<PersonaStore>().byId(personaId);
    if (persona == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('찾을 수 없는 계정이에요.')),
      );
    }
    final List<Post> posts = context.watch<FeedStore>().postsBy(persona.id);

    return Scaffold(
      appBar: AppBar(title: Text(persona.handle)),
      body: ListView(
        children: <Widget>[
          ProfileHeader(
            authorId: persona.id,
            name: persona.name,
            bio: persona.bio,
            stats: <String, int>{'게시물': posts.length},
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('메시지 보내기'),
              onPressed: () => openChat(context, personaId: persona.id),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          PostGrid(
            posts: posts,
            embedded: true,
            emptyText: '${persona.name}님은 아직 게시물이 없어요.',
          ),
        ],
      ),
    );
  }
}

/// 프로필 상단: 아바타, 통계, 이름, 소개.
class ProfileHeader extends StatelessWidget {
  final String authorId;
  final String name;
  final String bio;
  final Map<String, int> stats;

  const ProfileHeader({
    super.key,
    required this.authorId,
    required this.name,
    required this.bio,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AuthorAvatar(authorId: authorId, radius: 40),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    for (final MapEntry<String, int> stat in stats.entries)
                      Column(
                        children: <Widget>[
                          Text(
                            '${stat.value}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(stat.key),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (bio.isNotEmpty) Text(bio),
        ],
      ),
    );
  }
}

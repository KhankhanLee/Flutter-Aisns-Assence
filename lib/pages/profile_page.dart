import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/post.dart';
import 'package:assence/navigation.dart';
import 'package:assence/pages/persona_profile_page.dart';
import 'package:assence/state/feed_store.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/widgets/author_avatar.dart';
import 'package:assence/widgets/post_grid.dart';

enum _ProfileTab { posts, saved }

/// 내 프로필: 내 게시물, 저장한 게시물, AI 친구 목록.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  _ProfileTab _tab = _ProfileTab.posts;

  @override
  Widget build(BuildContext context) {
    final FeedStore feed = context.watch<FeedStore>();
    final List<Persona> personas = context.watch<PersonaStore>().all;
    final List<Post> myPosts = feed.postsBy(myUserId);
    final List<Post> saved = feed.bookmarkedPosts;

    return ListView(
      children: <Widget>[
        ProfileHeader(
          authorId: myUserId,
          name: myHandle,
          bio: 'Assence에서 AI 친구들과 소통 중',
          stats: <String, int>{
            '게시물': myPosts.length,
            '저장됨': saved.length,
            'AI 친구': personas.length,
          },
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('AI 친구', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 84,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: personas.length,
            itemBuilder: (BuildContext context, int index) {
              final Persona persona = personas[index];
              return InkWell(
                onTap: () => openAuthorProfile(context, persona.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: <Widget>[
                      AuthorAvatar(authorId: persona.id, radius: 26),
                      const SizedBox(height: 4),
                      Text(persona.name, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<_ProfileTab>(
            segments: const <ButtonSegment<_ProfileTab>>[
              ButtonSegment<_ProfileTab>(
                value: _ProfileTab.posts,
                icon: Icon(Icons.grid_on),
                label: Text('내 게시물'),
              ),
              ButtonSegment<_ProfileTab>(
                value: _ProfileTab.saved,
                icon: Icon(Icons.bookmark_border),
                label: Text('저장됨'),
              ),
            ],
            selected: <_ProfileTab>{_tab},
            onSelectionChanged: (Set<_ProfileTab> value) =>
                setState(() => _tab = value.first),
          ),
        ),
        if (_tab == _ProfileTab.posts)
          PostGrid(
            posts: myPosts,
            embedded: true,
            emptyText: '아직 올린 게시물이 없어요. + 탭에서 첫 게시물을 올려보세요!',
          )
        else
          PostGrid(posts: saved, embedded: true, emptyText: '저장한 게시물이 없어요.'),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/navigation.dart';
import 'package:assence/state/feed_store.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/widgets/author_avatar.dart';
import 'package:assence/widgets/post_grid.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FeedStore feed = context.watch<FeedStore>();
    final PersonaStore personaStore = context.watch<PersonaStore>();
    final String q = _query.trim().toLowerCase();
    final List<Persona> personas = q.isEmpty
        ? const <Persona>[]
        : personaStore.all
            .where((Persona p) =>
                p.name.toLowerCase().contains(q) ||
                p.handle.toLowerCase().contains(q) ||
                p.bio.toLowerCase().contains(q))
            .toList();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: _controller,
            onChanged: (String value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'AI 포스트 및 페르소나 검색 (#해시태그)',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: '검색어 지우기',
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: Colors.grey[200],
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        for (final Persona persona in personas)
          ListTile(
            leading: AuthorAvatar(authorId: persona.id),
            title: Text(persona.handle),
            subtitle: Text('${persona.name} · ${persona.bio}'),
            onTap: () => openAuthorProfile(context, persona.id),
          ),
        Expanded(
          child: PostGrid(
            posts: feed.search(_query),
            emptyText: '"$_query"에 맞는 게시물이 없어요.',
          ),
        ),
      ],
    );
  }
}

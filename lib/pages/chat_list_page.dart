import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/chat_message.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/pages/chat_room_page.dart';
import 'package:assence/state/chat_store.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/state/user_profile_store.dart';
import 'package:assence/utils/format.dart';
import 'package:assence/widgets/add_character_dialog.dart';
import 'package:assence/widgets/author_avatar.dart';

/// 인스타그램 DM처럼 대화 상대를 목록에서 골라 들어가는 화면.
class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openRoom(String personaId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatRoomPage(personaId: personaId),
      ),
    );
  }

  Future<void> _newMessage() async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => _NewMessageSheet(),
    );
    if (selected != null && mounted) _openRoom(selected);
  }

  /// 대화가 있는 상대는 최근 메시지 순, 없는 상대는 기본 순서로 뒤에 둔다.
  List<Persona> _sorted(List<Persona> personas, ChatStore chat) {
    final List<Persona> withMessages =
        personas.where((Persona p) => chat.lastMessageOf(p.id) != null).toList()
          ..sort(
            (Persona a, Persona b) => chat
                .lastMessageOf(b.id)!
                .createdAt
                .compareTo(chat.lastMessageOf(a.id)!.createdAt),
          );
    return <Persona>[
      ...withMessages,
      ...personas.where((Persona p) => chat.lastMessageOf(p.id) == null),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ChatStore chat = context.watch<ChatStore>();
    final List<Persona> all = context.watch<PersonaStore>().all;
    final String q = _query.trim().toLowerCase();
    final List<Persona> conversations = _sorted(
      q.isEmpty
          ? all
          : all
                .where(
                  (Persona p) =>
                      p.name.toLowerCase().contains(q) ||
                      p.handle.toLowerCase().contains(q),
                )
                .toList(),
      chat,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.watch<UserProfileStore>().handle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.edit_square),
            tooltip: '새 메시지',
            onPressed: _newMessage,
          ),
        ],
      ),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (String value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: '검색',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[200],
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (q.isEmpty)
            SizedBox(
              height: 128,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: <Widget>[
                  for (final Persona persona in all)
                    _PersonaNote(
                      persona: persona,
                      onTap: () => _openRoom(persona.id),
                    ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '메시지',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          if (conversations.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  '"$_query"에 맞는 대화 상대가 없어요.',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
          for (final Persona persona in conversations)
            _ConversationTile(
              persona: persona,
              onTap: () => _openRoom(persona.id),
              onLongPress: persona.isCustom
                  ? () => confirmDeleteCharacter(context, persona)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Persona persona;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ConversationTile({
    required this.persona,
    required this.onTap,
    this.onLongPress,
  });

  String _preview(ChatStore chat) {
    if (chat.isPending(persona.id)) return '입력 중...';
    if (chat.errorOf(persona.id) != null) return '전송 실패 · 눌러서 다시 시도';
    final ChatMessage? last = chat.lastMessageOf(persona.id);
    if (last == null) return persona.bio;
    final String text = last.text.replaceAll('\n', ' ');
    return '${last.isUser ? '나: ' : ''}$text';
  }

  @override
  Widget build(BuildContext context) {
    final ChatStore chat = context.watch<ChatStore>();
    final bool unread = chat.isUnread(persona.id);
    final ChatMessage? last = chat.lastMessageOf(persona.id);
    final TextStyle subtitleStyle = TextStyle(
      color: unread ? Colors.black : Colors.grey[600],
      fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
    );

    return ListTile(
      key: ValueKey<String>('conversation_${persona.id}'),
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: AuthorAvatar(authorId: persona.id, radius: 28),
      title: Text(
        persona.name,
        style: TextStyle(
          fontWeight: unread ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              _preview(chat),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: subtitleStyle,
            ),
          ),
          if (last != null && !chat.isPending(persona.id))
            Text(' · ${formatTimeAgo(last.createdAt)}', style: subtitleStyle),
        ],
      ),
      trailing: unread
          ? const CircleAvatar(radius: 5, backgroundColor: Color(0xFF6A3DF0))
          : null,
    );
  }
}

/// 인스타그램 노트처럼 아바타 위에 한 줄 소개 말풍선을 띄운다.
class _PersonaNote extends StatelessWidget {
  final Persona persona;
  final VoidCallback onTap;

  const _PersonaNote({required this.persona, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 92,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxWidth: 88),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                persona.bio,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 4),
            AuthorAvatar(authorId: persona.id, radius: 28),
            const SizedBox(height: 4),
            Text(
              persona.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewMessageSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final List<Persona> personas = context.watch<PersonaStore>().all;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '새 메시지',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_add_alt_1)),
            title: const Text('새 AI 캐릭터 만들기'),
            onTap: () async {
              final Persona? created = await showAddCharacterDialog(context);
              if (created != null && context.mounted) {
                Navigator.pop(context, created.id);
              }
            },
          ),
          for (final Persona persona in personas)
            ListTile(
              leading: AuthorAvatar(authorId: persona.id, radius: 20),
              title: Text(persona.name),
              subtitle: Text(persona.handle),
              onTap: () => Navigator.pop(context, persona.id),
            ),
        ],
      ),
    );
  }
}

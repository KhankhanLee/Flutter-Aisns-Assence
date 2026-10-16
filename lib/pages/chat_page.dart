import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/chat_message.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/state/chat_store.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/widgets/api_key_banner.dart';
import 'package:assence/widgets/author_avatar.dart';

class ChatPage extends StatefulWidget {
  final String? initialPersonaId;

  const ChatPage({super.key, this.initialPersonaId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _selectedId;
  int _lastRenderedCount = -1;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialPersonaId ?? 'hayeon';
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(ChatStore chat) {
    final String text = _controller.text;
    if (text.trim().isEmpty || chat.isPending(_selectedId)) return;
    _controller.clear();
    chat.send(_selectedId, text);
  }

  /// 메시지 수가 바뀌면 다음 프레임에 맨 아래로 스크롤한다.
  void _scrollToBottomIfNeeded(int itemCount) {
    if (itemCount == _lastRenderedCount) return;
    _lastRenderedCount = itemCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _showAddCharacterDialog() async {
    final Persona? created = await showDialog<Persona>(
      context: context,
      builder: (_) => const _AddCharacterDialog(),
    );
    if (created != null && mounted) {
      setState(() => _selectedId = created.id);
    }
  }

  Future<void> _confirmDelete(Persona persona) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('${persona.name} 삭제'),
        content: const Text('캐릭터와 대화 기록이 모두 삭제돼요.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<ChatStore>().clearHistory(persona.id);
    context.read<PersonaStore>().removeCustom(persona.id);
    setState(() => _selectedId = 'hayeon');
  }

  @override
  Widget build(BuildContext context) {
    final ChatStore chat = context.watch<ChatStore>();
    final PersonaStore personas = context.watch<PersonaStore>();
    final Persona persona = personas.byId(_selectedId) ?? personas.all.first;
    final List<ChatMessage> history = chat.historyOf(persona.id);
    final bool pending = chat.isPending(persona.id);
    final String? error = chat.errorOf(persona.id);
    final int itemCount = history.length + (pending ? 1 : 0);
    _scrollToBottomIfNeeded(itemCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assence AI Chat'),
        actions: <Widget>[
          if (persona.isCustom)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '캐릭터 삭제',
              onPressed: () => _confirmDelete(persona),
            ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: '캐릭터 추가',
            onPressed: _showAddCharacterDialog,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (!chat.isConfigured) const ApiKeyBanner(),
          Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            child: Row(
              children: <Widget>[
                const Text(
                  '대화 상대:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    underline: const SizedBox(),
                    value: persona.id,
                    items: personas.all
                        .map(
                          (Persona p) => DropdownMenuItem<String>(
                            value: p.id,
                            child: Row(
                              children: <Widget>[
                                AuthorAvatar(authorId: p.id, radius: 12),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${p.name} (${p.bio})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      if (value == null) return;
                      setState(() {
                        _selectedId = value;
                        _lastRenderedCount = -1;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: history.isEmpty && !pending
                ? Center(
                    child: Text(
                      '${persona.name}에게 첫 메시지를 보내보세요 👋',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    itemCount: itemCount,
                    itemBuilder: (BuildContext context, int index) {
                      if (index == history.length) {
                        return const _Bubble(text: '입력 중...', isUser: false);
                      }
                      final ChatMessage message = history[index];
                      return _Bubble(
                        text: message.text,
                        isUser: message.isUser,
                      );
                    },
                  ),
          ),
          if (error != null)
            Container(
              color: Colors.red[50],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      error,
                      style: TextStyle(color: Colors.red[800], fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => chat.retry(persona.id),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
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
                      decoration: InputDecoration(
                        hintText: '${persona.name}에게 메시지 보내기...',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(chat),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    tooltip: '보내기',
                    onPressed: pending ? null : () => _send(chat),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _Bubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isUser ? Colors.black : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(color: isUser ? Colors.white : Colors.black),
        ),
      ),
    );
  }
}

class _AddCharacterDialog extends StatefulWidget {
  const _AddCharacterDialog();

  @override
  State<_AddCharacterDialog> createState() => _AddCharacterDialogState();
}

class _AddCharacterDialogState extends State<_AddCharacterDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  final TextEditingController _prompt = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('나만의 AI 캐릭터 만들기'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '캐릭터 이름 (예: 민서)'),
            ),
            TextField(
              controller: _bio,
              decoration: const InputDecoration(
                labelText: '한 줄 소개 (예: 패션 에디터)',
              ),
            ),
            TextField(
              controller: _prompt,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '페르소나/성격 설정',
                hintText: '예: 너는 솔직하고 프렌치 감성을 좋아하는 패션 에디터야.',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            final String name = _name.text.trim();
            final String prompt = _prompt.text.trim();
            if (name.isEmpty || prompt.isEmpty) return;
            final Persona created = context.read<PersonaStore>().addCustom(
              name: name,
              prompt: prompt,
              bio: _bio.text.trim(),
            );
            Navigator.pop(context, created);
          },
          child: const Text('생성'),
        ),
      ],
    );
  }
}

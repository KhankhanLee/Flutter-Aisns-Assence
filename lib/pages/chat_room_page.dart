import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/chat_message.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/story.dart';
import 'package:assence/navigation.dart';
import 'package:assence/services/media_storage.dart';
import 'package:assence/state/ai_settings_store.dart';
import 'package:assence/state/chat_store.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/widgets/api_key_banner.dart';
import 'package:assence/utils/humanize.dart';
import 'package:assence/widgets/app_image.dart';
import 'package:assence/widgets/author_avatar.dart';

/// 페르소나 한 명과의 DM 대화방.
class ChatRoomPage extends StatefulWidget {
  final String personaId;

  /// 보낼 사진 고르기. 테스트에서 바꿔 끼운다.
  final PhotoPicker? pickPhoto;

  const ChatRoomPage({super.key, required this.personaId, this.pickPhoto});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _lastRenderedCount = -1;

  /// 보내려고 고른 사진. 보내거나 취소하면 null.
  String? _photo;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _canSend => _controller.text.trim().isNotEmpty || _photo != null;

  void _send(ChatStore chat) {
    final String text = _controller.text;
    if (!_canSend || chat.isPending(widget.personaId)) return;
    final String? photo = _photo;
    _controller.clear();
    setState(() => _photo = null);
    chat.send(widget.personaId, text, imagePath: photo);
  }

  Future<void> _pickPhoto() async {
    final PhotoPicker pick =
        widget.pickPhoto ?? devicePhotoPicker(folder: 'dm_photos');
    try {
      final String? path = await pick(ImageSource.gallery);
      if (path != null && mounted) setState(() => _photo = path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 가져오지 못했어요. 권한을 확인해 주세요.')),
      );
    }
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

  Future<void> _confirmDelete(Persona persona) async {
    final bool? confirmed = await confirmDeleteCharacter(context, persona);
    if (confirmed == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ChatStore chat = context.watch<ChatStore>();
    final Persona? persona = context.watch<PersonaStore>().byId(
      widget.personaId,
    );
    if (persona == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('삭제된 대화예요.')),
      );
    }

    final List<ChatMessage> history = chat.historyOf(persona.id);
    final bool pending = chat.isPending(persona.id);
    final String? error = chat.errorOf(persona.id);
    final int itemCount = history.length + (pending ? 1 : 0);
    _scrollToBottomIfNeeded(itemCount);
    // 대화방을 보고 있는 동안 도착한 답장은 바로 읽음 처리한다.
    if (chat.isUnread(persona.id)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => chat.markRead(persona.id),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => openAuthorProfile(context, persona.id),
          child: Row(
            children: <Widget>[
              AuthorAvatar(authorId: persona.id, radius: 16),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    persona.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    persona.handle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: <Widget>[
          if (persona.isCustom)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '캐릭터 삭제',
              onPressed: () => _confirmDelete(persona),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (!context.watch<AiSettingsStore>().isConfigured)
            const ApiKeyBanner(),
          Expanded(
            child: history.isEmpty && !pending
                ? _EmptyRoom(persona: persona)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    itemCount: itemCount,
                    itemBuilder: (BuildContext context, int index) {
                      if (index == history.length) {
                        return _Bubble(
                          text: '입력 중...',
                          isUser: false,
                          personaId: persona.id,
                        );
                      }
                      final ChatMessage message = history[index];
                      return _Bubble(
                        // 예전에 저장된 긴 답장도 마크다운 기호 없이 보여준다.
                        text: message.isUser
                            ? message.text
                            : humanizeReply(message.text, maxEmoji: 99),
                        isUser: message.isUser,
                        personaId: persona.id,
                        imagePath: message.imagePath,
                        story: message.story,
                        storyLabel: message.isUser
                            ? '${persona.name}님의 스토리에 답장함'
                            : '회원님의 스토리에 답장했어요',
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
          if (_photo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AppImage(
                        _photo!,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                        tooltip: '사진 빼기',
                        onPressed: () => setState(() => _photo = null),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4.0, 4.0, 4.0, 10.0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.photo_outlined),
                    tooltip: '사진 보내기',
                    onPressed: pending ? null : _pickPhoto,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: '메시지 보내기...',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(chat),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    tooltip: '보내기',
                    onPressed: pending || !_canSend ? null : () => _send(chat),
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

/// 커스텀 캐릭터 삭제를 확인하고, 확인하면 대화 기록과 함께 지운다.
Future<bool?> confirmDeleteCharacter(
  BuildContext context,
  Persona persona,
) async {
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
  if (confirmed == true && context.mounted) {
    context.read<ChatStore>().clearHistory(persona.id);
    context.read<PersonaStore>().removeCustom(persona.id);
  }
  return confirmed;
}

class _EmptyRoom extends StatelessWidget {
  final Persona persona;

  const _EmptyRoom({required this.persona});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            AuthorAvatar(authorId: persona.id, radius: 44),
            const SizedBox(height: 12),
            Text(
              persona.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              '${persona.handle} · Assence AI',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(persona.bio, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => openAuthorProfile(context, persona.id),
              child: const Text('프로필 보기'),
            ),
            const SizedBox(height: 24),
            Text(
              '${persona.name}에게 첫 메시지를 보내보세요 👋',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final String personaId;
  final SharedStory? story;
  final String storyLabel;
  final String? imagePath;

  const _Bubble({
    required this.text,
    required this.isUser,
    required this.personaId,
    this.story,
    this.storyLabel = '',
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final SharedStory? shared = story;
    final String? photo = imagePath;
    final double width = MediaQuery.sizeOf(context).width;
    final Widget textBubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.7,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFF6A3DF0) : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: isUser ? Colors.white : Colors.black),
      ),
    );
    // 사진 메시지: 사진을 먼저, 글이 있으면 그 아래에 말풍선.
    final Widget body = photo == null
        ? textBubble
        : Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: width * 0.6,
                    maxHeight: width * 0.8,
                  ),
                  child: AppImage(photo, fit: BoxFit.cover),
                ),
              ),
              if (text.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                textBubble,
              ],
            ],
          );
    final Widget bubble = shared == null
        ? body
        : Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                storyLabel,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              _StoryThumb(story: shared),
              const SizedBox(height: 4),
              body,
            ],
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (!isUser) ...<Widget>[
            AuthorAvatar(authorId: personaId, radius: 12),
            const SizedBox(width: 8),
          ],
          bubble,
        ],
      ),
    );
  }
}

/// DM에 함께 보이는 스토리 미리보기. 24시간이 지나면 만료 표시만 남는다.
class _StoryThumb extends StatelessWidget {
  final SharedStory story;

  const _StoryThumb({required this.story});

  @override
  Widget build(BuildContext context) {
    final bool expired =
        DateTime.now().difference(story.createdAt) >= Story.lifetime;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 96,
        height: 150,
        child: expired
            ? Container(
                color: Colors.grey[200],
                alignment: Alignment.center,
                padding: const EdgeInsets.all(8),
                child: const Text(
                  '스토리가 만료됐어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              )
            : story.imagePath.isEmpty
            ? Container(
                color: const Color(0xff6a3df0),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(8),
                child: Text(
                  story.text,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              )
            : AppImage(story.imagePath, fit: BoxFit.cover),
      ),
    );
  }
}

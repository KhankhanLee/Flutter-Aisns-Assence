import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/story.dart';
import 'package:assence/state/chat_store.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/state/story_store.dart';
import 'package:assence/utils/format.dart';
import 'package:assence/widgets/app_image.dart';
import 'package:assence/widgets/author_avatar.dart';

/// 전체 화면 스토리 뷰어. 좌/우 탭으로 이동하고 일정 시간이 지나면 다음으로 넘어간다.
/// 페르소나 스토리에는 좋아요를 누르거나 답장할 수 있고(답장은 DM으로 간다),
/// 내 스토리에서는 누가 봤는지 볼 수 있다.
class StoryViewerPage extends StatefulWidget {
  static const Duration storyDuration = Duration(seconds: 5);

  final List<Story> stories;
  final int initialIndex;

  const StoryViewerPage({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  final TextEditingController _reply = TextEditingController();
  final FocusNode _replyFocus = FocusNode();
  late int _index;

  Story get _story => widget.stories[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _progress =
        AnimationController(
            vsync: this,
            duration: StoryViewerPage.storyDuration,
          )
          ..addStatusListener((AnimationStatus status) {
            if (status == AnimationStatus.completed) _next();
          })
          ..forward();
    // 답장을 쓰는 동안은 자동 넘김을 멈춘다.
    _replyFocus.addListener(() {
      if (_replyFocus.hasFocus) {
        _progress.stop();
      } else if (!_progress.isCompleted) {
        _progress.forward();
      }
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    _reply.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= widget.stories.length - 1) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _index++);
    _progress.forward(from: 0);
  }

  void _previous() {
    if (_index > 0) setState(() => _index--);
    _progress.forward(from: 0);
  }

  void _sendReply() {
    final String text = _reply.text.trim();
    if (text.isEmpty) return;
    final Story story = _story;
    context.read<ChatStore>().send(story.authorId, text, story: story);
    _reply.clear();
    _replyFocus.unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('메시지를 보냈어요. DM에서 답장을 확인해 보세요!')),
    );
  }

  /// 내 스토리를 본 사람 목록. 보는 동안은 자동 넘김을 멈춘다.
  Future<void> _showViewers(Story story) async {
    _progress.stop();
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => _ViewersSheet(story: story),
    );
    if (mounted && !_progress.isCompleted) _progress.forward();
  }

  @override
  Widget build(BuildContext context) {
    final Story story = _story;
    final PersonaStore personas = context.watch<PersonaStore>();
    final StoryStore stories = context.watch<StoryStore>();
    final bool fromPersona = story.authorId != myUserId;
    final bool liked = stories.isLiked(story.id);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                onTapUp: (TapUpDetails details) {
                  final double width = MediaQuery.sizeOf(context).width;
                  if (details.localPosition.dx < width / 3) {
                    _previous();
                  } else {
                    _next();
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (story.imagePath.isEmpty)
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              Color(0xff8e2de2),
                              Color(0xff4a00e0),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      )
                    else
                      AppImage(story.imagePath, fit: BoxFit.cover),
                    if (story.text.isNotEmpty)
                      Align(
                        alignment: story.imagePath.isEmpty
                            ? Alignment.center
                            : Alignment.bottomCenter,
                        child: Container(
                          margin: const EdgeInsets.all(24),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            story.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Column(
                        children: <Widget>[
                          _ProgressBars(
                            count: widget.stories.length,
                            index: _index,
                            progress: _progress,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              AuthorAvatar(
                                authorId: story.authorId,
                                radius: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                authorHandle(context, story.authorId),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatTimeAgo(story.createdAt),
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                tooltip: '닫기',
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (fromPersona)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        focusNode: _replyFocus,
                        style: const TextStyle(color: Colors.white),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendReply(),
                        decoration: InputDecoration(
                          hintText:
                              '${personas.byId(story.authorId)?.name ?? ''}님에게 답장 보내기...',
                          hintStyle: const TextStyle(color: Colors.white60),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Colors.white54),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        color: liked ? Colors.redAccent : Colors.white,
                      ),
                      tooltip: liked ? '좋아요 취소' : '좋아요',
                      onPressed: () => stories.toggleLike(story.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      tooltip: '답장 보내기',
                      onPressed: _sendReply,
                    ),
                  ],
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showViewers(story),
                  icon: const Icon(
                    Icons.remove_red_eye_outlined,
                    color: Colors.white,
                  ),
                  label: Text(
                    '활동 ${stories.viewersOf(story).length}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBars extends StatelessWidget {
  final int count;
  final int index;
  final Animation<double> progress;

  const _ProgressBars({
    required this.count,
    required this.index,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (BuildContext context, _) => Row(
        children: <Widget>[
          for (int i = 0; i < count; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: LinearProgressIndicator(
                  value: i < index ? 1 : (i == index ? progress.value : 0),
                  minHeight: 2.5,
                  backgroundColor: Colors.white30,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 내 스토리를 본 사람과 좋아요 표시.
class _ViewersSheet extends StatelessWidget {
  final Story story;

  const _ViewersSheet({required this.story});

  @override
  Widget build(BuildContext context) {
    final List<StoryView> viewers = context.watch<StoryStore>().viewersOf(
      story,
    );
    final PersonaStore personas = context.watch<PersonaStore>();
    final int likes = viewers.where((StoryView v) => v.liked).length;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '조회 ${viewers.length}명${likes > 0 ? ' · 좋아요 $likes' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          if (viewers.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Text(
                '아직 아무도 안 봤어요. 친구들이 보면 여기에 나타나요.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final StoryView view in viewers)
                    ListTile(
                      leading: AuthorAvatar(authorId: view.personaId),
                      title: Text(
                        personas.byId(view.personaId)?.handle ?? view.personaId,
                      ),
                      subtitle: Text(formatTimeAgo(view.at)),
                      trailing: view.liked
                          ? const Icon(Icons.favorite, color: Colors.redAccent)
                          : null,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

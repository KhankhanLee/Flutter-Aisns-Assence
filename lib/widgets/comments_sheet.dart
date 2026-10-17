import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/comment.dart';
import 'package:assence/models/post.dart';
import 'package:assence/state/feed_store.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/utils/format.dart';
import 'package:assence/utils/humanize.dart';
import 'package:assence/widgets/author_avatar.dart';

Future<void> showCommentsSheet(BuildContext context, String postId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: CommentsSheet(postId: postId),
    ),
  );
}

/// 원 댓글 아래에 답글을 들여쓰기해서 보여주는 댓글 목록.
List<Comment> threadedComments(List<Comment> comments) {
  final List<Comment> roots = comments
      .where((Comment c) => c.parentId == null)
      .toList();
  return <Comment>[
    for (final Comment root in roots) ...<Comment>[
      root,
      ...comments.where((Comment c) => c.parentId == root.id),
    ],
  ];
}

class CommentsSheet extends StatefulWidget {
  final String postId;

  const CommentsSheet({super.key, required this.postId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  /// 답글을 달 대상 댓글. null이면 새 댓글.
  Comment? _replyTo;

  @override
  Widget build(BuildContext context) {
    final FeedStore feed = context.watch<FeedStore>();
    final Post? post = feed.byId(widget.postId);
    if (post == null) return const SizedBox.shrink();
    final List<Comment> comments = threadedComments(post.comments);

    return Column(
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('댓글', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const Divider(height: 1),
        Expanded(
          child: comments.isEmpty
              ? const Center(
                  child: Text(
                    '아직 댓글이 없어요. 첫 댓글을 남겨보세요!',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: comments.length,
                  itemBuilder: (BuildContext context, int index) => CommentTile(
                    comment: comments[index],
                    onReply: (Comment c) => setState(() => _replyTo = c),
                  ),
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: CommentInput(
            postId: widget.postId,
            autofocus: true,
            replyTo: _replyTo,
            onReplyDone: () => setState(() => _replyTo = null),
          ),
        ),
      ],
    );
  }
}

class CommentTile extends StatelessWidget {
  final Comment comment;
  final bool compact;

  /// '답글 달기'를 눌렀을 때. null이면 버튼을 숨긴다.
  final ValueChanged<Comment>? onReply;

  const CommentTile({
    super.key,
    required this.comment,
    this.compact = false,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final FeedStore feed = context.watch<FeedStore>();
    final String handle = authorHandle(context, comment.authorId);
    final bool isReply = comment.parentId != null;
    final String? error = feed.replyErrorOf(comment.id);

    final Widget body = RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 13),
        children: <TextSpan>[
          TextSpan(
            text: '$handle ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: comment.authorId == myUserId
                ? comment.text
                : humanizeReply(comment.text, maxEmoji: 99),
          ),
        ],
      ),
    );

    if (compact) {
      return Padding(
        padding: EdgeInsets.fromLTRB(isReply ? 32 : 16, 2, 16, 2),
        child: body,
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(isReply ? 52 : 16, 6, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AuthorAvatar(authorId: comment.authorId, radius: isReply ? 12 : 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                body,
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Text(
                      formatTimeAgo(comment.createdAt),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    if (onReply != null) ...<Widget>[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => onReply!(comment),
                        child: const Text(
                          '답글 달기',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (feed.isReplyPending(comment.id))
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      '답글 작성 중...',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                if (error != null)
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          error,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => feed.retryReply(comment.id),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommentInput extends StatefulWidget {
  final String postId;
  final bool autofocus;

  /// 답글을 달 대상. 있으면 입력창 위에 표시하고, 보내면 그 스레드에 붙는다.
  final Comment? replyTo;
  final VoidCallback? onReplyDone;

  const CommentInput({
    super.key,
    required this.postId,
    this.autofocus = false,
    this.replyTo,
    this.onReplyDone,
  });

  @override
  State<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<CommentInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(CommentInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 답글 대상을 고르면 바로 입력할 수 있게 포커스를 준다.
    if (widget.replyTo != null && widget.replyTo != oldWidget.replyTo) {
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final String text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    context.read<FeedStore>().addComment(
      widget.postId,
      text,
      replyToId: widget.replyTo?.id,
    );
    widget.onReplyDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final Comment? replyTo = widget.replyTo;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (replyTo != null)
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${authorHandle(context, replyTo.authorId)}님에게 답글 남기는 중',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: '답글 취소',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onReplyDone,
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: Row(
            children: <Widget>[
              const AuthorAvatar(authorId: 'me', radius: 14),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: replyTo == null ? '댓글 달기...' : '답글 달기...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
              TextButton(
                onPressed: _controller.text.trim().isEmpty ? null : _submit,
                child: const Text('게시'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/comment.dart';
import 'package:assence/models/post.dart';
import 'package:assence/state/feed_store.dart';
import 'package:assence/utils/format.dart';
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

class CommentsSheet extends StatelessWidget {
  final String postId;

  const CommentsSheet({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    final FeedStore feed = context.watch<FeedStore>();
    final Post? post = feed.byId(postId);
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
                  itemBuilder: (BuildContext context, int index) =>
                      CommentTile(comment: comments[index]),
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: CommentInput(postId: postId, autofocus: true),
        ),
      ],
    );
  }
}

class CommentTile extends StatelessWidget {
  final Comment comment;
  final bool compact;

  const CommentTile({super.key, required this.comment, this.compact = false});

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
          TextSpan(text: comment.text),
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
                Text(
                  formatTimeAgo(comment.createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
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

  const CommentInput({super.key, required this.postId, this.autofocus = false});

  @override
  State<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<CommentInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    context.read<FeedStore>().addComment(widget.postId, text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      child: Row(
        children: <Widget>[
          const AuthorAvatar(authorId: 'me', radius: 14),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '댓글 달기...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
          TextButton(
            onPressed: _controller.text.trim().isEmpty ? null : _submit,
            child: const Text('게시'),
          ),
        ],
      ),
    );
  }
}

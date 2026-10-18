import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/comment.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/post.dart';
import 'package:assence/navigation.dart';
import 'package:assence/state/feed_store.dart';
import 'package:assence/utils/format.dart';
import 'package:assence/widgets/app_image.dart';
import 'package:assence/widgets/author_avatar.dart';
import 'package:assence/widgets/comments_sheet.dart';

class PostCard extends StatelessWidget {
  static const int _previewCommentCount = 2;

  final Post post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final FeedStore feed = context.read<FeedStore>();
    final String handle = authorHandle(context, post.authorId);
    final bool fromPersona = post.authorId != myUserId;
    final List<Comment> thread = threadedComments(post.comments);
    final List<Comment> preview = thread.length > _previewCommentCount
        ? thread.sublist(thread.length - _previewCommentCount)
        : thread;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 8.0, 12.0),
          child: InkWell(
            onTap: () => openAuthorProfile(context, post.authorId),
            child: Row(
              children: <Widget>[
                AuthorAvatar(authorId: post.authorId),
                const SizedBox(width: 10.0),
                Text(
                  handle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onDoubleTap: () {
            if (!post.likedByMe) feed.toggleLike(post.id);
          },
          child: AspectRatio(aspectRatio: 1, child: AppImage(post.imagePath)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: <Widget>[
              IconButton(
                icon: Icon(
                  post.likedByMe ? Icons.favorite : Icons.favorite_border,
                  color: post.likedByMe ? Colors.red : Colors.black,
                ),
                tooltip: '좋아요',
                onPressed: () => feed.toggleLike(post.id),
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: '댓글',
                onPressed: () => showCommentsSheet(context, post.id),
              ),
              if (fromPersona)
                IconButton(
                  icon: const Icon(Icons.send_outlined),
                  tooltip: '메시지 보내기',
                  onPressed: () => openChat(context, personaId: post.authorId),
                ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  post.bookmarked ? Icons.bookmark : Icons.bookmark_border,
                ),
                tooltip: '저장',
                onPressed: () => feed.toggleBookmark(post.id),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _LikesLine(post: post),
        ),
        if (post.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 6.0, 16.0, 0.0),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black, fontSize: 14),
                children: <TextSpan>[
                  TextSpan(
                    text: '$handle ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: post.caption),
                ],
              ),
            ),
          ),
        if (thread.length > _previewCommentCount)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: GestureDetector(
              onTap: () => showCommentsSheet(context, post.id),
              child: Text(
                '댓글 ${thread.length}개 모두 보기',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ),
        if (preview.isNotEmpty) const SizedBox(height: 4),
        for (final Comment comment in preview)
          // 미리보기 댓글을 누르면 댓글 창이 열려 답글을 달 수 있다.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showCommentsSheet(context, post.id),
            child: CommentTile(comment: comment, compact: true),
          ),
        if (post.comments.any((Comment c) => feed.isReplyPending(c.id)))
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 2, 16, 0),
            child: Text(
              '$handle 님이 답글을 작성 중...',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        for (final Comment comment in post.comments)
          if (feed.replyErrorOf(comment.id) != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 16, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      feed.replyErrorOf(comment.id)!,
                      style: TextStyle(color: Colors.red[700], fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => feed.retryReply(comment.id),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
        CommentInput(
          key: ValueKey<String>('input_${post.id}'),
          postId: post.id,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            formatTimeAgo(post.createdAt),
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// "좋아요 N개", 또는 AI 친구가 눌렀으면 "hayeon_daily님 외 N명이 좋아합니다".
class _LikesLine extends StatelessWidget {
  final Post post;

  const _LikesLine({required this.post});

  @override
  Widget build(BuildContext context) {
    final List<String> friends = post.friendLikersAt(DateTime.now());
    final int total = post.likes + friends.length;
    const TextStyle bold = TextStyle(fontWeight: FontWeight.bold);
    if (friends.isEmpty) {
      return Text('좋아요 ${formatCount(total)}개', style: bold);
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 14),
        children: <TextSpan>[
          TextSpan(text: authorHandle(context, friends.last), style: bold),
          const TextSpan(text: '님 '),
          if (total > 1) ...<TextSpan>[
            const TextSpan(text: '외 '),
            TextSpan(text: '${formatCount(total - 1)}명', style: bold),
            const TextSpan(text: '이 '),
          ] else
            const TextSpan(text: '이 '),
          const TextSpan(text: '좋아합니다'),
        ],
      ),
    );
  }
}

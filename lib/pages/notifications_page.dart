import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/app_notification.dart';
import 'package:assence/navigation.dart';
import 'package:assence/state/notification_store.dart';
import 'package:assence/utils/format.dart';
import 'package:assence/widgets/author_avatar.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<AppNotification> items = context
        .watch<NotificationStore>()
        .items;

    if (items.isEmpty) {
      return const Center(
        child: Text(
          '아직 알림이 없어요.\nAI 친구 게시물에 댓글을 남겨보세요!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final AppNotification n = items[index];
        final String handle = authorHandle(context, n.personaId);
        final String action = switch (n.type) {
          NotificationType.commentReply => '님이 회원님의 댓글에 답글을 남겼어요',
          NotificationType.postReaction => '님이 회원님의 게시물에 댓글을 남겼어요',
        };
        return ListTile(
          tileColor: n.read ? null : Colors.blue[50],
          leading: AuthorAvatar(authorId: n.personaId),
          title: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 14),
              children: <TextSpan>[
                TextSpan(
                  text: handle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: '$action: ${n.text}'),
              ],
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            formatTimeAgo(n.createdAt),
            style: const TextStyle(fontSize: 11),
          ),
          onTap: () => openPost(context, n.postId),
        );
      },
    );
  }
}

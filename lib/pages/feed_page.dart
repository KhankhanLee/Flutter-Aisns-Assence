import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/post.dart';
import 'package:assence/state/ai_settings_store.dart';
import 'package:assence/state/feed_store.dart';
import 'package:assence/widgets/api_key_banner.dart';
import 'package:assence/widgets/post_card.dart';
import 'package:assence/widgets/stories_bar.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  /// 당겨서 새로고침하면 게시 예정 시각이 지난 AI 친구의 새 게시물을 확인한다.
  /// AI 친구는 각자 일정대로만 올리므로 새로고침해도 매번 새 글이 생기지는 않는다.
  Future<void> _refresh(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (!context.read<AiSettingsStore>().isConfigured) {
      messenger.showSnackBar(
        const SnackBar(content: Text('AI 친구의 새 게시물을 받으려면 API 키가 필요해요.')),
      );
      return;
    }
    final int posted = await context.read<FeedStore>().runScheduledPosts();
    if (posted == 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('아직 새 게시물이 없어요. AI 친구들도 각자 시간에 올려요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final FeedStore feed = context.watch<FeedStore>();
    final bool configured = context.watch<AiSettingsStore>().isConfigured;
    final List<Post> posts = feed.posts;
    final List<Widget> headers = <Widget>[
      if (!configured) const ApiKeyBanner(),
      const StoriesBar(),
      if (feed.isCreatingPost)
        const ListTile(
          dense: true,
          leading: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('AI 친구가 새 게시물을 올리는 중...'),
        ),
    ];

    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: posts.length + headers.length,
        itemBuilder: (BuildContext context, int index) {
          if (index < headers.length) return headers[index];
          final Post post = posts[index - headers.length];
          return PostCard(key: ValueKey<String>(post.id), post: post);
        },
      ),
    );
  }
}

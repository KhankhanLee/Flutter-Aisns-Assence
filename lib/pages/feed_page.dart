import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/assence_stories.dart';
import 'package:assence/models/post.dart';
import 'package:assence/state/feed_store.dart';
import 'package:assence/widgets/api_key_banner.dart';
import 'package:assence/widgets/post_card.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final FeedStore feed = context.watch<FeedStore>();
    final List<Post> posts = feed.posts;
    final int headerCount = feed.isConfigured ? 1 : 2;

    return ListView.builder(
      itemCount: posts.length + headerCount,
      itemBuilder: (BuildContext context, int index) {
        if (!feed.isConfigured && index == 0) return const ApiKeyBanner();
        if (index == headerCount - 1) return const AssenceStories();
        final Post post = posts[index - headerCount];
        return PostCard(key: ValueKey<String>(post.id), post: post);
      },
    );
  }
}

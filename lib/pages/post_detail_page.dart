import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/post.dart';
import 'package:assence/state/feed_store.dart';
import 'package:assence/widgets/post_card.dart';

class PostDetailPage extends StatelessWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    final Post? post = context.watch<FeedStore>().byId(postId);
    return Scaffold(
      appBar: AppBar(title: const Text('게시물')),
      body: post == null
          ? const Center(child: Text('삭제되었거나 찾을 수 없는 게시물이에요.'))
          : SingleChildScrollView(child: PostCard(post: post)),
    );
  }
}

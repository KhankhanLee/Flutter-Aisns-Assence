import 'package:flutter/material.dart';
import 'package:assence/models/post.dart';
import 'package:assence/navigation.dart';
import 'package:assence/widgets/app_image.dart';

/// 3열 썸네일 그리드. 누르면 게시물 상세로 이동한다.
/// 다른 스크롤 뷰 안에 넣을 때는 [embedded]를 true로 준다.
class PostGrid extends StatelessWidget {
  final List<Post> posts;
  final bool embedded;
  final String emptyText;

  const PostGrid({
    super.key,
    required this.posts,
    this.embedded = false,
    this.emptyText = '게시물이 없어요.',
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(emptyText, style: const TextStyle(color: Colors.grey)),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(2.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2.0,
        mainAxisSpacing: 2.0,
      ),
      itemCount: posts.length,
      itemBuilder: (BuildContext context, int index) {
        final Post post = posts[index];
        return GestureDetector(
          key: ValueKey<String>('grid_${post.id}'),
          onTap: () => openPost(context, post.id),
          child: AppImage(post.imagePath),
        );
      },
    );
  }
}

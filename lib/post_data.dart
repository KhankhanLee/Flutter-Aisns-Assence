import 'package:flutter/material.dart';
import 'package0font_awesome_flutter/font_awesome_flutter.dart';
import 'package:assence/assence_stories.dart';
import 'package:assence/post_data.dart';

class AssenceList extends StatefulWidget {
  const AssenceList({super.key});

  @override
  State<AssenceList> createState() => _AssenceListState();
}

class _AssenceListState extends State<AssenceList> {
  final Map<int, bool> _likedPosts = {};
  final Map<int, TextEditingController> _commentControllers = {};

  @override
  void dispose() {
    for (var controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getCommentController(int index) {
    if (!_commentControllers.containsKey(index)) {
      _commentControllers[index] = TextEditingController();
    }
    return _commentControllers[index]!;
  }

  @override
  Widget build(BuildContext context) {
    final deviceSize = MediaQuery.of(context).size;

    return ListView.builder(
      itemCount: samplePosts.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return SizedBox(
            height: deviceSize.height * 0.15,
            child: const AssenceStories(),
          );
        }

        final postIndex = index - 1;
        final post = samplePosts[postIndex];
        final isLiked = _likedPosts[postIndex] ?? false;

        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 1. 헤더 (에셋 프로필 이미지 적용)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 8.0, 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        height: 36.0,
                        width: 36.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            fit: BoxFit.cover,
                            image: AssetImage(post.userImage), // ⭕️ post.userImage 연동
                          ),
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      Text(
                        post.username,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {},
                  )
                ],
              ),
            ),

            // 2. 피드 이미지 (Image.asset 및 post.postImage 연동)
            Flexible(
              fit: FlexFit.loose,
              child: Image.asset( // ⭕️ Image.asset 사용
                post.postImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 300,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey, size: 50),
                    ),
                  );
                },
              ),
            ),

            // 3. 버튼 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        icon: Icon(
                          isLiked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                          color: isLiked ? Colors.red : Colors.black,
                        ),
                        onPressed: () {
                          setState(() {
                            _likedPosts[postIndex] = !isLiked;
                          });
                        },
                      ),
                      const SizedBox(width: 8.0),
                      const Icon(FontAwesomeIcons.comment),
                      const SizedBox(width: 16.0),
                      const Icon(FontAwesomeIcons.paperPlane),
                    ],
                  ),
                  const Icon(FontAwesomeIcons.bookmark)
                ],
              ),
            ),

            // 4. 좋아요 수
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                '좋아요 ${post.likes}개',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            // 5. 캡션
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 6.0, 16.0, 0.0),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  children: [
                    TextSpan(
                      text: '${post.username} ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: post.caption),
                  ],
                ),
              ),
            ),

            // 6. 댓글 입력란
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4.0),
              child: Row(
                children: <Widget>[
                  Container(
                    height: 30.0,
                    width: 30.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        fit: BoxFit.cover,
                        image: AssetImage(post.userImage),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: TextField(
                      controller: _getCommentController(postIndex),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "댓글 달기...",
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 7. 작성 시간
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                post.timeAgo,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),

            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:assence/assence_stories.dart';
import 'package:assence/post_data.dart';

class AssenceList extends StatefulWidget {
  const AssenceList({super.key});

  @override
  State<AssenceList> createState() => _AssenceListState();
}

class _AssenceListState extends State<AssenceList> {
  // 포스트별 좋아요 상태 및 개수 관리를 위한 Map
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
      itemCount: samplePosts.length + 1, // 상단 스토리(1) + 캐릭터 포스트 수(7)
      itemBuilder: (context, index) {
        // 0번째는 상단 스토리 영역 노출
        if (index == 0) {
          return SizedBox(
            height: deviceSize.height * 0.15,
            child: const AssenceStories(),
          );
        }

        // 포스트 인덱스 (스토리 영역 제외)
        final postIndex = index - 1;
        final post = samplePosts[postIndex];
        final isLiked = _likedPosts[postIndex] ?? false;

        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 1. 헤더 (프로필 이미지 + 사용자 이름)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 8.0, 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue[100],
                        child: const Icon(Icons.person, color: Colors.blue),
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

            // 2. 캐릭터 포스트 이미지 (로컬 에셋 연동)
            Image.asset(
              post.postImage,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 300,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              ),
            ),

            // 3. 인터랙션 버튼 (좋아요, 댓글, 공유, 북마크)
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
                      IconButton(
                        icon: const Icon(FontAwesomeIcons.comment),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(FontAwesomeIcons.paperPlane),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(FontAwesomeIcons.bookmark),
                    onPressed: () {},
                  ),
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

            // 5. 캐릭터 작성 글 (Caption)
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
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey[300],
                    child: const Icon(Icons.person, size: 16, color: Colors.white),
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

            // 7. 게재 시간
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

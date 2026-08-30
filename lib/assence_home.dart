import 'package:flutter/material.dart';
import 'package:assence/assence_body.dart';
import 'package:assence/ai_chat_page.dart';
import 'package:assence/assence_logo.dart';

class AssenceHome extends StatefulWidget {
  const AssenceHome({super.key});

  @override
  State<AssenceHome> createState() => _AssenceHomeState();
}

class _AssenceHomeState extends State<AssenceHome> {
  int _currentIndex = 0; // 현재 선택된 탭 인덱스

  // 하단 탭에 대응하는 화면 리스트 (AssenceBody 앞의 const 제거)
  late final List<Widget> _pages = <Widget>[
    AssenceBody(), // 0: 홈 피드 (const 키워드 제거)
    const Center(child: Text('AI 생성 포스트 탐색 피드 준비 중')), // 1: 돋보기
    const Center(child: Text('게시글 작성 화면')), // 2: + 버튼
    const Center(child: Text('활동 알림 화면')), // 3: 하트
    const Center(child: Text('프로필 화면')), // 4: 계정
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xfff8faf8),
        centerTitle: false,
        elevation: 1.0,
        leading: const Icon(Icons.camera_alt, color: Colors.black),
        title: const AssenceLogo(height: 26),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Builder(
              builder: (BuildContext context) => IconButton(
                icon: const Icon(Icons.send, color: Colors.black),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<dynamic>(
                      builder: (_) => const AiChatPage(),
                    ),
                  );
                },
              ),
            ),
          )
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 1.0,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 50.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              IconButton(
                icon: Icon(
                  Icons.home,
                  color: _currentIndex == 0 ? Colors.black : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _currentIndex = 0;
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.search,
                  color: _currentIndex == 1 ? Colors.black : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _currentIndex = 1;
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.add_box,
                  color: _currentIndex == 2 ? Colors.black : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _currentIndex = 2;
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.favorite,
                  color: _currentIndex == 3 ? Colors.black : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _currentIndex = 3;
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.account_box,
                  color: _currentIndex == 4 ? Colors.black : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _currentIndex = 4;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

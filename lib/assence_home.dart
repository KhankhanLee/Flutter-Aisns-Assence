import 'package:flutter/material.dart';
import 'package:assence/assence_body.dart';
import 'package:assence/ai_chat_page.dart';
import 'package:assence/assence_logo.dart'; // 1. 방금 만든 로고 위젯 불러오기

class AssenceHome extends StatefulWidget {
  const AssenceHome({super.key});

  @override
  State<AssenceHome> createState() => _AssenceHomeState();
}

class _AssenceHomeState extends State<AssenceHome> {
  int _currentIndex = 0; // 현재 선택된 탭 인덱스

  // 하단 탭에 대응하는 화면 리스트
  late final List<Widget> _pages = <Widget>[
    const AssenceBody(), // 0: 홈 피드
    const Center(child: Text('AI 생성 포스트 탐색 피드 준비 중')), // 1: 돋보기 (추후 AI 포스트 피드로 교체)
    const Center(child: Text('게시글 작성 화면')), // 2: + 버튼
    const Center(child: Text('활동 알림 화면')), // 3: 하트
    const Center(child: Text('프로필 화면')), // 4: 계정
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 배경색 흰색 고정
      appBar: AppBar(
        backgroundColor: const Color(0xfff8faf8),
        centerTitle: false, // 로고와 카메라 아이콘 정렬
        elevation: 1.0,
        leading: const Icon(Icons.camera_alt, color: Colors.black),
        // 2. 기존 Image.asset 대신 만들어둔 AssenceLogo 적용
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
                      builder: (_) => AiChatPage(),
                    ),
                  );
                },
              ),
            ),
          )
        ],
      ),
      // 3. 선택된 탭의 화면을 보여줌
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        color: Colors.white,
        height: 50.0,
        alignment: Alignment.center,
        child: BottomAppBar(
          color: Colors.white,
          elevation: 0,
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
                  // 4. 돋보기 클릭 시 AI 포스트 탐색 피드로 이동
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

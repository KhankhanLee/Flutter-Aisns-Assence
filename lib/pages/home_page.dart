import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/navigation.dart';
import 'package:assence/pages/feed_page.dart';
import 'package:assence/state/notification_store.dart';
import 'package:assence/widgets/assence_logo.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const int feedTab = 0;
  static const int searchTab = 1;
  static const int composeTab = 2;
  static const int notificationsTab = 3;
  static const int profileTab = 4;

  int _currentIndex = feedTab;

  void _select(int index) => setState(() => _currentIndex = index);

  Widget _buildTab(int index) {
    switch (index) {
      case searchTab:
        return const Center(child: Text('AI 생성 포스트 탐색 피드 준비 중'));
      case composeTab:
        return const Center(child: Text('게시글 작성 화면'));
      case notificationsTab:
        return const Center(child: Text('활동 알림 화면'));
      case profileTab:
        return const Center(child: Text('프로필 화면'));
      default:
        return const FeedPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final int unread = context.watch<NotificationStore>().unreadCount;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xfff8faf8),
        centerTitle: false,
        elevation: 1.0,
        title: const AssenceLogo(height: 26),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              icon: const Icon(Icons.send),
              tooltip: 'AI 채팅',
              onPressed: () => openChat(context),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: List<Widget>.generate(5, _buildTab),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 1.0,
        padding: EdgeInsets.zero,
        height: 56.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _tabButton(feedTab, Icons.home, '홈'),
            _tabButton(searchTab, Icons.search, '검색'),
            _tabButton(composeTab, Icons.add_box, '게시물 작성'),
            _tabButton(notificationsTab, Icons.favorite, '알림', badge: unread),
            _tabButton(profileTab, Icons.account_box, '프로필'),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(int index, IconData icon, String label, {int badge = 0}) {
    final Widget iconWidget = Icon(
      icon,
      color: _currentIndex == index ? Colors.black : Colors.grey,
    );
    return IconButton(
      tooltip: label,
      icon: badge > 0
          ? Badge(label: Text('$badge'), child: iconWidget)
          : iconWidget,
      onPressed: () => _select(index),
    );
  }
}

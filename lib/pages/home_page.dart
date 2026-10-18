import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/app.dart';
import 'package:assence/navigation.dart';
import 'package:assence/pages/compose_page.dart';
import 'package:assence/pages/feed_page.dart';
import 'package:assence/pages/notifications_page.dart';
import 'package:assence/pages/profile_page.dart';
import 'package:assence/pages/search_page.dart';
import 'package:assence/pages/settings_page.dart';
import 'package:assence/state/chat_store.dart';
import 'package:assence/state/notification_store.dart';
import 'package:assence/state/user_profile_store.dart';
import 'package:assence/widgets/assence_logo.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const int feedTab = 0;
  static const int searchTab = 1;
  static const int composeTab = 2;
  static const int notificationsTab = 3;
  static const int profileTab = 4;

  int _currentIndex = feedTab;

  Timer? _scheduleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // AI 친구는 각자 게시 일정이 있다. 앱을 열 때, 다시 돌아올 때, 켜 둔 동안
    // 15분마다 예정 시각이 지난 친구가 있는지 확인한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSchedule();
      // 알림을 눌러 앱을 열었으면 그 화면으로 간다.
      final String? target = takePendingTarget();
      if (target != null && mounted) openTarget(context, target);
    });
    _scheduleTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _checkSchedule(),
    );
  }

  @override
  void dispose() {
    _scheduleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkSchedule();
  }

  /// 할 차례가 된 AI 친구 활동(게시물, 스토리, DM, 친구끼리 댓글)을 처리한다.
  /// 앱이 켜져 있을 때는 폰 알림 대신 뱃지로 보여준다.
  void _checkSchedule() {
    if (!mounted) return;
    context.read<AppStores>().runner.runDue();
  }

  void _select(int index) {
    // 알림 탭을 보고 나갈 때 읽음 처리한다. 보는 동안은 새 알림이 강조된 채로 남는다.
    if (_currentIndex == notificationsTab && index != notificationsTab) {
      context.read<NotificationStore>().markAllRead();
    }
    setState(() => _currentIndex = index);
  }

  Widget _buildTab(int index) {
    switch (index) {
      case searchTab:
        return const SearchPage();
      case composeTab:
        return ComposePage(onPosted: () => _select(feedTab));
      case notificationsTab:
        return const NotificationsPage();
      case profileTab:
        return const ProfilePage();
      default:
        return const FeedPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final int unread = context.watch<NotificationStore>().unreadCount;
    final bool onProfile = _currentIndex == profileTab;
    final int unreadDms = context.watch<ChatStore>().unreadCount;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xfff8faf8),
        centerTitle: false,
        elevation: 1.0,
        // 프로필 탭에서는 인스타그램처럼 내 계정명과 설정 버튼을 보여준다.
        title: onProfile
            ? Text(
                context.watch<UserProfileStore>().handle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : const AssenceLogo(height: 26),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: onProfile
                ? IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: '설정',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsPage(),
                      ),
                    ),
                  )
                : IconButton(
                    icon: Badge(
                      isLabelVisible: unreadDms > 0,
                      label: Text('$unreadDms'),
                      child: const Icon(Icons.send),
                    ),
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

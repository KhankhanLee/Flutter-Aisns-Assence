import 'dart:async';

import 'package:flutter/material.dart';
import 'package:assence/app.dart';
import 'package:assence/navigation.dart';
import 'package:assence/services/background.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final LocalStore local = await LocalStore.open();
  runApp(AssenceRoot(local: local, gemini: GeminiService.fromEnvironment()));
}

/// 앱 상태를 들고, 앱이 닫혀 있는 동안 백그라운드 작업이 바꾼 내용이 있으면
/// 다시 열릴 때 새로 읽어 온다. 알림을 눌렀을 때 화면 이동도 여기서 처리한다.
class AssenceRoot extends StatefulWidget {
  final LocalStore local;
  final GeminiService gemini;

  const AssenceRoot({super.key, required this.local, required this.gemini});

  @override
  State<AssenceRoot> createState() => _AssenceRootState();
}

class _AssenceRootState extends State<AssenceRoot> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late AppStores _stores;
  late int _revision;
  bool _reloaded = false;
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _revision = _readRevision();
    _stores = _createStores();
    _markForeground();
    // 화면에 떠 있는 동안은 백그라운드 작업이 끼어들지 않게 표시를 갱신한다.
    _presenceTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _markForeground(),
    );
    _setUpNotifications();
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  AppStores _createStores() {
    final AppStores stores = AppStores.create(widget.local, widget.gemini);
    stores.notificationSettings.addListener(_syncBackground);
    return stores;
  }

  int _readRevision() {
    final Object? revision = widget.local.readJson(
      BackgroundActivity.revisionKey,
    );
    return revision is int ? revision : 0;
  }

  void _markForeground() =>
      AppPresence.markForeground(widget.local, DateTime.now());

  Future<void> _setUpNotifications() async {
    try {
      await LocalNotifier.initialize(onTap: _openTarget);
      final String? launch = await LocalNotifier.launchPayload();
      if (launch != null) setPendingTarget(launch);
      await _syncBackground();
    } catch (_) {
      // 알림 플러그인이 없는 환경(테스트 등)에서는 알림 없이 동작한다.
    }
  }

  Future<void> _syncBackground() async {
    try {
      await BackgroundActivity.sync(
        enabled: _stores.notificationSettings.enabled,
      );
    } catch (_) {}
  }

  void _openTarget(String target) {
    final BuildContext? context = _navigatorKey.currentContext;
    if (context == null) {
      setPendingTarget(target);
    } else {
      openTarget(context, target);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _onResume();
      case AppLifecycleState.paused || AppLifecycleState.detached:
        AppPresence.markBackground(widget.local);
      default:
        break;
    }
  }

  /// 앱이 닫혀 있는 동안 백그라운드 작업이 돌았으면 저장된 내용을 새로 읽는다.
  Future<void> _onResume() async {
    await widget.local.reload();
    _markForeground();
    final int revision = _readRevision();
    if (revision == _revision || !mounted) return;
    _stores.notificationSettings.removeListener(_syncBackground);
    setState(() {
      _revision = revision;
      _reloaded = true;
      _stores = _createStores();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AssenceApp(
      key: ValueKey<int>(_revision),
      stores: _stores,
      navigatorKey: _navigatorKey,
      showSplash: !_reloaded,
    );
  }
}

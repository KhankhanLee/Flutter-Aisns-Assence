import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:assence/state/activity_runner.dart';

/// 폰 알림을 띄운다. 테스트에서는 가짜로 바꿔 끼운다.
abstract class Notifier {
  Future<void> show({
    required ActivityEvent event,
    required String personaName,
  });
}

/// 알림 제목과 본문.
({String title, String body}) notificationText(
  ActivityEvent event,
  String personaName,
) => switch (event.kind) {
  ActivityKind.dm => (title: personaName, body: event.text),
  ActivityKind.storyDm => (
    title: personaName,
    body: '회원님의 스토리에 답장: ${event.text}',
  ),
  ActivityKind.comment => (title: '$personaName님의 댓글', body: event.text),
  ActivityKind.newPost => (title: '$personaName님의 새 게시물', body: event.text),
  ActivityKind.friendStory => (
    title: '$personaName님이 스토리를 올렸어요',
    body: event.text,
  ),
};

/// flutter_local_notifications로 Android 알림을 띄운다.
class LocalNotifier implements Notifier {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _nextId = DateTime.now().millisecondsSinceEpoch % 100000;

  /// 알림을 눌렀을 때 [onTap]에 payload(`chat:<id>` / `post:<id>`)를 넘긴다.
  static Future<void> initialize({void Function(String payload)? onTap}) async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload;
        if (payload != null) onTap?.call(payload);
      },
    );
    _initialized = true;
  }

  /// 앱이 알림을 눌러서 열렸으면 그 payload.
  static Future<String?> launchPayload() async {
    final NotificationAppLaunchDetails? details = await _plugin
        .getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  /// Android 13 이상에서 알림 권한을 묻는다. 허용하면 true.
  static Future<bool> requestPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<void> show({
    required ActivityEvent event,
    required String personaName,
  }) async {
    await initialize();
    final bool isDm =
        event.kind == ActivityKind.dm || event.kind == ActivityKind.storyDm;
    final ({String title, String body}) text = notificationText(
      event,
      personaName,
    );
    await _plugin.show(
      id: _nextId++,
      title: text.title,
      body: text.body,
      payload: event.target,
      notificationDetails: NotificationDetails(
        android: isDm
            ? const AndroidNotificationDetails(
                'assence_dm',
                'DM',
                channelDescription: 'AI 친구가 보낸 메시지',
                importance: Importance.high,
                priority: Priority.high,
              )
            : const AndroidNotificationDetails(
                'assence_activity',
                '활동',
                channelDescription: '댓글, 새 게시물, 스토리',
              ),
      ),
    );
  }
}

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:assence/pages/home_page.dart';
import 'package:assence/pages/splash_page.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/services/post_image_source.dart';
import 'package:assence/state/activity_runner.dart';
import 'package:assence/state/ai_budget.dart';
import 'package:assence/state/ai_settings_store.dart';
import 'package:assence/state/chat_store.dart';
import 'package:assence/state/feed_store.dart';
import 'package:assence/state/notification_settings_store.dart';
import 'package:assence/state/notification_store.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/state/story_store.dart';
import 'package:assence/state/user_profile_store.dart';

/// 앱 전역 상태. 저장된 데이터는 생성 시점에 복원된다.
class AppStores {
  final LocalStore local;
  final GeminiService gemini;
  final PersonaStore personas;
  final NotificationStore notifications;
  final ChatStore chat;
  final FeedStore feed;
  final StoryStore stories;
  final UserProfileStore profile;
  final AiSettingsStore ai;
  final NotificationSettingsStore notificationSettings;

  /// AI 친구들이 알아서 하는 활동의 하루 요청 상한.
  final AiBudget budget;

  late final ActivityRunner runner = ActivityRunner(this);

  AppStores._({
    required this.local,
    required this.gemini,
    required this.personas,
    required this.notifications,
    required this.chat,
    required this.feed,
    required this.stories,
    required this.profile,
    required this.ai,
    required this.notificationSettings,
    required this.budget,
  });

  /// [now]·[random]은 테스트에서 시간과 확률을 고정할 때 쓴다.
  factory AppStores.create(
    LocalStore local,
    GeminiService gemini, {
    DateTime Function()? now,
    Random? random,
  }) {
    // 앱에 저장된 API 키·모델을 먼저 적용해야 다른 스토어가 바로 쓸 수 있다.
    final AiSettingsStore ai = AiSettingsStore(local, gemini);
    final PersonaStore personas = PersonaStore(local);
    final NotificationStore notifications = NotificationStore(local);
    return AppStores._(
      local: local,
      gemini: gemini,
      personas: personas,
      notifications: notifications,
      chat: ChatStore(local, gemini, personas, now: now, random: random),
      feed: FeedStore(
        local,
        gemini,
        personas,
        notifications,
        imageSource: GeminiPostImageSource(
          gemini,
          enabled: () => ai.imageGeneration,
        ),
        now: now,
        random: random,
      ),
      stories: StoryStore(local, now: now, random: random),
      profile: UserProfileStore(local),
      ai: ai,
      notificationSettings: NotificationSettingsStore(local),
      budget: AiBudget(local, now: now),
    );
  }
}

class AssenceApp extends StatelessWidget {
  final AppStores stores;

  /// 처음에 로고 시작 화면을 보여줄지 여부. 테스트에서는 바로 홈으로 간다.
  final bool showSplash;

  /// 알림을 눌렀을 때 화면을 옮기는 데 쓴다.
  final GlobalKey<NavigatorState>? navigatorKey;

  const AssenceApp({
    super.key,
    required this.stores,
    this.showSplash = true,
    this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<AppStores>.value(value: stores),
        ChangeNotifierProvider<PersonaStore>.value(value: stores.personas),
        ChangeNotifierProvider<NotificationStore>.value(
          value: stores.notifications,
        ),
        ChangeNotifierProvider<ChatStore>.value(value: stores.chat),
        ChangeNotifierProvider<FeedStore>.value(value: stores.feed),
        ChangeNotifierProvider<StoryStore>.value(value: stores.stories),
        ChangeNotifierProvider<UserProfileStore>.value(value: stores.profile),
        ChangeNotifierProvider<AiSettingsStore>.value(value: stores.ai),
        ChangeNotifierProvider<NotificationSettingsStore>.value(
          value: stores.notificationSettings,
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Assence',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.black,
            primary: Colors.black,
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0.5,
          ),
          primaryTextTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.black, fontFamily: 'Aveny'),
          ),
        ),
        home: showSplash ? const SplashPage() : const HomePage(),
      ),
    );
  }
}

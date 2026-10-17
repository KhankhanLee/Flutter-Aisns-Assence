import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/pages/home_page.dart';
import 'package:assence/pages/splash_page.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/state/chat_store.dart';
import 'package:assence/state/feed_store.dart';
import 'package:assence/state/notification_store.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/state/story_store.dart';
import 'package:assence/state/user_profile_store.dart';

/// 앱 전역 상태. 저장된 데이터는 생성 시점에 복원된다.
class AppStores {
  final PersonaStore personas;
  final NotificationStore notifications;
  final ChatStore chat;
  final FeedStore feed;
  final StoryStore stories;
  final UserProfileStore profile;

  AppStores._(
    this.personas,
    this.notifications,
    this.chat,
    this.feed,
    this.stories,
    this.profile,
  );

  factory AppStores.create(LocalStore local, GeminiService gemini) {
    final PersonaStore personas = PersonaStore(local);
    final NotificationStore notifications = NotificationStore(local);
    return AppStores._(
      personas,
      notifications,
      ChatStore(local, gemini, personas),
      FeedStore(local, gemini, personas, notifications),
      StoryStore(local),
      UserProfileStore(local),
    );
  }
}

class AssenceApp extends StatelessWidget {
  final AppStores stores;

  /// 처음에 로고 시작 화면을 보여줄지 여부. 테스트에서는 바로 홈으로 간다.
  final bool showSplash;

  const AssenceApp({super.key, required this.stores, this.showSplash = true});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <ChangeNotifierProvider<ChangeNotifier>>[
        ChangeNotifierProvider<PersonaStore>.value(value: stores.personas),
        ChangeNotifierProvider<NotificationStore>.value(
          value: stores.notifications,
        ),
        ChangeNotifierProvider<ChatStore>.value(value: stores.chat),
        ChangeNotifierProvider<FeedStore>.value(value: stores.feed),
        ChangeNotifierProvider<StoryStore>.value(value: stores.stories),
        ChangeNotifierProvider<UserProfileStore>.value(value: stores.profile),
      ],
      child: MaterialApp(
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/pages/profile_edit_page.dart';
import 'package:assence/pages/api_key_page.dart';
import 'package:assence/data/seed_data.dart';
import 'package:assence/models/post.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/notification_service.dart';
import 'package:assence/state/ai_settings_store.dart';
import 'package:assence/state/feed_store.dart';
import 'package:assence/state/notification_settings_store.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/state/post_schedule.dart';
import 'package:assence/utils/format.dart';
import 'package:assence/widgets/author_avatar.dart';
import 'package:assence/state/user_profile_store.dart';
import 'package:assence/widgets/assence_logo.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final UserProfileStore profile = context.watch<UserProfileStore>();
    final AiSettingsStore ai = context.watch<AiSettingsStore>();
    final FeedStore feed = context.watch<FeedStore>();
    final PersonaStore personas = context.watch<PersonaStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: <Widget>[
          const _SectionTitle('계정'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('프로필 편집'),
            subtitle: Text('@${profile.handle} · ${profile.name}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ProfileEditPage()),
            ),
          ),
          const _SectionTitle('AI'),
          ListTile(
            leading: Icon(
              ai.isConfigured ? Icons.check_circle_outline : Icons.key_outlined,
              color: ai.isConfigured ? Colors.green : Colors.orange,
            ),
            title: const Text('AI 연결 (Gemini / Claude)'),
            subtitle: Text(
              !ai.isConfigured
                  ? '미설정 · 눌러서 키를 입력하면 AI 답글·DM·게시물이 켜져요'
                  : ai.fallbackModel != null
                  ? '${_providerName(ai.provider)} 연결됨 · 기본 모델 사용량 초과로 '
                        '${ai.fallbackModel} 사용 중'
                  : '${_providerName(ai.provider)} 연결됨 · ${ai.maskedKey} · ${ai.model}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const ApiKeyPage())),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome_outlined),
            title: const Text('AI 친구가 사진도 직접 만들기'),
            subtitle: const Text(
              '새 게시물마다 Gemini로 프로필 속 인물의 새 사진을 만들어요. '
              'Gemini 키가 있어야 하고, 이미지 모델은 유료일 수 있어요. '
              '끄거나 실패하면 기존 사진 중에서 골라요.',
            ),
            value: ai.imageGeneration,
            onChanged: ai.hasKey(AiProvider.gemini)
                ? (bool value) => ai.imageGeneration = value
                : null,
          ),
          const _SectionTitle('알림'),
          const _NotificationSettings(),
          const _SectionTitle('AI 친구 게시 일정'),
          for (final MapEntry<String, PostingHabit> habit
              in personaHabits.entries)
            ListTile(
              dense: true,
              leading: AuthorAvatar(authorId: habit.key, radius: 16),
              title: Text(
                '${personas.byId(habit.key)?.name ?? habit.key} · '
                '일주일에 ${habit.value.postsPerWeek.round()}번쯤',
              ),
              subtitle: Text(
                feed.nextPostTimes[habit.key] == null
                    ? '-'
                    : '다음 게시: ${formatTimeUntil(feed.nextPostTimes[habit.key]!)}',
              ),
            ),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('지금 AI 게시물 하나 올려보기 (테스트)'),
            subtitle: const Text('일정과 상관없이 AI 친구 한 명이 바로 올려요'),
            enabled: ai.isConfigured && !feed.isCreatingPost,
            onTap: () async {
              final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                context,
              );
              try {
                final Post? post = await feed.createPersonaPost();
                if (post != null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('새 게시물이 올라왔어요. 홈 피드를 확인해 보세요!'),
                    ),
                  );
                }
              } on GeminiException catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(e.userMessage)));
              }
            },
          ),
          const _SectionTitle('정보'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Assence 정보'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Assence',
              applicationIcon: const AssenceMark(size: 48),
              children: const <Widget>[Text('AI 페르소나와 소통하는 SNS 프로토타입')],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
      ),
    );
  }
}

String _providerName(AiProvider provider) => switch (provider) {
  AiProvider.gemini => 'Gemini',
  AiProvider.claude => 'Claude',
};

/// 앱을 닫아 둬도 AI 친구 소식을 폰 알림으로 받는 설정.
class _NotificationSettings extends StatelessWidget {
  const _NotificationSettings();

  Future<void> _toggleAll(BuildContext context, bool value) async {
    final NotificationSettingsStore settings = context
        .read<NotificationSettingsStore>();
    if (value) {
      bool granted = true;
      try {
        granted = await LocalNotifier.requestPermission();
      } catch (_) {
        // 알림 플러그인이 없는 환경(테스트 등)
      }
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('알림 권한이 꺼져 있어요. 폰 설정 > 앱 > Assence에서 알림을 허용해 주세요.'),
            ),
          );
        }
        return;
      }
    }
    settings.update(enabled: value);
  }

  @override
  Widget build(BuildContext context) {
    final NotificationSettingsStore settings = context
        .watch<NotificationSettingsStore>();
    final bool on = settings.enabled;
    return Column(
      children: <Widget>[
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('폰 알림 받기'),
          subtitle: const Text(
            '앱을 닫아 둬도 1시간쯤마다 AI 친구 소식을 확인해서 알려줘요. '
            '배터리 절약 모드에서는 늦게 올 수 있어요.',
          ),
          value: on,
          onChanged: (bool value) => _toggleAll(context, value),
        ),
        SwitchListTile(
          title: const Text('새 DM'),
          value: settings.dm,
          onChanged: on ? (bool v) => settings.update(dm: v) : null,
          dense: true,
        ),
        SwitchListTile(
          title: const Text('댓글·새 게시물'),
          value: settings.activity,
          onChanged: on ? (bool v) => settings.update(activity: v) : null,
          dense: true,
        ),
        SwitchListTile(
          title: const Text('친구 새 스토리'),
          value: settings.stories,
          onChanged: on ? (bool v) => settings.update(stories: v) : null,
          dense: true,
        ),
      ],
    );
  }
}

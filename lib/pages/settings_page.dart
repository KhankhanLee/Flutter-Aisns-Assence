import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/pages/profile_edit_page.dart';
import 'package:assence/state/chat_store.dart';
import 'package:assence/state/user_profile_store.dart';
import 'package:assence/widgets/assence_logo.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final UserProfileStore profile = context.watch<UserProfileStore>();
    final bool aiReady = context.watch<ChatStore>().isConfigured;

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
              aiReady ? Icons.check_circle_outline : Icons.error_outline,
              color: aiReady ? Colors.green : Colors.orange,
            ),
            title: const Text('Gemini 연결 상태'),
            subtitle: Text(
              aiReady
                  ? '연결됨 · AI 답글과 DM을 사용할 수 있어요'
                  : 'API 키 미설정 · --dart-define=GEMINI_API_KEY=<키> 로 빌드해 주세요',
            ),
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

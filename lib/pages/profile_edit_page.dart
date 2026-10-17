import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/state/user_profile_store.dart';
import 'package:assence/widgets/author_avatar.dart';

/// 이름·사용자 이름(닉네임)·소개를 수정한다.
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final UserProfileStore _profile = context.read<UserProfileStore>();
  late final TextEditingController _name = TextEditingController(
    text: _profile.name,
  );
  late final TextEditingController _handle = TextEditingController(
    text: _profile.handle,
  );
  late final TextEditingController _bio = TextEditingController(
    text: _profile.bio,
  );
  String? _handleError;

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _save() {
    final String handle = _handle.text.trim().toLowerCase();
    final Iterable<String> taken = context.read<PersonaStore>().all.map(
      (Persona p) => p.handle.toLowerCase(),
    );
    final String? error = UserProfileStore.validateHandle(handle, taken);
    if (error != null) {
      setState(() => _handleError = error);
      return;
    }
    _profile.update(handle: handle, name: _name.text, bio: _bio.text);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('프로필을 저장했어요.')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 편집'),
        actions: <Widget>[
          TextButton(onPressed: _save, child: const Text('완료')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Center(child: AuthorAvatar(authorId: myUserId, radius: 44)),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            maxLength: 30,
            decoration: const InputDecoration(
              labelText: '이름',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _handle,
            maxLength: UserProfileStore.maxHandleLength,
            autocorrect: false,
            onChanged: (_) {
              if (_handleError != null) setState(() => _handleError = null);
            },
            decoration: InputDecoration(
              labelText: '사용자 이름',
              helperText: '영문 소문자, 숫자, 마침표(.), 밑줄(_)',
              errorText: _handleError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bio,
            maxLength: 150,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '소개',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

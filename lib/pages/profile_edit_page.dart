import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/services/media_storage.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/state/user_profile_store.dart';
import 'package:assence/widgets/author_avatar.dart';

/// 프로필 사진·이름·사용자 이름(닉네임)·소개를 수정한다.
class ProfileEditPage extends StatefulWidget {
  /// 사진 고르기. 테스트에서 바꿔 끼운다.
  final PhotoPicker? pickPhoto;

  const ProfileEditPage({super.key, this.pickPhoto});

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

  /// 사진 변경: 갤러리·카메라에서 고르거나, 지금 사진을 지운다. 바로 저장된다.
  Future<void> _changePhoto() async {
    final bool hasPhoto = _profile.avatarPath != null;
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라로 찍기'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('사진 삭제', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final String? previous = _profile.avatarPath;
    if (choice == 'delete') {
      _profile.setAvatar(null);
      await deleteKeptPhoto(previous);
      return;
    }
    final PhotoPicker pick =
        widget.pickPhoto ?? devicePhotoPicker(folder: 'avatars', maxWidth: 800);
    try {
      final String? path = await pick(
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
      if (path == null) return;
      _profile.setAvatar(path);
      if (previous != path) await deleteKeptPhoto(previous);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 가져오지 못했어요. 권한을 확인해 주세요.')),
      );
    }
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
          Center(
            child: GestureDetector(
              onTap: _changePhoto,
              child: const AuthorAvatar(authorId: myUserId, radius: 44),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: _changePhoto,
              child: const Text('사진 변경'),
            ),
          ),
          const SizedBox(height: 8),
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

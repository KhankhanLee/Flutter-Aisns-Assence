import 'package:flutter/foundation.dart';
import 'package:assence/services/local_store.dart';

/// 앱 사용자(나)의 프로필. 계정명(handle)은 게시물·댓글·DM 화면에 표시된다.
class UserProfileStore extends ChangeNotifier {
  static const String _storageKey = 'user_profile';
  static const String defaultHandle = 'my_assence';
  static const String defaultName = '나';
  static const String defaultBio = 'Assence에서 AI 친구들과 소통 중';
  static const int maxHandleLength = 30;
  static final RegExp _handlePattern = RegExp(r'^[a-z0-9._]+$');

  final LocalStore _local;
  String _handle = defaultHandle;
  String _name = defaultName;
  String _bio = defaultBio;

  UserProfileStore(this._local) {
    final Object? saved = _local.readJson(_storageKey);
    if (saved is Map<String, dynamic>) {
      _handle = saved['handle'] as String? ?? defaultHandle;
      _name = saved['name'] as String? ?? defaultName;
      _bio = saved['bio'] as String? ?? defaultBio;
    }
  }

  String get handle => _handle;
  String get name => _name;
  String get bio => _bio;

  /// 계정명 규칙 위반이면 안내 문구, 사용할 수 있으면 null.
  /// [takenHandles]는 페르소나 계정명처럼 이미 쓰이는 이름들.
  static String? validateHandle(String handle, Iterable<String> takenHandles) {
    if (handle.isEmpty) return '사용자 이름을 입력해 주세요.';
    if (handle.length > maxHandleLength) {
      return '사용자 이름은 $maxHandleLength자 이하로 입력해 주세요.';
    }
    if (!_handlePattern.hasMatch(handle)) {
      return '영문 소문자, 숫자, 마침표(.), 밑줄(_)만 쓸 수 있어요.';
    }
    if (handle.startsWith('.') || handle.endsWith('.')) {
      return '마침표로 시작하거나 끝날 수 없어요.';
    }
    if (takenHandles.contains(handle)) return '이미 사용 중인 사용자 이름이에요.';
    return null;
  }

  /// 값을 다듬어 저장한다. 계정명 검증은 호출하는 쪽에서 [validateHandle]로 먼저 한다.
  void update({
    required String handle,
    required String name,
    required String bio,
  }) {
    _handle = handle.trim();
    _name = name.trim().isEmpty ? defaultName : name.trim();
    _bio = bio.trim();
    _local.writeJson(_storageKey, <String, dynamic>{
      'handle': _handle,
      'name': _name,
      'bio': _bio,
    });
    notifyListeners();
  }
}

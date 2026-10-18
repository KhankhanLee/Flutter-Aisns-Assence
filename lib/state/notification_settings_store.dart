import 'package:flutter/foundation.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/state/activity_runner.dart';

/// 폰 알림 설정. 앱이 닫혀 있을 때 백그라운드 작업도 이 값을 읽는다.
class NotificationSettingsStore extends ChangeNotifier {
  static const String _storageKey = 'notification_settings';

  final LocalStore _local;

  /// 폰 알림 전체. 처음 켤 때 알림 권한을 요청하므로 기본은 꺼짐.
  bool _enabled = false;

  /// 새 DM (먼저 보낸 DM, 스토리 보고 보낸 DM).
  bool _dm = true;

  /// 내 댓글·게시물에 단 댓글, 새 게시물.
  bool _activity = true;

  /// 친구 새 스토리. 자주 오므로 기본은 꺼짐.
  bool _stories = false;

  NotificationSettingsStore(this._local) {
    final Object? saved = _local.readJson(_storageKey);
    if (saved is Map<String, dynamic>) {
      _enabled = saved['enabled'] as bool? ?? _enabled;
      _dm = saved['dm'] as bool? ?? _dm;
      _activity = saved['activity'] as bool? ?? _activity;
      _stories = saved['stories'] as bool? ?? _stories;
    }
  }

  bool get enabled => _enabled;
  bool get dm => _dm;
  bool get activity => _activity;
  bool get stories => _stories;

  /// [kind] 활동을 폰 알림으로 보여줄지.
  bool allows(ActivityKind kind) {
    if (!_enabled) return false;
    return switch (kind) {
      ActivityKind.dm || ActivityKind.storyDm => _dm,
      ActivityKind.comment || ActivityKind.newPost => _activity,
      ActivityKind.friendStory => _stories,
    };
  }

  void update({bool? enabled, bool? dm, bool? activity, bool? stories}) {
    _enabled = enabled ?? _enabled;
    _dm = dm ?? _dm;
    _activity = activity ?? _activity;
    _stories = stories ?? _stories;
    _local.writeJson(_storageKey, <String, bool>{
      'enabled': _enabled,
      'dm': _dm,
      'activity': _activity,
      'stories': _stories,
    });
    notifyListeners();
  }
}

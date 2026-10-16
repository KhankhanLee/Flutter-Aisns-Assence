import 'package:flutter/foundation.dart';
import 'package:assence/models/app_notification.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/utils/format.dart';

class NotificationStore extends ChangeNotifier {
  static const String _storageKey = 'notifications';
  static const int _maxCount = 100;

  final LocalStore _local;
  final List<AppNotification> _items = <AppNotification>[]; // 최신순

  NotificationStore(this._local) {
    final Object? saved = _local.readJson(_storageKey);
    if (saved is List<dynamic>) {
      _items.addAll(saved.map((dynamic json) =>
          AppNotification.fromJson(json as Map<String, dynamic>)));
    }
  }

  List<AppNotification> get items => List<AppNotification>.unmodifiable(_items);

  int get unreadCount => _items.where((AppNotification n) => !n.read).length;

  void add({
    required NotificationType type,
    required String personaId,
    required String postId,
    required String text,
  }) {
    _items.insert(
      0,
      AppNotification(
        id: newId('noti'),
        type: type,
        personaId: personaId,
        postId: postId,
        text: text,
        createdAt: DateTime.now(),
      ),
    );
    if (_items.length > _maxCount) _items.removeRange(_maxCount, _items.length);
    _save();
    notifyListeners();
  }

  void markAllRead() {
    if (unreadCount == 0) return;
    for (final AppNotification n in _items) {
      n.read = true;
    }
    _save();
    notifyListeners();
  }

  Future<void> _save() => _local.writeJson(
      _storageKey, _items.map((AppNotification n) => n.toJson()).toList());
}

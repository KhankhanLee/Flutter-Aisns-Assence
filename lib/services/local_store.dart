import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// shared_preferences에 JSON으로 저장하는 얇은 래퍼.
class LocalStore {
  final SharedPreferences _prefs;

  LocalStore(this._prefs);

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  /// 저장된 값이 없거나 손상됐으면 null.
  Object? readJson(String key) {
    final String? raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  /// 다른 isolate(백그라운드 작업)가 바꾼 값을 다시 읽어 온다.
  Future<void> reload() => _prefs.reload();

  Future<void> writeJson(String key, Object? value) =>
      _prefs.setString(key, jsonEncode(value));
}

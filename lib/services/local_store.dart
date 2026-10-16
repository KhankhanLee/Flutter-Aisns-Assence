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

  Future<void> writeJson(String key, Object? value) =>
      _prefs.setString(key, jsonEncode(value));
}

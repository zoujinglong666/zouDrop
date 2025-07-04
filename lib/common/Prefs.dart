import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> set(String key, dynamic value, {int? expireInSeconds}) async {
    if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is List<String>) {
      await _prefs.setStringList(key, value);
    } else {
      // ✅ 自动转 JSON 字符串保存
      final jsonStr = jsonEncode(value);
      await _prefs.setString(key, jsonStr);
    }

    if (expireInSeconds != null) {
      final expiresAt = DateTime.now().add(Duration(seconds: expireInSeconds));
      await _prefs.setString('${key}__expires', expiresAt.toIso8601String());
    }
  }

  static dynamic get(String key) {
    final expireStr = _prefs.getString('${key}__expires');
    if (expireStr != null) {
      final expiresAt = DateTime.tryParse(expireStr);
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        remove(key);
        return null;
      }
    }

    final raw = _prefs.get(key);

    // ✅ 若是 String 且可能为 JSON，则尝试解析
    if (raw is String && (raw.startsWith("{") || raw.startsWith("["))) {
      try {
        return jsonDecode(raw);
      } catch (_) {
        return raw;
      }
    }

    return raw;
  }

  static bool contains(String key) {
    final expireStr = _prefs.getString('${key}__expires');
    if (expireStr != null) {
      final expiresAt = DateTime.tryParse(expireStr);
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        remove(key);
        return false;
      }
    }
    return _prefs.containsKey(key);
  }

  static Future<void> remove(String key) async {
    await _prefs.remove(key);
    await _prefs.remove('${key}__expires');
  }

  static Future<void> clear() async {
    await _prefs.clear();
  }

  /// ✅ 可选扩展：明确的 JSON 保存方法
  static Future<void> setJson(String key, Object value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  static dynamic getJson(String key) {
    final str = _prefs.getString(key);
    if (str == null) return null;
    return jsonDecode(str);
  }
}

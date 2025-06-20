import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static late SharedPreferences _prefs;

  /// 初始化（在 app 启动时调用）
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 设置值，可选传入过期时间（单位：秒）
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
      throw Exception("不支持的类型: ${value.runtimeType}");
    }

    // 保存过期时间戳
    if (expireInSeconds != null) {
      final expiresAt = DateTime.now().add(Duration(seconds: expireInSeconds));
      await _prefs.setString('${key}__expires', expiresAt.toIso8601String());
    }
  }

  /// 获取值，自动判断是否过期（过期返回 null 并删除 key）
  static dynamic get(String key) {
    final expireStr = _prefs.getString('${key}__expires');
    if (expireStr != null) {
      final expiresAt = DateTime.tryParse(expireStr);
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        remove(key);
        return null;
      }
    }
    return _prefs.get(key);
  }

  /// 是否包含有效值（未过期）
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

  /// 删除值（包括过期时间）
  static Future<void> remove(String key) async {
    await _prefs.remove(key);
    await _prefs.remove('${key}__expires');
  }

  /// 清空所有（包括所有过期信息）
  static Future<void> clear() async {
    await _prefs.clear();
  }
}

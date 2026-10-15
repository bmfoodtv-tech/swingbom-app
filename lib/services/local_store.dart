/// 로컬 키-값 저장 (가이드 캐시 등)
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
///
/// 키에는 반드시 swb_ 구분자를 붙인다 (SwingGuide.key 참조).
library;

import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static Future<void> write(String key, String value) async {
    final p = await SharedPreferences.getInstance();
    if (value.isEmpty) {
      await p.remove(key);
    } else {
      await p.setString(key, value);
    }
  }

  static Future<String?> read(String key) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(key);
  }

  static Future<void> remove(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(key);
  }
}

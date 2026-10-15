/// 토큰 영속 저장 · 자동 로그인 · 회원 세션
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/entitlement.dart';
import '../models/member.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  // 충돌 방지 구분자 적용 키
  static const _kToken = 'swb_token';
  static const _kMember = 'swb_member';

  static const _secure = FlutterSecureStorage();

  Member? _member;
  Member? get member => _member;
  bool get isLoggedIn => _member != null;

  /// 이용권 상태 — 로그인·자동로그인·구독화면에서 갱신된다
  Entitlement _entitlement = Entitlement.none;
  Entitlement get entitlement => _entitlement;
  bool get hasAccess => _entitlement.active;

  void setEntitlement(Entitlement e) {
    _entitlement = e;
    notifyListeners();
  }

  // ── 저장소 헬퍼 (보안저장소 실패 시 SharedPreferences 폴백) ──────────
  Future<void> _write(String key, String value) async {
    try {
      await _secure.write(key: key, value: value);
      return;
    } catch (_) {/* 폴백 */}
    final p = await SharedPreferences.getInstance();
    await p.setString(key, value);
  }

  Future<String?> _read(String key) async {
    try {
      final v = await _secure.read(key: key);
      if (v != null) return v;
    } catch (_) {/* 폴백 */}
    final p = await SharedPreferences.getInstance();
    return p.getString(key);
  }

  Future<void> _delete(String key) async {
    try {
      await _secure.delete(key: key);
    } catch (_) {/* 무시 */}
    final p = await SharedPreferences.getInstance();
    await p.remove(key);
  }

  // ── 자동 로그인 ────────────────────────────────────────────────
  /// 저장된 토큰을 불러와 서버에서 유효성 검사한다.
  /// 유효하면 true (→ 대시보드), 아니면 false (→ 로그인 화면).
  Future<bool> tryAutoLogin() async {
    final token = await _read(_kToken);
    if (token == null || token.isEmpty) return false;

    ApiService.token = token;

    // 캐시된 회원 정보로 먼저 화면을 띄울 수 있게 준비
    final cached = await _read(_kMember);
    if (cached != null) {
      try {
        _member = Member.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {/* 무시 */}
    }

    final res = await ApiService.get(ApiConfig.me);
    if (res.success && res.data['member'] != null) {
      _member = Member.fromJson(res.data['member'] as Map<String, dynamic>);
      if (res.data['entitlement'] != null) {
        _entitlement = Entitlement.fromJson(
            res.data['entitlement'] as Map<String, dynamic>);
      }
      await _write(_kMember, jsonEncode(_member!.toJson()));
      notifyListeners();
      return true;
    }

    // 토큰 만료·폐기 → 정리
    if (res.isAuthError) {
      await _clear();
      return false;
    }

    // 네트워크 장애: 캐시가 있으면 오프라인 진입 허용
    if (_member != null) {
      notifyListeners();
      return true;
    }
    return false;
  }

  // ── 로그인 / 회원가입 / 로그아웃 ──────────────────────────────────
  Future<ApiResult> login(String username, String password) async {
    final res = await ApiService.post(ApiConfig.login,
        body: {'username': username, 'password': password});
    if (res.success) await _applyLogin(res);
    return res;
  }

  /// 로그인 성공 응답(token + member + entitlement)을 저장한다.
  /// 아이디 로그인과 네이버 로그인이 같은 형식을 쓰므로 한 곳에서 처리한다.
  Future<void> _applyLogin(ApiResult res) async {
    final token = res.data['token'] as String;
    ApiService.token = token;
    await _write(_kToken, token);

    _member = Member.fromJson(res.data['member'] as Map<String, dynamic>);
    if (res.data['entitlement'] != null) {
      _entitlement =
          Entitlement.fromJson(res.data['entitlement'] as Map<String, dynamic>);
    }
    await _write(_kMember, jsonEncode(_member!.toJson()));
    notifyListeners();
  }

  Future<ApiResult> register({
    required String username,
    required String password,
    String? name,
    String? email,
  }) {
    return ApiService.post(ApiConfig.register, body: {
      'username': username,
      'password': password,
      if (name != null && name.isNotEmpty) 'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
    });
  }

  /// 네이버 로그인 마무리 — 웹뷰가 받아온 1회용 코드를 토큰으로 교환한다.
  Future<ApiResult> completeNaverLogin(String handoffCode) async {
    final res = await ApiService.post(ApiConfig.naverExchange,
        body: {'code': handoffCode});
    if (res.success && res.data['token'] != null) {
      await _applyLogin(res);
    }
    return res;
  }

  /// 회원 탈퇴 — 서버에서 계정과 데이터를 삭제하고 로컬 정보도 지운다.
  /// 본인 확인을 위해 비밀번호를 다시 받는다.
  Future<ApiResult> deleteAccount(String password) async {
    final res = await ApiService.post(ApiConfig.accountDelete,
        body: {'password': password});
    if (res.success) await _clear();
    return res;
  }

  Future<void> logout() async {
    if (ApiService.token != null) {
      await ApiService.post(ApiConfig.logout);
    }
    await _clear();
  }

  Future<void> _clear() async {
    ApiService.token = null;
    _member = null;
    _entitlement = Entitlement.none;
    await _delete(_kToken);
    await _delete(_kMember);
    notifyListeners();
  }
}

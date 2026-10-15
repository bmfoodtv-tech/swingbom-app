/// 스윙봄 서버 통신
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
///
/// 중요: 닷홈(PHP-CGI) 환경에서는 4xx 상태코드를 내면 Apache가 응답 본문을
/// HTML 에러페이지로 대체해 버린다. 그래서 서버는 항상 HTTP 200으로 응답하고
/// 실제 결과는 JSON의 success / code 필드로 전달한다.
/// 따라서 클라이언트는 statusCode가 아니라 success/code 로 분기한다.
library;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiResult {
  final bool success;
  final int code;
  final String message;
  final Map<String, dynamic> data;

  const ApiResult({
    required this.success,
    required this.code,
    required this.message,
    this.data = const {},
  });

  bool get isAuthError => code == 401;

  factory ApiResult.error(String message, {int code = 0}) =>
      ApiResult(success: false, code: code, message: message);
}

class ApiService {
  /// 로그인 토큰 (AuthService가 주입)
  static String? token;

  static Map<String, String> _headers({bool json = false}) {
    final h = <String, String>{'Accept': 'application/json'};
    if (json) h['Content-Type'] = 'application/json; charset=utf-8';
    final t = token;
    if (t != null && t.isNotEmpty) h[ApiConfig.tokenHeader] = t;
    return h;
  }

  static ApiResult _parse(http.Response res) {
    // 서버는 항상 200을 주지만, 호스팅 장애 등으로 HTML이 올 수 있어 방어한다.
    late final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return ApiResult.error(
        '서버 응답을 해석할 수 없습니다. (HTTP ${res.statusCode})',
        code: res.statusCode,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      return ApiResult.error('서버 응답 형식이 올바르지 않습니다.');
    }
    return ApiResult(
      success: decoded['success'] == true,
      code: (decoded['code'] as num?)?.toInt() ?? res.statusCode,
      message: (decoded['message'] as String?) ?? '',
      data: (decoded['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  static Future<ApiResult> _send(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    var uri = Uri.parse(ApiConfig.baseUrl + path);
    if (query != null && query.isNotEmpty) uri = uri.replace(queryParameters: query);

    try {
      final res = method == 'POST'
          ? await http
              .post(uri, headers: _headers(json: true), body: jsonEncode(body ?? {}))
              .timeout(ApiConfig.timeout)
          : await http.get(uri, headers: _headers()).timeout(ApiConfig.timeout);
      return _parse(res);
    } on TimeoutException {
      return ApiResult.error('서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해 주세요.');
    } catch (e) {
      return ApiResult.error('네트워크 연결을 확인해 주세요.');
    }
  }

  static Future<ApiResult> get(String path, {Map<String, String>? query}) =>
      _send(path, query: query);

  static Future<ApiResult> post(String path, {Map<String, dynamic>? body}) =>
      _send(path, method: 'POST', body: body);
}

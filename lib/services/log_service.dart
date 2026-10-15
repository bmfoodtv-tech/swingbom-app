/// 연습일지 서버 통신
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import '../config/api_config.dart';
import '../models/practice_log.dart';
import 'api_service.dart';

class LogService {
  /// 목록 + 요약 통계
  static Future<(PracticeLogPage?, ApiResult)> list({
    String? from,
    String? to,
    int? limit,
  }) async {
    final q = <String, String>{};
    if (from != null) q['from'] = from;
    if (to != null) q['to'] = to;
    if (limit != null) q['limit'] = '$limit';

    final res = await ApiService.get(ApiConfig.practiceLogList, query: q);
    if (!res.success) return (null, res);

    final raw = (res.data['logs'] as List? ?? const []);
    final page = PracticeLogPage(
      logs: raw
          .map((e) => PracticeLog.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      totalSwings: (res.data['total_swings'] as num?)?.toInt() ?? 0,
      totalDays: (res.data['total_days'] as num?)?.toInt() ?? 0,
      summary: LogSummary.fromJson(
          (res.data['summary'] as Map<String, dynamic>?) ?? const {}),
    );
    return (page, res);
  }

  /// 등록(id 없음) / 수정(id 있음)
  static Future<ApiResult> save({
    int? id,
    required String practiceDate,
    String? location,
    int swingCount = 0,
    String? notes,
  }) {
    return ApiService.post(ApiConfig.practiceLogSave, body: {
      if (id != null && id > 0) 'id': id,
      'practice_date': practiceDate,
      'location': location ?? '',
      'swing_count': swingCount,
      'notes': notes ?? '',
    });
  }

  static Future<ApiResult> delete(int id) =>
      ApiService.post(ApiConfig.practiceLogDelete, body: {'id': id});

  /// 스윙 자동 누적 — 연습 화면에서 한 번 촬영할 때마다 호출한다.
  /// 해당 날짜 일지가 없으면 서버가 새로 만든다.
  static Future<ApiResult> bump({int count = 1, String? location}) =>
      ApiService.post(ApiConfig.practiceLogBump, body: {
        'count': count,
        if (location != null && location.isNotEmpty) 'location': location,
      });

  /// 특정 날짜의 연습일지 1건 (없으면 null)
  static Future<PracticeLog?> byDate(String date) async {
    final (page, _) = await list(from: date, to: date, limit: 1);
    if (page == null || page.logs.isEmpty) return null;
    return page.logs.first;
  }
}

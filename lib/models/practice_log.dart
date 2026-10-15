/// 연습일지 모델
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
class PracticeLog {
  final int id;
  final String practiceDate; // YYYY-MM-DD
  final String? location;
  final int swingCount;
  final String? notes;

  const PracticeLog({
    required this.id,
    required this.practiceDate,
    this.location,
    this.swingCount = 0,
    this.notes,
  });

  factory PracticeLog.fromJson(Map<String, dynamic> j) => PracticeLog(
        id: (j['id'] as num).toInt(),
        practiceDate: j['practice_date'] as String,
        location: j['location'] as String?,
        swingCount: (j['swing_count'] as num?)?.toInt() ?? 0,
        notes: j['notes'] as String?,
      );
}

/// 대시보드 요약 통계
class LogSummary {
  final int monthSwings;
  final int monthDays;
  final int totalSwings;
  final int totalDays;
  final String? lastDate;

  const LogSummary({
    this.monthSwings = 0,
    this.monthDays = 0,
    this.totalSwings = 0,
    this.totalDays = 0,
    this.lastDate,
  });

  factory LogSummary.fromJson(Map<String, dynamic> j) => LogSummary(
        monthSwings: (j['month_swings'] as num?)?.toInt() ?? 0,
        monthDays: (j['month_days'] as num?)?.toInt() ?? 0,
        totalSwings: (j['total_swings'] as num?)?.toInt() ?? 0,
        totalDays: (j['total_days'] as num?)?.toInt() ?? 0,
        lastDate: j['last_date'] as String?,
      );
}

/// 목록 조회 결과
class PracticeLogPage {
  final List<PracticeLog> logs;
  final int totalSwings;
  final int totalDays;
  final LogSummary summary;

  const PracticeLogPage({
    required this.logs,
    required this.totalSwings,
    required this.totalDays,
    required this.summary,
  });
}

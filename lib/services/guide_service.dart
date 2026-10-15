/// 가이드 라인 저장·불러오기 (로컬 캐시 + 서버 동기화)
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
///
/// 정책
///  - 불러오기: 서버 우선 → 실패(오프라인 등)하면 로컬 캐시로 폴백
///  - 저장:     로컬에 먼저 쓰고 서버 upsert. 서버 실패해도 로컬은 남는다.
library;

import '../config/api_config.dart';
import '../config/constants.dart';
import '../models/shape.dart';
import '../models/swing_guide.dart';
import 'api_service.dart';
import 'local_store.dart';

class GuideLoadResult {
  final SwingGuide guide;
  final bool fromServer;
  final String? warning;

  const GuideLoadResult(this.guide, {this.fromServer = false, this.warning});
}

class GuideService {
  /// club + view 조합의 가이드 불러오기
  static Future<GuideLoadResult> load(ClubType club, ViewType view) async {
    final empty = SwingGuide(clubType: club, viewType: view);

    final res = await ApiService.get(ApiConfig.guideSync, query: {
      'club_type': club.code,
      'view_type': view.code,
    });

    if (res.success) {
      final json = res.data['shapes_json'] as String?;
      final shapes = SwingGuide.decodeShapes(json);
      // 서버 응답을 로컬에도 캐시 (오프라인 대비)
      await LocalStore.write(empty.key, json ?? '');
      return GuideLoadResult(
        empty.copyWith(shapes: shapes),
        fromServer: true,
      );
    }

    // 서버 실패 → 로컬 캐시
    final cached = await LocalStore.read(empty.key);
    final shapes = SwingGuide.decodeShapes(cached);
    return GuideLoadResult(
      empty.copyWith(shapes: shapes),
      fromServer: false,
      warning: res.isAuthError ? null : '서버에 연결하지 못해 기기에 저장된 가이드를 불러왔습니다.',
    );
  }

  /// 가이드 저장 (로컬 → 서버 upsert)
  /// 반환: 서버 저장 성공 여부와 메시지
  static Future<ApiResult> save(SwingGuide guide) async {
    final json = guide.encodeShapes();
    await LocalStore.write(guide.key, json);

    if (guide.shapes.isEmpty) {
      // 도형이 없으면 서버에서도 지운다
      return ApiService.post(ApiConfig.guideSync, body: {
        'club_type': guide.clubType.code,
        'view_type': guide.viewType.code,
        'delete': 1,
      });
    }

    return ApiService.post(ApiConfig.guideSync, body: {
      'club_type': guide.clubType.code,
      'view_type': guide.viewType.code,
      'shapes_json': json,
    });
  }

  /// 저장된 조합 목록 (club_type, view_type, updated_at)
  static Future<List<Map<String, dynamic>>> listSaved() async {
    final res = await ApiService.get(ApiConfig.guideSync, query: {'list': '1'});
    if (!res.success) return const [];
    return (res.data['guides'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  /// 로컬 캐시만 읽기 (서버 왕복 없이 즉시 표시할 때)
  static Future<List<Shape>> loadLocal(ClubType club, ViewType view) async {
    final key = SwingGuide(clubType: club, viewType: view).key;
    return SwingGuide.decodeShapes(await LocalStore.read(key));
  }
}

/// 문의 게시판 서버 통신
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import '../config/api_config.dart';
import '../models/inquiry.dart';
import 'api_service.dart';

class InquiryListResult {
  final List<Inquiry> inquiries;
  final bool isAdmin;
  final int totalUnread;

  const InquiryListResult({
    this.inquiries = const [],
    this.isAdmin = false,
    this.totalUnread = 0,
  });
}

class InquiryService {
  /// 목록 — 일반 사용자는 본인 문의만, 관리자는 전체
  static Future<(InquiryListResult?, ApiResult)> list() async {
    final res = await ApiService.get(ApiConfig.inquiryList);
    if (!res.success) return (null, res);

    final raw = (res.data['inquiries'] as List? ?? const []);
    return (
      InquiryListResult(
        inquiries: raw
            .map((e) => Inquiry.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        isAdmin: (res.data['is_admin'] as num?)?.toInt() == 1,
        totalUnread: (res.data['total_unread'] as num?)?.toInt() ?? 0,
      ),
      res
    );
  }

  /// 대시보드 뱃지용 — 미확인 답변 수만 (실패 시 0)
  static Future<int> unreadCount() async {
    final (page, _) = await list();
    return page?.totalUnread ?? 0;
  }

  static Future<ApiResult> create({
    required String title,
    required String content,
  }) =>
      ApiService.post(ApiConfig.inquiryCreate,
          body: {'title': title, 'content': content});

  static Future<(InquiryThread?, ApiResult)> detail(int inquiryId) async {
    final res = await ApiService.get(ApiConfig.inquiryDetail,
        query: {'inquiry_id': '$inquiryId'});
    if (!res.success) return (null, res);

    final msgs = (res.data['messages'] as List? ?? const [])
        .map((e) => InquiryMessage.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    return (
      InquiryThread(
        inquiry:
            Inquiry.fromJson(res.data['inquiry'] as Map<String, dynamic>),
        messages: msgs,
        isAdmin: (res.data['is_admin'] as num?)?.toInt() == 1,
        isOwner: (res.data['is_owner'] as num?)?.toInt() == 1,
      ),
      res
    );
  }

  static Future<ApiResult> reply({
    required int inquiryId,
    required String content,
  }) =>
      ApiService.post(ApiConfig.inquiryReply,
          body: {'inquiry_id': inquiryId, 'content': content});

  static Future<ApiResult> close(int inquiryId, {bool reopen = false}) =>
      ApiService.post(ApiConfig.inquiryClose, body: {
        'inquiry_id': inquiryId,
        if (reopen) 'reopen': 1,
      });
}

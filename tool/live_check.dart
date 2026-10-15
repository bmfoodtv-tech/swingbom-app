/// 실서버 연동 점검 — 앱의 서비스 계층(ApiService/LogService)을 그대로 사용한다.
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
///
/// 실행: dart run tool/live_check.dart
/// (Flutter 위젯을 import 하지 않으므로 순수 dart 로 실행된다)
library;

import 'dart:io';

import 'package:swingbom/config/api_config.dart';
import 'package:swingbom/models/member.dart';
import 'package:swingbom/services/api_service.dart';
import 'package:swingbom/services/log_service.dart';

int _pass = 0;
int _fail = 0;

void check(String label, bool ok, [String extra = '']) {
  if (ok) {
    _pass++;
    stdout.writeln('  [OK]   $label${extra.isEmpty ? '' : '  → $extra'}');
  } else {
    _fail++;
    stdout.writeln('  [FAIL] $label${extra.isEmpty ? '' : '  → $extra'}');
  }
}

Future<void> main() async {
  stdout.writeln('스윙봄 실서버 연동 점검 — ${ApiConfig.baseUrl}\n');

  final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
  final username = 'swbchk_$suffix';
  const password = 'test1234';

  // 1) 회원가입
  var r = await ApiService.post(ApiConfig.register, body: {
    'username': username,
    'password': password,
    'name': '점검계정',
  });
  check('회원가입', r.success, r.message);

  // 2) 중복 가입 차단
  r = await ApiService.post(ApiConfig.register,
      body: {'username': username, 'password': password});
  check('중복 가입 차단(code 409)', !r.success && r.code == 409, r.message);

  // 3) 잘못된 비밀번호
  r = await ApiService.post(ApiConfig.login,
      body: {'username': username, 'password': 'wrong'});
  check('비밀번호 오류(code 401)', !r.success && r.code == 401, r.message);

  // 4) 로그인 + 토큰
  r = await ApiService.post(ApiConfig.login,
      body: {'username': username, 'password': password});
  check('로그인', r.success && (r.data['token'] as String?)?.isNotEmpty == true);
  if (!r.success) {
    stdout.writeln('\n로그인 실패로 중단합니다.');
    exit(1);
  }
  ApiService.token = r.data['token'] as String;
  final me = Member.fromJson(r.data['member'] as Map<String, dynamic>);
  check('회원 파싱', me.username == username, '${me.displayName} / admin=${me.isAdmin}');

  // 5) 토큰 검증 (Splash 자동로그인 경로)
  r = await ApiService.get(ApiConfig.me);
  check('me.php 토큰 유효', r.success);

  // 6) 연습일지 등록
  final today = DateTime.now();
  String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  var s = await LogService.save(
    practiceDate: fmt(today),
    location: '스크린골프 점검점',
    swingCount: 120,
    notes: '드라이버 슬라이스 교정',
  );
  check('연습일지 등록', s.success, s.message);
  final logId = (s.data['id'] as num?)?.toInt() ?? 0;

  s = await LogService.save(
    practiceDate: fmt(today.subtract(const Duration(days: 3))),
    location: '실내연습장',
    swingCount: 80,
  );
  check('연습일지 등록 2', s.success);

  // 7) 목록 + 요약 통계
  var (page, res) = await LogService.list();
  check('목록 조회', page != null && page.logs.length >= 2,
      page == null ? res.message : '${page.logs.length}건');
  check('요약 통계 집계',
      page != null && page.summary.totalSwings >= 200 && page.summary.totalDays >= 2,
      page == null ? '' : '누적 ${page.summary.totalDays}일 / ${page.summary.totalSwings}회');
  check('최근 연습일', page?.summary.lastDate == fmt(today), '${page?.summary.lastDate}');

  // 8) limit
  (page, res) = await LogService.list(limit: 1);
  check('limit=1', page != null && page.logs.length == 1);

  // 9) 기간 필터
  (page, res) = await LogService.list(from: fmt(today), to: fmt(today));
  check('기간 필터(오늘만)', page != null && page.logs.length == 1,
      page == null ? '' : '${page.totalSwings}회');

  // 10) 수정
  s = await LogService.save(
    id: logId,
    practiceDate: fmt(today),
    location: '스크린골프 점검점(수정)',
    swingCount: 150,
    notes: '수정 확인',
  );
  check('연습일지 수정', s.success, s.message);
  (page, res) = await LogService.list(limit: 1);
  check('수정 반영', page?.logs.first.swingCount == 150,
      '${page?.logs.first.location}');

  // 11) 날짜 형식 검증
  s = await LogService.save(practiceDate: '2026-02-30', swingCount: 10);
  check('잘못된 날짜 거부(code 400)', !s.success && s.code == 400, s.message);

  // 12) 삭제
  s = await LogService.delete(logId);
  check('연습일지 삭제', s.success, s.message);
  s = await LogService.delete(logId);
  check('없는 일지 삭제 거부(code 404)', !s.success && s.code == 404, s.message);

  // ── 가이드 동기화 (Phase 3) ────────────────────────────────
  // 주의: Shape 모델은 dart:ui(Offset/Color)를 쓰므로 순수 dart 에서 import 할 수 없다.
  //       여기서는 서버가 주고받는 JSON 문자열을 그대로 검증한다.
  const shapesJson =
      '[{"type":"circle","points":[[0.58,0.3],[0.63,0.33]],"colorValue":4294901760,"strokeWidth":3},'
      '{"type":"line","points":[[0.45,0.2],[0.7,0.75]],"colorValue":4294901760,"strokeWidth":3}]';

  r = await ApiService.get(ApiConfig.guideSync,
      query: {'club_type': 'iron', 'view_type': 'side'});
  check('가이드 미저장 조회', r.success && r.data['shapes_json'] == null, r.message);

  r = await ApiService.post(ApiConfig.guideSync, body: {
    'club_type': 'iron',
    'view_type': 'side',
    'shapes_json': shapesJson,
  });
  check('가이드 저장', r.success && r.data['shape_count'] == 2, r.message);

  r = await ApiService.get(ApiConfig.guideSync,
      query: {'club_type': 'iron', 'view_type': 'side'});
  final roundTrip = r.data['shapes_json'] as String?;
  check('가이드 불러오기', r.success && roundTrip != null,
      '${roundTrip?.length ?? 0}자');
  check('정규화 좌표 보존', (roundTrip ?? '').contains('0.58'), roundTrip ?? '');

  r = await ApiService.post(ApiConfig.guideSync, body: {
    'club_type': 'driver',
    'view_type': 'front',
    'shapes_json': shapesJson,
  });
  check('다른 조합 저장', r.success);

  r = await ApiService.get(ApiConfig.guideSync, query: {'list': '1'});
  check('가이드 목록', r.success && (r.data['guides'] as List).length == 2,
      '${(r.data['guides'] as List?)?.length}건');

  r = await ApiService.get(ApiConfig.guideSync,
      query: {'club_type': 'putter', 'view_type': 'side'});
  check('잘못된 club_type 거부(code 400)', !r.success && r.code == 400, r.message);

  r = await ApiService.post(ApiConfig.guideSync, body: {
    'club_type': 'wood',
    'view_type': 'front',
    'shapes_json': 'not-json',
  });
  check('깨진 JSON 거부(code 400)', !r.success && r.code == 400, r.message);

  r = await ApiService.post(ApiConfig.guideSync, body: {
    'club_type': 'iron',
    'view_type': 'side',
    'delete': 1,
  });
  check('가이드 삭제', r.success, r.message);

  r = await ApiService.get(ApiConfig.guideSync,
      query: {'club_type': 'iron', 'view_type': 'side'});
  check('삭제 확인', r.success && r.data['shapes_json'] == null);

  // ── 스윙 자동 누적 (대시보드 통계 반영) ──────────────────────
  r = await ApiService.post(ApiConfig.practiceLogBump,
      body: {'count': 1, 'location': '자동누적 점검'});
  check('스윙 자동 누적 1회', r.success && r.data['swing_count'] == 1, r.message);
  r = await ApiService.post(ApiConfig.practiceLogBump, body: {'count': 1});
  check('스윙 자동 누적 2회', r.success && r.data['swing_count'] == 2);

  (page, res) = await LogService.list(limit: 5);
  check('연습만 해도 통계에 반영',
      page != null && page.summary.totalSwings >= 2 && page.summary.totalDays >= 1,
      page == null ? '' : '누적 ${page.summary.totalDays}일 / ${page.summary.totalSwings}회');

  // ── 이용권 / 쿠폰 ────────────────────────────────────────────
  r = await ApiService.get(ApiConfig.subscriptionStatus);
  final ent = (r.data['entitlement'] as Map<String, dynamic>?) ?? const {};
  check('가입 시 7일 무료체험 자동 부여',
      r.success && ent['active'] == true && ent['source'] == 'trial',
      '${ent['plan_label']} · ${ent['days_left']}일');
  check('판매 상품 3종 노출',
      (r.data['products'] as List?)?.length == 3,
      '${(r.data['products'] as List?)?.length}종');

  r = await ApiService.post(ApiConfig.couponRedeem, body: {'code': 'ZZZZ-ZZZZ-ZZZZ'});
  check('없는 쿠폰 거부(code 404)', !r.success && r.code == 404, r.message);

  r = await ApiService.post(ApiConfig.couponRedeem, body: {'code': ''});
  check('빈 쿠폰 거부(code 400)', !r.success && r.code == 400, r.message);

  r = await ApiService.post(ApiConfig.playVerify,
      body: {'product_id': 'bogus', 'purchase_token': 'x'});
  check('알 수 없는 상품 거부(code 400)', !r.success && r.code == 400, r.message);

  r = await ApiService.post(ApiConfig.playVerify,
      body: {'product_id': 'swb_pass_1m', 'purchase_token': 'unverified_token_check'});
  check('검증 미설정 시 지급 거부(code 402)', !r.success && r.code == 402, r.message);

  // ── 문의 게시판 ──────────────────────────────────────────────
  r = await ApiService.get(ApiConfig.inquiryList);
  check('문의 목록(비어있음)', r.success && (r.data['inquiries'] as List).isEmpty);

  r = await ApiService.post(ApiConfig.inquiryCreate,
      body: {'title': '점검 문의', 'content': '자동 점검에서 생성한 문의입니다.'});
  check('문의 작성', r.success, r.message);
  final inquiryId = (r.data['inquiry_id'] as num?)?.toInt() ?? 0;

  r = await ApiService.post(ApiConfig.inquiryCreate,
      body: {'title': '', 'content': '제목 없음'});
  check('제목 없이 작성 거부(code 400)', !r.success && r.code == 400, r.message);

  r = await ApiService.get(ApiConfig.inquiryDetail,
      query: {'inquiry_id': '$inquiryId'});
  check('문의 상세(첫 메시지)',
      r.success && (r.data['messages'] as List).length == 1, r.message);

  r = await ApiService.post(ApiConfig.inquiryReply,
      body: {'inquiry_id': inquiryId, 'content': '추가 질문입니다.'});
  check('사용자 답글', r.success && r.data['sender_type'] == 'user', r.message);

  r = await ApiService.get(ApiConfig.inquiryDetail,
      query: {'inquiry_id': '$inquiryId'});
  check('스레드 2건', r.success && (r.data['messages'] as List).length == 2);

  r = await ApiService.post(ApiConfig.inquiryClose, body: {'inquiry_id': inquiryId});
  check('문의 종료', r.success && r.data['status'] == 'closed', r.message);

  r = await ApiService.post(ApiConfig.inquiryReply,
      body: {'inquiry_id': inquiryId, 'content': '종료 후 답글'});
  check('종료 후 답글 차단(code 400)', !r.success && r.code == 400, r.message);

  r = await ApiService.get(ApiConfig.inquiryDetail, query: {'inquiry_id': '999999'});
  check('없는 문의(code 404)', !r.success && r.code == 404, r.message);

  // ── 앱 설정 / 네이버 로그인 ──────────────────────────────────
  r = await ApiService.get(ApiConfig.appConfig);
  check('앱 설정 조회', r.success && r.data.containsKey('naver_enabled'),
      '네이버 ${r.data['naver_enabled'] == true ? '켜짐' : '꺼짐(키 미설정)'}');

  r = await ApiService.post(ApiConfig.naverExchange, body: {'code': ''});
  check('네이버 코드 없음 거부(code 400)', !r.success && r.code == 400, r.message);

  r = await ApiService.post(ApiConfig.naverExchange,
      body: {'code': 'deadbeef' * 6});
  check('네이버 잘못된 코드 거부(code 401)', !r.success && r.code == 401, r.message);

  // ── 회원 탈퇴 (구글 플레이 계정 삭제 정책) ──────────────────
  // 별도 계정을 만들어 실제로 지워본다 (본 점검 계정은 뒤 항목에서 계속 쓴다)
  final delUser = 'swbdel_$suffix';
  await ApiService.post(ApiConfig.register,
      body: {'username': delUser, 'password': password, 'name': '탈퇴점검'});
  final savedToken = ApiService.token;
  r = await ApiService.post(ApiConfig.login,
      body: {'username': delUser, 'password': password});
  ApiService.token = r.data['token'] as String?;

  await LogService.bump(count: 3);

  r = await ApiService.post(ApiConfig.accountDelete, body: {});
  check('비밀번호 없이 탈퇴 거부(code 400)', !r.success && r.code == 400, r.message);

  r = await ApiService.post(ApiConfig.accountDelete, body: {'password': 'wrong'});
  check('틀린 비밀번호 탈퇴 거부(code 401)', !r.success && r.code == 401, r.message);

  r = await ApiService.post(ApiConfig.accountDelete, body: {'password': password});
  check('회원 탈퇴', r.success, r.message);
  check('연습일지 함께 삭제', (r.data['practice_logs'] as num?) == 1,
      '${r.data['practice_logs']}건');

  r = await ApiService.get(ApiConfig.me);
  check('탈퇴 후 토큰 무효(code 401)', !r.success && r.isAuthError, r.message);

  r = await ApiService.post(ApiConfig.login,
      body: {'username': delUser, 'password': password});
  check('탈퇴 계정 재로그인 차단(code 401)', !r.success && r.code == 401, r.message);

  ApiService.token = savedToken; // 원래 점검 계정으로 복귀

  // 13) 로그아웃 → 토큰 폐기
  r = await ApiService.post(ApiConfig.logout);
  check('로그아웃', r.success);
  r = await ApiService.get(ApiConfig.me);
  check('폐기된 토큰 거부(code 401)', !r.success && r.isAuthError, r.message);

  // 14) 무인증 접근 차단
  ApiService.token = null;
  (page, res) = await LogService.list();
  check('무인증 목록 차단(code 401)', page == null && res.isAuthError, res.message);

  stdout.writeln('\n결과: 통과 $_pass · 실패 $_fail');
  stdout.writeln('점검 계정: $username (정리 필요)');
  exit(_fail == 0 ? 0 : 1);
}

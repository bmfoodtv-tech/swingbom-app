/// 스윙봄 API 설정
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

class ApiConfig {
  /// 서버 확정 주소 (닷홈 · baljubom.com/swingbom/)
  static const String baseUrl = 'https://baljubom.com/swingbom/';

  /// 충돌 방지용 토큰 헤더
  static const String tokenHeader = 'X-SWB-Token';

  /// 엔드포인트
  static const String register = 'register.php';
  static const String login = 'login.php';
  static const String logout = 'logout.php';
  static const String me = 'me.php';
  static const String practiceLogSave = 'practice_log_save.php';
  static const String practiceLogList = 'practice_log_list.php';
  static const String practiceLogDelete = 'practice_log_delete.php';
  static const String practiceLogBump = 'practice_log_bump.php';
  static const String guideSync = 'guide_sync.php';
  static const String inquiryList = 'inquiry_list.php';
  static const String inquiryCreate = 'inquiry_create.php';
  static const String inquiryDetail = 'inquiry_detail.php';
  static const String inquiryReply = 'inquiry_reply.php';
  static const String inquiryClose = 'inquiry_close.php';
  static const String subscriptionStatus = 'subscription_status.php';
  static const String couponRedeem = 'coupon_redeem.php';
  static const String playVerify = 'play_verify.php';
  static const String accountDelete = 'account_delete.php';
  static const String appConfig = 'app_config.php';
  static const String naverExchange = 'naver_exchange.php';

  /// 웹 계정 삭제 페이지 (플레이스토어 데이터 보안 신고 URL 과 동일)
  static const String deleteAccountUrl = '${baseUrl}delete_account.php';

  static const Duration timeout = Duration(seconds: 20);
}

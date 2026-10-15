/// 이용권(구독) 모델
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

class Entitlement {
  final bool active;
  final String? expiresAt;
  final int daysLeft;
  final String? planCode;
  final String? planLabel;
  final String? source; // trial / play / coupon / admin
  final bool isTrial;

  const Entitlement({
    this.active = false,
    this.expiresAt,
    this.daysLeft = 0,
    this.planCode,
    this.planLabel,
    this.source,
    this.isTrial = false,
  });

  /// 서버 응답이 없을 때의 기본값 (이용권 없음)
  static const none = Entitlement();

  String get sourceLabel => switch (source) {
        'trial' => '무료체험',
        'play' => '스토어 결제',
        'coupon' => '쿠폰',
        'admin' => '관리자 지급',
        _ => '',
      };

  /// 만료가 가까우면 안내를 띄운다
  bool get expiringSoon => active && daysLeft <= 3;

  String get shortExpiry {
    final e = expiresAt;
    if (e == null) return '';
    return e.length >= 10 ? e.substring(0, 10) : e;
  }

  factory Entitlement.fromJson(Map<String, dynamic> j) => Entitlement(
        active: j['active'] == true,
        expiresAt: j['expires_at'] as String?,
        daysLeft: (j['days_left'] as num?)?.toInt() ?? 0,
        planCode: j['plan_code'] as String?,
        planLabel: j['plan_label'] as String?,
        source: j['source'] as String?,
        isTrial: j['is_trial'] == true,
      );

  Map<String, dynamic> toJson() => {
        'active': active,
        'expires_at': expiresAt,
        'days_left': daysLeft,
        'plan_code': planCode,
        'plan_label': planLabel,
        'source': source,
        'is_trial': isTrial,
      };
}

/// 판매 상품 (플레이스토어 인앱 상품과 1:1)
class PassProduct {
  final String productId;
  final String planCode;
  final String label;
  final int days;
  final int price;

  const PassProduct({
    required this.productId,
    required this.planCode,
    required this.label,
    required this.days,
    required this.price,
  });

  /// 스토어에서 실제 가격을 못 받아왔을 때 표시할 기본 가격
  String get fallbackPrice =>
      '${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}원';

  /// 1개월 대비 월 환산 절감률 (배지용)
  int discountPercentVs(int monthlyPrice) {
    if (monthlyPrice <= 0 || days <= 0) return 0;
    final months = days / 30.0;
    final expected = monthlyPrice * months;
    if (expected <= 0) return 0;
    return (100 - (price / expected * 100)).round();
  }

  factory PassProduct.fromJson(Map<String, dynamic> j) => PassProduct(
        productId: (j['product_id'] as String?) ?? '',
        planCode: (j['plan_code'] as String?) ?? '',
        label: (j['label'] as String?) ?? '',
        days: (j['days'] as num?)?.toInt() ?? 0,
        price: (j['price'] as num?)?.toInt() ?? 0,
      );
}

class SubscriptionStatus {
  final Entitlement entitlement;
  final List<PassProduct> products;
  final List<Map<String, dynamic>> history;

  const SubscriptionStatus({
    this.entitlement = Entitlement.none,
    this.products = const [],
    this.history = const [],
  });
}

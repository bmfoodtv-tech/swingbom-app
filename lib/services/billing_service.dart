/// 이용권 · 플레이스토어 결제
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
///
/// 결제 흐름
///   앱: in_app_purchase 로 구매 → purchaseToken 획득
///   서버: play_verify.php 가 Google Play Developer API 로 진위 확인 → 이용권 부여
///   앱: completePurchase() 로 구매 완료 처리
///
/// ⚠️ 플레이스토어 결제는 **플레이 스토어에서 설치된 앱**에서만 동작한다.
///    (내부 테스트 트랙 이상). 사이드로드한 APK 에서는 상품 조회 자체가 되지 않는다.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/api_config.dart';
import '../models/entitlement.dart';
import 'api_service.dart';

class BillingService {
  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _sub;

  /// 스토어에서 받은 상품 정보 (productId → ProductDetails)
  static final Map<String, ProductDetails> storeProducts = {};

  /// 스토어 사용 가능 여부 (사이드로드 APK 에서는 false 가 될 수 있다)
  static bool available = false;

  /// 구매 결과 알림 — 화면에서 구독
  static final StreamController<BillingEvent> events =
      StreamController<BillingEvent>.broadcast();

  // ── 이용권 상태 ──────────────────────────────────────────
  static Future<(SubscriptionStatus?, ApiResult)> status() async {
    final res = await ApiService.get(ApiConfig.subscriptionStatus);
    if (!res.success) return (null, res);

    return (
      SubscriptionStatus(
        entitlement: Entitlement.fromJson(
            (res.data['entitlement'] as Map<String, dynamic>?) ?? const {}),
        products: (res.data['products'] as List? ?? const [])
            .map((e) => PassProduct.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        history: (res.data['history'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false),
      ),
      res
    );
  }

  static Future<ApiResult> redeemCoupon(String code) =>
      ApiService.post(ApiConfig.couponRedeem, body: {'code': code});

  // ── 스토어 초기화 ────────────────────────────────────────
  static Future<void> init(Iterable<String> productIds) async {
    available = await _iap.isAvailable();
    if (!available) return;

    _sub ??= _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) =>
          events.add(BillingEvent.error('결제 처리 중 오류가 발생했습니다.')),
    );

    if (productIds.isEmpty) return;
    final resp = await _iap.queryProductDetails(productIds.toSet());
    storeProducts
      ..clear()
      ..addEntries(resp.productDetails.map((p) => MapEntry(p.id, p)));

    if (resp.notFoundIDs.isNotEmpty) {
      debugPrint('[swb] 스토어에서 찾지 못한 상품: ${resp.notFoundIDs.join(", ")}');
    }
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  // ── 구매 ────────────────────────────────────────────────
  static Future<String?> buy(String productId) async {
    if (!available) {
      return '이 기기에서는 스토어 결제를 사용할 수 없습니다.\n'
          '플레이스토어에서 설치한 앱에서만 결제가 가능합니다.';
    }
    final product = storeProducts[productId];
    if (product == null) {
      return '상품 정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }

    try {
      // 기간 이용권은 소모성 상품 — 여러 번 구매해 기간을 이어 붙인다
      await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
        autoConsume: true,
      );
      return null;
    } catch (e) {
      return '결제를 시작하지 못했습니다.';
    }
  }

  /// 이전에 완료하지 못한 구매 복구
  static Future<void> restore() async {
    if (!available) return;
    try {
      await _iap.restorePurchases();
    } catch (_) {/* 무시 */}
  }

  static Future<void> _onPurchaseUpdate(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          events.add(BillingEvent.pending());
          break;

        case PurchaseStatus.canceled:
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          events.add(BillingEvent.canceled());
          break;

        case PurchaseStatus.error:
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          events.add(BillingEvent.error(
              p.error?.message ?? '결제에 실패했습니다.'));
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final res = await _verifyOnServer(p);
          // 서버 반영 여부와 무관하게 스토어 쪽 구매는 닫아준다.
          // (실패 시 restorePurchases 로 다시 시도할 수 있다)
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          events.add(res.success
              ? BillingEvent.done(res.message)
              : BillingEvent.error(res.message));
          break;
      }
    }
  }

  static Future<ApiResult> _verifyOnServer(PurchaseDetails p) {
    return ApiService.post(ApiConfig.playVerify, body: {
      'product_id': p.productID,
      'purchase_token': p.verificationData.serverVerificationData,
      if (p.purchaseID != null) 'order_id': p.purchaseID,
    });
  }
}

enum BillingEventType { pending, done, canceled, error }

class BillingEvent {
  final BillingEventType type;
  final String message;

  const BillingEvent(this.type, this.message);

  factory BillingEvent.pending() =>
      const BillingEvent(BillingEventType.pending, '결제를 진행하고 있습니다…');
  factory BillingEvent.done(String m) =>
      BillingEvent(BillingEventType.done, m.isEmpty ? '이용권이 등록되었습니다.' : m);
  factory BillingEvent.canceled() =>
      const BillingEvent(BillingEventType.canceled, '결제를 취소했습니다.');
  factory BillingEvent.error(String m) => BillingEvent(BillingEventType.error, m);
}

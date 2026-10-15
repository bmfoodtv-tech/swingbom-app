/// 이용권 — 현재 상태 · 플레이스토어 결제 · 쿠폰 등록
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/app_footer.dart';
import '../config/constants.dart';
import '../models/entitlement.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';

class SubscriptionScreen extends StatefulWidget {
  /// 이용권이 만료돼 기능이 막힌 상태로 들어온 경우 안내 문구가 달라진다
  final bool blocked;

  const SubscriptionScreen({super.key, this.blocked = false});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  SubscriptionStatus _status = const SubscriptionStatus();
  StreamSubscription<BillingEvent>? _events;

  @override
  void initState() {
    super.initState();
    _events = BillingService.events.stream.listen(_onBilling);
    _load();
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final (status, res) = await BillingService.status();
    if (!mounted) return;

    if (status == null) {
      setState(() {
        _loading = false;
        _error = res.message;
      });
      return;
    }

    // 스토어 상품 정보 조회 (실패해도 서버 가격으로 표시한다)
    await BillingService.init(status.products.map((e) => e.productId));
    if (!mounted) return;

    setState(() {
      _loading = false;
      _status = status;
    });
    context.read<AuthService>().setEntitlement(status.entitlement);
  }

  void _onBilling(BillingEvent e) {
    if (!mounted) return;
    switch (e.type) {
      case BillingEventType.pending:
        setState(() => _busy = true);
        _toast(e.message);
        break;
      case BillingEventType.done:
        setState(() => _busy = false);
        _toast(e.message);
        _load();
        break;
      case BillingEventType.canceled:
        setState(() => _busy = false);
        _toast(e.message);
        break;
      case BillingEventType.error:
        setState(() => _busy = false);
        _toast(e.message, error: true);
        break;
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : null,
      ));
  }

  Future<void> _buy(PassProduct p) async {
    setState(() => _busy = true);
    final err = await BillingService.buy(p.productId);
    if (!mounted) return;
    if (err != null) {
      setState(() => _busy = false);
      _toast(err, error: true);
    }
    // 성공 시에는 purchaseStream 이벤트에서 마무리한다
  }

  Future<void> _redeemCoupon() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('쿠폰 등록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '전달받은 쿠폰번호를 입력하세요.\n대소문자와 하이픈은 없어도 됩니다.',
              style: TextStyle(fontSize: 13, color: AppColors.textSub),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(20)],
              decoration: const InputDecoration(
                hintText: 'ABCD-EFGH-JKLM',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('등록'),
          ),
        ],
      ),
    );

    if (code == null || code.isEmpty || !mounted) return;

    setState(() => _busy = true);
    final res = await BillingService.redeemCoupon(code);
    if (!mounted) return;
    setState(() => _busy = false);

    _toast(res.message, error: !res.success);
    if (res.success) _load();
  }

  @override
  Widget build(BuildContext context) {
    final ent = _status.entitlement;
    final monthly = _status.products
        .firstWhere((p) => p.planCode == 'm1',
            orElse: () => const PassProduct(
                productId: '', planCode: '', label: '', days: 30, price: 3300))
        .price;

    return Scaffold(
      appBar: AppBar(
        title: const Text('이용권'),
        actions: [
          IconButton(
            tooltip: '구매 복구',
            icon: const Icon(Icons.restore),
            onPressed: _busy
                ? null
                : () async {
                    _toast('이전 결제 내역을 확인합니다…');
                    await BillingService.restore();
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (widget.blocked && !ent.active) const _BlockedNotice(),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.danger)),
                          ),
                          TextButton(
                              onPressed: _load, child: const Text('다시 시도')),
                        ],
                      ),
                    ),

                  _CurrentCard(entitlement: ent),

                  const SizedBox(height: 24),
                  const Text('이용권 구매',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    ent.active
                        ? '남은 기간 뒤에 이어서 더해집니다.'
                        : '구매 즉시 사용할 수 있습니다.',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSub),
                  ),
                  const SizedBox(height: 12),

                  ..._status.products.map((p) => _ProductCard(
                        product: p,
                        storePrice:
                            BillingService.storeProducts[p.productId]?.price,
                        discount: p.planCode == 'm1'
                            ? 0
                            : p.discountPercentVs(monthly),
                        busy: _busy,
                        onTap: () => _buy(p),
                      )),

                  if (!BillingService.available)
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Text(
                        '지금은 스토어 결제를 사용할 수 없습니다.\n'
                        '플레이스토어에서 설치한 앱에서만 결제가 가능합니다.\n'
                        '테스트 중이시라면 아래 쿠폰 등록을 이용해 주세요.',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF92400E),
                            height: 1.5),
                      ),
                    ),

                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _redeemCoupon,
                    icon: const Icon(Icons.confirmation_number_outlined),
                    label: const Text('쿠폰번호 등록'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),

                  if (_status.history.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    const Text('이용 내역',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._status.history.map(_historyTile),
                  ],

                  const SizedBox(height: 10),
                  const AppFooter(),
                ],
              ),
      ),
    );
  }

  Widget _historyTile(Map<String, dynamic> h) {
    final source = switch (h['source']) {
      'trial' => '무료체험',
      'play' => '스토어 결제',
      'coupon' => '쿠폰',
      'admin' => '관리자 지급',
      _ => '',
    };
    final started = (h['started_at'] as String?) ?? '';
    final expires = (h['expires_at'] as String?) ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${h['plan_label'] ?? h['plan_code']}  ·  $source',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  '${started.length >= 10 ? started.substring(0, 10) : started}'
                  ' ~ ${expires.length >= 10 ? expires.substring(0, 10) : expires}',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSub),
                ),
              ],
            ),
          ),
          if (h['status'] == 'expired')
            const Text('만료',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSub)),
        ],
      ),
    );
  }
}

class _BlockedNotice extends StatelessWidget {
  const _BlockedNotice();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, color: AppColors.danger, size: 20),
            SizedBox(width: 11),
            Expanded(
              child: Text(
                '이용권이 만료되어 연습 기능을 쓸 수 없습니다.\n'
                '이용권을 등록하면 바로 다시 사용할 수 있습니다.\n'
                '(연습일지와 가이드는 그대로 보관됩니다)',
                style: TextStyle(
                    fontSize: 13, color: Color(0xFF991B1B), height: 1.55),
              ),
            ),
          ],
        ),
      );
}

class _CurrentCard extends StatelessWidget {
  final Entitlement entitlement;

  const _CurrentCard({required this.entitlement});

  @override
  Widget build(BuildContext context) {
    final e = entitlement;
    final active = e.active;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : const Color(0xFF64748B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(active ? Icons.verified : Icons.lock_outline,
                  color: Colors.white, size: 19),
              const SizedBox(width: 7),
              Text(
                active ? '이용 중' : '이용권 없음',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              if (active && e.sourceLabel.isNotEmpty) ...[
                const SizedBox(width: 7),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(e.sourceLabel,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10.5)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (active) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${e.daysLeft}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        height: 1)),
                const SizedBox(width: 5),
                const Text('일 남음',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 6),
            Text('${e.shortExpiry} 까지  ·  ${e.planLabel ?? ''}',
                style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            if (e.expiringSoon) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('곧 만료됩니다. 미리 연장해 두세요.',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ] else
            const Text('이용권을 등록하면 연습 기능을 사용할 수 있습니다.',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final PassProduct product;
  final String? storePrice;
  final int discount;
  final bool busy;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.storePrice,
    required this.discount,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final best = discount >= 30;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: best ? AppColors.primary : AppColors.border,
            width: best ? 1.7 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(product.label,
                              style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMain)),
                          if (discount > 0) ...[
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('$discount% 절약',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${product.days}일 사용',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSub)),
                    ],
                  ),
                ),
                Text(
                  storePrice ?? product.fallbackPrice,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.textSub),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

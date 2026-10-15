/// 연습일지 대시보드 — 로그인 후 첫 화면(홈)
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_footer.dart';
import '../config/constants.dart';
import '../models/practice_log.dart';
import '../services/auth_service.dart';
import '../models/entitlement.dart';
import '../services/billing_service.dart';
import '../services/inquiry_service.dart';
import '../services/log_service.dart';
import '../widgets/stat_card.dart';
import '../widgets/log_tile.dart';
import 'log_edit_screen.dart';
import 'club_select_screen.dart';
import 'subscription_screen.dart';
import 'inquiry_list_screen.dart';
import 'log_list_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String? _error;
  LogSummary _summary = const LogSummary();
  List<PracticeLog> _recent = const [];

  /// 문의 미확인 답변 수 (뱃지)
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final (page, res) = await LogService.list(limit: 5);
    if (!mounted) return;

    if (page == null) {
      // 토큰 만료 → 로그인 화면으로
      if (res.isAuthError) {
        await context.read<AuthService>().logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
        return;
      }
      setState(() {
        _loading = false;
        _error = res.message;
      });
      return;
    }

    setState(() {
      _loading = false;
      _summary = page.summary;
      _recent = page.logs;
    });

    // 이용권 상태 갱신 (배너 + 연습 시작 게이팅에 쓰인다)
    final (sub, _) = await BillingService.status();
    if (mounted && sub != null) {
      context.read<AuthService>().setEntitlement(sub.entitlement);
    }

    // 문의 미확인 답변 뱃지 (실패해도 화면에 영향 없음)
    final unread = await InquiryService.unreadCount();
    if (mounted) setState(() => _unread = unread);
  }

  Future<void> _openInquiries() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InquiryListScreen()),
    );
    if (mounted) _load();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃하시겠습니까?\n다음 실행 시 다시 로그인해야 합니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('로그아웃', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await context.read<AuthService>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  /// 회원 탈퇴 — 삭제 내용 안내 → 비밀번호 확인 → 서버 삭제
  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('탈퇴하면 아래 정보가 즉시 영구 삭제되며 되돌릴 수 없습니다.',
                  style: TextStyle(fontSize: 14)),
              SizedBox(height: 12),
              Text(
                  '· 회원 정보 (아이디·이름·이메일)\n'
                  '· 연습일지 전체\n'
                  '· 저장해 둔 가이드 라인 전체\n'
                  '· 문의 내역과 답변\n'
                  '· 남아 있는 이용권 (환불되지 않습니다)',
                  style: TextStyle(fontSize: 13.5, height: 1.7)),
              SizedBox(height: 12),
              Text('기기 갤러리에 저장한 스윙 영상은 그대로 남습니다.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSub)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('계속', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final pwController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('본인 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('계정을 삭제하려면 비밀번호를 입력하세요.',
                style: TextStyle(fontSize: 13.5, color: AppColors.textSub)),
            const SizedBox(height: 14),
            TextField(
              controller: pwController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(c, pwController.text),
            child: const Text('탈퇴하기', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (password == null || password.isEmpty || !mounted) return;

    setState(() => _loading = true);
    final res = await context.read<AuthService>().deleteAccount(password);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.message),
        backgroundColor: AppColors.danger,
      ));
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(res.message)));
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _openEdit({PracticeLog? log}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LogEditScreen(log: log)),
    );
    if (changed == true) _load();
  }

  Future<void> _openList() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LogListScreen()),
    );
    if (changed == true) _load();
  }

  Future<void> _openSubscription({bool blocked = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SubscriptionScreen(blocked: blocked)),
    );
    if (mounted) _load();
  }

  Future<void> _startPractice() async {
    // 이용권이 없으면 연습 기능 대신 이용권 화면으로 보낸다
    if (!context.read<AuthService>().hasAccess) {
      await _openSubscription(blocked: true);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ClubSelectScreen()),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final member = context.watch<AuthService>().member;

    return Scaffold(
      appBar: AppBar(
        title: const Text('⛳ $kAppName'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          PopupMenuButton<String>(
            tooltip: '계정 메뉴',
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'logout') _logout();
              if (v == 'delete') _deleteAccount();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, size: 18, color: AppColors.textSub),
                  SizedBox(width: 10),
                  Text('로그아웃'),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.person_remove_outlined,
                      size: 18, color: AppColors.danger),
                  SizedBox(width: 10),
                  Text('회원 탈퇴', style: TextStyle(color: AppColors.danger)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                '${member?.displayName ?? '회원'}님, 오늘도 스윙 점검해요',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _summary.lastDate == null
                    ? '아직 연습 기록이 없습니다. 첫 일지를 남겨보세요.'
                    : '최근 연습일 · ${_summary.lastDate}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSub),
              ),
              const SizedBox(height: 14),

              _PassBanner(
                entitlement: context.watch<AuthService>().entitlement,
                onTap: () => _openSubscription(),
              ),
              const SizedBox(height: 14),

              if (_error != null) _ErrorBox(message: _error!, onRetry: _load),

              // ── 요약 통계 ────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: '이번 달 연습일',
                      value: '${_summary.monthDays}',
                      unit: '일',
                      icon: Icons.calendar_month,
                      loading: _loading,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      label: '이번 달 스윙',
                      value: '${_summary.monthSwings}',
                      unit: '회',
                      icon: Icons.sports_golf,
                      loading: _loading,
                      highlight: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: '누적 연습일',
                      value: '${_summary.totalDays}',
                      unit: '일',
                      icon: Icons.event_available,
                      loading: _loading,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      label: '누적 스윙',
                      value: '${_summary.totalSwings}',
                      unit: '회',
                      icon: Icons.timeline,
                      loading: _loading,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              // ── 최근 연습일지 ─────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '최근 연습일지',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextButton(onPressed: _openList, child: const Text('전체 보기')),
                ],
              ),
              const SizedBox(height: 4),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_recent.isEmpty)
                const _EmptyBox()
              else
                ..._recent.map((e) => LogTile(
                      log: e,
                      onTap: () => _openEdit(log: e),
                    )),

              const SizedBox(height: 26),

              // ── 주요 버튼 ────────────────────────────────
              FilledButton.icon(
                onPressed: _startPractice,
                icon: const Icon(Icons.play_circle_fill),
                label: const Text('연습 시작', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openEdit(),
                icon: const Icon(Icons.add),
                label: const Text('연습일지 작성'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _openInquiries,
                icon: Badge(
                  isLabelVisible: _unread > 0,
                  label: Text('$_unread'),
                  child: const Icon(Icons.chat_bubble_outline),
                ),
                label: Text(_unread > 0 ? '문의하기 · 새 답변 $_unread건' : '문의하기'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor:
                      _unread > 0 ? AppColors.primary : null,
                ),
              ),

              const SizedBox(height: 8),
              const AppFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이용권 상태 배너 — 남은 일수, 만료 임박·만료 시 강조
class _PassBanner extends StatelessWidget {
  final Entitlement entitlement;
  final VoidCallback onTap;

  const _PassBanner({required this.entitlement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = entitlement;
    final (bg, border, fg, icon) = !e.active
        ? (const Color(0xFFFEF2F2), const Color(0xFFFECACA),
            const Color(0xFF991B1B), Icons.lock_outline)
        : e.expiringSoon
            ? (const Color(0xFFFFFBEB), const Color(0xFFFDE68A),
                const Color(0xFF92400E), Icons.schedule)
            : (const Color(0xFFF0FDF4), const Color(0xFFBBF7D0),
                const Color(0xFF166534), Icons.verified);

    final text = !e.active
        ? '이용권이 없습니다 · 등록하고 연습을 시작하세요'
        : e.isTrial
            ? '무료체험 ${e.daysLeft}일 남음 · ${e.shortExpiry}까지'
            : '${e.planLabel ?? '이용권'} ${e.daysLeft}일 남음 · ${e.shortExpiry}까지';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 9),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
              ),
              Icon(Icons.chevron_right, size: 19, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.sports_golf, size: 34, color: AppColors.textSub),
          SizedBox(height: 8),
          Text('아직 연습일지가 없습니다.',
              style: TextStyle(color: AppColors.textSub, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 13, color: AppColors.danger)),
          ),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

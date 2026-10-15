/// 로그인 / 회원가입
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../config/app_footer.dart';
import '../config/constants.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'naver_login_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();

  bool _isRegister = false;
  bool _busy = false;
  bool _obscure = true;

  /// 서버가 네이버 로그인을 켜 두었는지 (키가 없으면 버튼을 숨긴다)
  bool _naverEnabled = false;
  String _naverLoginUrl = '';
  String _naverDonePath = 'naver_done.php';

  @override
  void initState() {
    super.initState();
    _loadServerConfig();
  }

  Future<void> _loadServerConfig() async {
    final res = await ApiService.get(ApiConfig.appConfig);
    if (!mounted || !res.success) return;
    setState(() {
      _naverEnabled = res.data['naver_enabled'] == true;
      _naverLoginUrl = (res.data['naver_login_url'] as String?) ?? '';
      _naverDonePath =
          (res.data['naver_done_path'] as String?) ?? 'naver_done.php';
    });
  }

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.primary,
    ));
  }

  /// 네이버 로그인 — 웹뷰에서 인증 후 받은 1회용 코드를 토큰으로 교환한다
  Future<void> _naverLogin() async {
    if (_naverLoginUrl.isEmpty) return;

    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => NaverLoginScreen(
          loginUrl: _naverLoginUrl,
          donePath: _naverDonePath,
        ),
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;

    setState(() => _busy = true);
    final res = await context.read<AuthService>().completeNaverLogin(code);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!res.success) {
      _toast(res.message, error: true);
      return;
    }
    _toast(res.message);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (_) => false,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthService>();

    try {
      if (_isRegister) {
        final r = await auth.register(
          username: _id.text.trim(),
          password: _pw.text,
          name: _name.text.trim(),
          email: _email.text.trim(),
        );
        if (!r.success) {
          _toast(r.message, error: true);
          return;
        }
        // 가입 성공 → 바로 로그인
        final l = await auth.login(_id.text.trim(), _pw.text);
        if (!l.success) {
          _toast('가입은 완료됐습니다. 다시 로그인해 주세요.');
          setState(() => _isRegister = false);
          return;
        }
      } else {
        final r = await auth.login(_id.text.trim(), _pw.text);
        if (!r.success) {
          _toast(r.message, error: true);
          return;
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    const Text('⛳',
                        style: TextStyle(fontSize: 52),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text(
                      kAppName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '내 스윙을 가이드 라인 위에 겹쳐 확인하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.textSub),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _id,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: '아이디',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return '아이디를 입력하세요.';
                        if (_isRegister && !_kIdRe.hasMatch(s)) {
                          return '영문·숫자·밑줄 4~50자로 입력하세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pw,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if ((v ?? '').isEmpty) return '비밀번호를 입력하세요.';
                        if (_isRegister && v!.length < 6) {
                          return '6자 이상 입력하세요.';
                        }
                        return null;
                      },
                    ),
                    if (_isRegister) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: '이름 (선택)',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: '이메일 (선택)',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return null;
                          return _kEmailRe.hasMatch(s)
                              ? null
                              : '이메일 형식이 올바르지 않습니다.';
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(_isRegister ? '가입하고 시작하기' : '로그인'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _isRegister = !_isRegister;
                                _formKey.currentState?.reset();
                              }),
                      child: Text(
                          _isRegister ? '이미 계정이 있어요 · 로그인' : '처음이신가요? 회원가입'),
                    ),
                    if (_naverEnabled) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('또는',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSub)),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _NaverButton(
                        onPressed: _busy ? null : _naverLogin,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '네이버로 처음 로그인하면 자동으로 가입되며\n'
                        '7일 무료체험이 시작됩니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSub,
                            height: 1.5),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const AppFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 아이디: 영문·숫자·밑줄 4~50자 (서버 register.php 검증과 동일)
final RegExp _kIdRe = RegExp(r'^[A-Za-z0-9_]{4,50}$');

/// 이메일 간이 검증
final RegExp _kEmailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// 네이버 브랜드 버튼 — 공식 색(#03C75A)과 로고 형태를 따른다
class _NaverButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _NaverButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF03C75A),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF03C75A).withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'N',
                style: TextStyle(
                  color: Color(0xFF03C75A),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('네이버로 로그인',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

/// 스플래시 — 저장된 토큰 확인 후 자동 로그인 분기
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_footer.dart';
import '../config/constants.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final auth = context.read<AuthService>();
    final ok = await auth.tryAutoLogin();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ok ? const DashboardScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const Text('⛳', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            const Text(
              kAppName,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              kAppNameEn,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(Colors.white70),
              ),
            ),
            const Spacer(),
            AppFooter(color: Colors.white.withValues(alpha: 0.65)),
          ],
        ),
      ),
    );
  }
}

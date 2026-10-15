/// 네이버 로그인 — 웹뷰로 네이버 인증을 진행한다.
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
///
/// 네이티브 SDK 를 쓰지 않는 이유
///   SDK 를 붙이면 안드로이드 빌드 설정(compileSdk·서명 해시 등)에 묶여
///   유지보수가 까다로워진다. 웹뷰 + 서버 콜백 방식은 서버만 고치면 되고
///   iOS 에서도 같은 코드로 동작한다.
///
/// 흐름
///   웹뷰가 naver_login.php 를 연다
///     → 네이버 로그인 화면
///     → 서버 콜백이 회원을 만들고 naver_done.php?c=1회용코드 로 보낸다
///     → 이 화면이 그 주소를 가로채 코드만 들고 닫힌다
library;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/constants.dart';

class NaverLoginScreen extends StatefulWidget {
  /// 서버가 알려준 시작 주소 (app_config.php)
  final String loginUrl;

  /// 완료를 판정할 경로 조각 (기본 naver_done.php)
  final String donePath;

  const NaverLoginScreen({
    super.key,
    required this.loginUrl,
    this.donePath = 'naver_done.php',
  });

  @override
  State<NaverLoginScreen> createState() => _NaverLoginScreenState();
}

class _NaverLoginScreenState extends State<NaverLoginScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _finished = false; // 코드를 한 번만 돌려주기 위한 잠금

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _checkDone(url);
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (req) {
            if (_checkDone(req.url)) return NavigationDecision.prevent;
            return NavigationDecision.navigate;
          },
          onWebResourceError: (err) {
            if (!mounted || _finished) return;
            // 페이지 자체를 못 연 경우에만 알린다 (하위 리소스 실패는 무시)
            if (err.isForMainFrame ?? false) {
              _close(null, message: '네이버 로그인 페이지를 열지 못했습니다.');
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.loginUrl));
  }

  /// 완료 주소면 1회용 코드를 꺼내 화면을 닫는다
  bool _checkDone(String url) {
    if (_finished || !url.contains(widget.donePath)) return false;
    final code = Uri.tryParse(url)?.queryParameters['c'];
    _close(code,
        message: code == null ? '로그인 정보를 받지 못했습니다.' : null);
    return true;
  }

  void _close(String? code, {String? message}) {
    if (_finished) return;
    _finished = true;
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
      ));
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('네이버 로그인'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _close(null),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const LinearProgressIndicator(minHeight: 2.5),
          ],
        ),
      ),
    );
  }
}

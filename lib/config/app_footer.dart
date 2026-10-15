/// 저작권 푸터 위젯 — 모든 주요 화면 하단에 배치
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'package:flutter/material.dart';
import 'constants.dart';

class AppFooter extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Color? color;

  const AppFooter({
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 14),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        kCopyright,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: color ?? AppColors.textSub.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

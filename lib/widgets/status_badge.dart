/// 문의 상태 배지
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'package:flutter/material.dart';
import '../models/inquiry.dart';

class StatusBadge extends StatelessWidget {
  final InquiryStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      InquiryStatus.open => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      InquiryStatus.answered =>
        (const Color(0xFFDCFCE7), const Color(0xFF166534)),
      InquiryStatus.closed =>
        (const Color(0xFFE5E7EB), const Color(0xFF4B5563)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}

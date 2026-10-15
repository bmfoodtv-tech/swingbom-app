/// 대시보드 요약 통계 카드
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'package:flutter/material.dart';
import '../config/constants.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final bool loading;
  final bool highlight;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.loading = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = highlight ? Colors.white : AppColors.textMain;
    final sub = highlight ? Colors.white70 : AppColors.textSub;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primary : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: highlight ? AppColors.primary : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: sub),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: sub),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (loading)
            SizedBox(
              height: 26,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(sub),
                  ),
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: fg,
                  ),
                ),
                const SizedBox(width: 3),
                Text(unit, style: TextStyle(fontSize: 12, color: sub)),
              ],
            ),
        ],
      ),
    );
  }
}

/// 연습일지 카드 한 줄
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/practice_log.dart';

class LogTile extends StatelessWidget {
  final PracticeLog log;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const LogTile({super.key, required this.log, this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final hasNotes = (log.notes ?? '').trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            log.practiceDate,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${log.swingCount}회',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if ((log.location ?? '').isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined,
                                size: 13, color: AppColors.textSub),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                log.location!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5, color: AppColors.textSub),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (hasNotes) ...[
                        const SizedBox(height: 5),
                        Text(
                          log.notes!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textSub),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: '삭제',
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: AppColors.textSub),
                    onPressed: onDelete,
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(top: 2, right: 6),
                    child: Icon(Icons.chevron_right,
                        size: 20, color: AppColors.textSub),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

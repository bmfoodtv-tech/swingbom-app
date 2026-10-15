/// 문의 목록 — 일반 사용자는 내 문의, 관리자는 전체 문의
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'package:flutter/material.dart';

import '../config/app_footer.dart';
import '../config/constants.dart';
import '../models/inquiry.dart';
import '../services/inquiry_service.dart';
import '../widgets/status_badge.dart';
import 'inquiry_detail_screen.dart';
import 'inquiry_write_screen.dart';

class InquiryListScreen extends StatefulWidget {
  const InquiryListScreen({super.key});

  @override
  State<InquiryListScreen> createState() => _InquiryListScreenState();
}

class _InquiryListScreenState extends State<InquiryListScreen> {
  bool _loading = true;
  String? _error;
  InquiryListResult _page = const InquiryListResult();

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
    final (page, res) = await InquiryService.list();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (page == null) {
        _error = res.message;
      } else {
        _page = page;
      }
    });
  }

  Future<void> _write() async {
    final created = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const InquiryWriteScreen()));
    if (created == true) _load();
  }

  Future<void> _open(Inquiry inq) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InquiryDetailScreen(inquiryId: inq.id)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _page.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? '문의 관리 (관리자)' : '문의하기'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: _write,
              icon: const Icon(Icons.edit),
              label: const Text('문의 작성'),
            ),
      body: SafeArea(
        child: Column(
          children: [
            if (_page.totalUnread > 0)
              Container(
                width: double.infinity,
                color: AppColors.primary.withValues(alpha: 0.08),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                  children: [
                    const Icon(Icons.mark_email_unread_outlined,
                        size: 17, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      isAdmin
                          ? '확인하지 않은 문의 ${_page.totalUnread}건'
                          : '읽지 않은 답변 ${_page.totalUnread}건',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorView(message: _error!, onRetry: _load)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _page.inquiries.isEmpty
                              ? ListView(
                                  children: [
                                    const SizedBox(height: 90),
                                    Icon(Icons.forum_outlined,
                                        size: 40,
                                        color: AppColors.textSub
                                            .withValues(alpha: 0.5)),
                                    const SizedBox(height: 12),
                                    Text(
                                      isAdmin
                                          ? '등록된 문의가 없습니다.'
                                          : '아직 문의가 없습니다.\n궁금한 점을 남겨주세요.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: AppColors.textSub,
                                          fontSize: 13,
                                          height: 1.6),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 14, 16, 90),
                                  itemCount: _page.inquiries.length,
                                  itemBuilder: (_, i) => _InquiryTile(
                                    inquiry: _page.inquiries[i],
                                    showWriter: isAdmin,
                                    onTap: () => _open(_page.inquiries[i]),
                                  ),
                                ),
                        ),
            ),
            const AppFooter(padding: EdgeInsets.only(top: 2, bottom: 6)),
          ],
        ),
      ),
    );
  }
}

class _InquiryTile extends StatelessWidget {
  final Inquiry inquiry;
  final bool showWriter;
  final VoidCallback onTap;

  const _InquiryTile({
    required this.inquiry,
    required this.showWriter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusBadge(status: inquiry.status),
                          const SizedBox(width: 7),
                          if (inquiry.unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('${inquiry.unreadCount}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        inquiry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMain),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        [
                          if (showWriter && inquiry.writerLabel.isNotEmpty)
                            inquiry.writerLabel,
                          '${inquiry.messageCount}개 대화',
                          inquiry.updatedAt.length >= 16
                              ? inquiry.updatedAt.substring(0, 16)
                              : inquiry.updatedAt,
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textSub),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 20, left: 4),
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

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      );
}

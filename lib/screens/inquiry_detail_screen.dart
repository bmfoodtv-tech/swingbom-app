/// 문의 상세 — 사용자 ↔ 관리자 대화 스레드 + 답글
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/inquiry.dart';
import '../services/inquiry_service.dart';
import '../widgets/status_badge.dart';

class InquiryDetailScreen extends StatefulWidget {
  final int inquiryId;

  const InquiryDetailScreen({super.key, required this.inquiryId});

  @override
  State<InquiryDetailScreen> createState() => _InquiryDetailScreenState();
}

class _InquiryDetailScreenState extends State<InquiryDetailScreen> {
  final _reply = TextEditingController();
  final _scroll = ScrollController();

  bool _loading = true;
  bool _sending = false;
  String? _error;
  InquiryThread? _thread;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool toBottom = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final (thread, res) = await InquiryService.detail(widget.inquiryId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (thread == null) {
        _error = res.message;
      } else {
        _thread = thread;
      }
    });
    if (toBottom) _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    final res = await InquiryService.reply(
      inquiryId: widget.inquiryId,
      content: text,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.message),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    _reply.clear();
    await _load(toBottom: true);
  }

  Future<void> _toggleClose() async {
    final t = _thread;
    if (t == null) return;
    final closing = t.inquiry.status != InquiryStatus.closed;

    if (closing) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('문의 종료'),
          content: const Text('이 문의를 종료할까요?\n종료하면 답글을 달 수 없습니다.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('취소')),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('종료')),
          ],
        ),
      );
      if (ok != true) return;
    }

    final res = await InquiryService.close(widget.inquiryId, reopen: !closing);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.message),
      backgroundColor: res.success ? null : AppColors.danger,
    ));
    if (res.success) _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = _thread;

    return Scaffold(
      appBar: AppBar(
        title: const Text('문의 상세'),
        actions: [
          if (t != null)
            IconButton(
              tooltip: t.inquiry.status == InquiryStatus.closed
                  ? '다시 열기'
                  : '문의 종료',
              icon: Icon(t.inquiry.status == InquiryStatus.closed
                  ? Icons.lock_open
                  : Icons.lock_outline),
              onPressed: _toggleClose,
            ),
        ],
      ),
      body: SafeArea(
        child: _loading && t == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && t == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style: const TextStyle(color: AppColors.danger)),
                        const SizedBox(height: 12),
                        OutlinedButton(
                            onPressed: () => _load(),
                            child: const Text('다시 시도')),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      _Header(inquiry: t!.inquiry, showWriter: t.isAdmin),
                      Expanded(
                        child: ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          itemCount: t.messages.length,
                          itemBuilder: (_, i) => _Bubble(
                            message: t.messages[i],
                            writerLabel: t.inquiry.writerLabel.isEmpty
                                ? '나'
                                : t.inquiry.writerLabel,
                            viewerIsAdmin: t.isAdmin,
                          ),
                        ),
                      ),
                      if (t.canReply)
                        _ReplyBar(
                          controller: _reply,
                          sending: _sending,
                          isAdmin: t.isAdmin,
                          onSend: _send,
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: const Color(0xFFF1F5F9),
                          child: const Text(
                            '종료된 문의입니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSub),
                          ),
                        ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          kCopyright,
                          style: TextStyle(
                              fontSize: 10.5, color: AppColors.textSub),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Inquiry inquiry;
  final bool showWriter;

  const _Header({required this.inquiry, required this.showWriter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(status: inquiry.status),
              const Spacer(),
              Text(
                inquiry.createdAt.length >= 16
                    ? inquiry.createdAt.substring(0, 16)
                    : inquiry.createdAt,
                style:
                    const TextStyle(fontSize: 11.5, color: AppColors.textSub),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            inquiry.title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain),
          ),
          if (showWriter && inquiry.writerLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('작성자 · ${inquiry.writerLabel}',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textSub)),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final InquiryMessage message;
  final String writerLabel;
  final bool viewerIsAdmin;

  const _Bubble({
    required this.message,
    required this.writerLabel,
    required this.viewerIsAdmin,
  });

  @override
  Widget build(BuildContext context) {
    // 보는 사람 기준으로 내 메시지를 오른쪽에 둔다
    final mine = viewerIsAdmin ? message.fromAdmin : !message.fromAdmin;
    final who = message.fromAdmin ? '찬이작업실' : writerLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
            child: Text(
              '$who · ${message.createdAt.length >= 16 ? message.createdAt.substring(5, 16) : message.createdAt}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSub),
            ),
          ),
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: message.fromAdmin
                  ? const Color(0xFFDCFCE7)
                  : AppColors.card,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(mine ? 14 : 3),
                topRight: Radius.circular(mine ? 3 : 14),
                bottomLeft: const Radius.circular(14),
                bottomRight: const Radius.circular(14),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              message.content,
              style: const TextStyle(
                  fontSize: 14, height: 1.5, color: AppColors.textMain),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final bool isAdmin;
  final VoidCallback onSend;

  const _ReplyBar({
    required this.controller,
    required this.sending,
    required this.isAdmin,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: isAdmin ? '답변을 입력하세요' : '추가로 궁금한 점을 남겨주세요',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            height: 46,
            child: FilledButton(
              onPressed: sending ? null : onSend,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send, size: 19),
            ),
          ),
        ],
      ),
    );
  }
}

/// 연습일지 등록 / 수정
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_footer.dart';
import '../config/constants.dart';
import '../models/practice_log.dart';
import '../services/log_service.dart';

class LogEditScreen extends StatefulWidget {
  /// null 이면 신규 등록(오늘 날짜 기본값)
  final PracticeLog? log;

  /// 연습 화면에서 넘어올 때 스윙 카운트 기본값 (Phase 4 연동)
  final int? initialSwingCount;

  const LogEditScreen({super.key, this.log, this.initialSwingCount});

  @override
  State<LogEditScreen> createState() => _LogEditScreenState();
}

class _LogEditScreenState extends State<LogEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late final TextEditingController _location;
  late final TextEditingController _count;
  late final TextEditingController _notes;
  bool _busy = false;

  bool get _isEdit => widget.log != null;

  @override
  void initState() {
    super.initState();
    final l = widget.log;
    _date = l != null ? DateTime.parse(l.practiceDate) : DateTime.now();
    _location = TextEditingController(text: l?.location ?? '');
    _count = TextEditingController(
        text: '${l?.swingCount ?? widget.initialSwingCount ?? 0}');
    _notes = TextEditingController(text: l?.notes ?? '');
  }

  @override
  void dispose() {
    _location.dispose();
    _count.dispose();
    _notes.dispose();
    super.dispose();
  }

  String get _dateStr =>
      '${_date.year.toString().padLeft(4, '0')}-'
      '${_date.month.toString().padLeft(2, '0')}-'
      '${_date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: '연습일자 선택',
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _bump(int delta) {
    final cur = int.tryParse(_count.text.trim()) ?? 0;
    final next = (cur + delta).clamp(0, 100000);
    _count.text = '$next';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final res = await LogService.save(
      id: widget.log?.id,
      practiceDate: _dateStr,
      location: _location.text.trim(),
      swingCount: int.tryParse(_count.text.trim()) ?? 0,
      notes: _notes.text.trim(),
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.message),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(res.message)));
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('연습일지 삭제'),
        content: Text('${widget.log!.practiceDate} 일지를 삭제할까요?\n되돌릴 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    final res = await LogService.delete(widget.log!.id);
    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.message),
      backgroundColor: res.success ? null : AppColors.danger,
    ));
    if (res.success) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '연습일지 수정' : '연습일지 작성'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: '삭제',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              // 연습일자
              const _Label('연습일자'),
              InkWell(
                onTap: _busy ? null : _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(_dateStr, style: const TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(height: 18),

              // 연습 장소
              const _Label('연습 장소'),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                  hintText: '예) 스크린골프 강남점 / 실내연습장',
                  prefixIcon: Icon(Icons.place_outlined, size: 18),
                ),
                validator: (v) => (v ?? '').trim().length > 100
                    ? '100자 이내로 입력하세요.'
                    : null,
              ),
              const SizedBox(height: 18),

              // 스윙 카운트
              const _Label('연습 스윙 카운트'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _count,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        suffixText: '회',
                        prefixIcon: Icon(Icons.sports_golf, size: 18),
                      ),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null) return '숫자를 입력하세요.';
                        if (n < 0) return '0 이상이어야 합니다.';
                        if (n > 100000) return '너무 큰 값입니다.';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  _BumpBtn(label: '+10', onTap: _busy ? null : () => _bump(10)),
                  const SizedBox(width: 6),
                  _BumpBtn(label: '+50', onTap: _busy ? null : () => _bump(50)),
                ],
              ),
              const SizedBox(height: 18),

              // 특이사항
              const _Label('특이사항 메모'),
              TextFormField(
                controller: _notes,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '예) 드라이버 슬라이스 교정 / 머리 고정 집중',
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(_isEdit ? '수정 저장' : '저장'),
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

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7, left: 2),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textMain,
          ),
        ),
      );
}

class _BumpBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _BumpBtn({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Text(label),
        ),
      );
}

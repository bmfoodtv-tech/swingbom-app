/// 문의 작성
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'package:flutter/material.dart';

import '../config/app_footer.dart';
import '../config/constants.dart';
import '../services/inquiry_service.dart';

class InquiryWriteScreen extends StatefulWidget {
  const InquiryWriteScreen({super.key});

  @override
  State<InquiryWriteScreen> createState() => _InquiryWriteScreenState();
}

class _InquiryWriteScreenState extends State<InquiryWriteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final res = await InquiryService.create(
      title: _title.text.trim(),
      content: _content.text.trim(),
    );

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
      appBar: AppBar(title: const Text('문의 작성')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              const Text(
                '앱 사용 중 불편하거나 궁금한 점을 남겨주세요.\n답변이 등록되면 문의 목록에 표시됩니다.',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSub, height: 1.5),
              ),
              const SizedBox(height: 20),

              const _Label('제목'),
              TextFormField(
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '예) 0.25배속 재생이 끊깁니다',
                  prefixIcon: Icon(Icons.title, size: 18),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return '제목을 입력하세요.';
                  if (s.length > 200) return '200자 이내로 입력하세요.';
                  return null;
                },
              ),
              const SizedBox(height: 18),

              const _Label('내용'),
              TextFormField(
                controller: _content,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: '사용 중인 기기, 어떤 상황에서 생기는지 적어주시면 확인이 빠릅니다.',
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return '문의 내용을 입력하세요.';
                  if (s.length > 5000) return '5000자 이내로 입력하세요.';
                  return null;
                },
              ),

              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send),
                label: const Text('문의 등록'),
              ),

              const SizedBox(height: 10),
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
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain)),
      );
}

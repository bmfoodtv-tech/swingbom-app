/// 클럽 / 뷰 선택 — "연습 시작" 진입 화면
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'package:flutter/material.dart';

import '../config/app_footer.dart';
import '../config/constants.dart';
import '../services/guide_service.dart';
import 'practice_screen.dart';

class ClubSelectScreen extends StatefulWidget {
  const ClubSelectScreen({super.key});

  @override
  State<ClubSelectScreen> createState() => _ClubSelectScreenState();
}

class _ClubSelectScreenState extends State<ClubSelectScreen> {
  ViewType _view = ViewType.side;
  ClubType _club = ClubType.driver;

  /// 서버에 저장된 조합 목록 → "가이드 있음" 배지 표시용
  Set<String> _saved = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final list = await GuideService.listSaved();
    if (!mounted) return;
    setState(() {
      _saved = list
          .map((e) => '${e['club_type']}_${e['view_type']}')
          .whereType<String>()
          .toSet();
      _loading = false;
    });
  }

  bool _hasGuide(ClubType c, ViewType v) => _saved.contains('${c.code}_${v.code}');

  Future<void> _start() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticeScreen(clubType: _club, viewType: _view),
      ),
    );
    if (mounted) _loadSaved(); // 돌아오면 저장 상태 갱신
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('연습 시작')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            const _Label('촬영 방향'),
            Row(
              children: ViewType.values.map((v) {
                final on = _view == v;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: v == ViewType.front ? 10 : 0),
                    child: _BigChip(
                      label: v.label,
                      icon: v == ViewType.front
                          ? Icons.accessibility_new
                          : Icons.directions_walk,
                      selected: on,
                      badge: _hasGuide(_club, v),
                      onTap: () => setState(() => _view = v),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 26),
            const _Label('클럽'),
            // 유틸/우드를 한 버튼으로 합쳐 4개 → 한 줄에 모두 표시
            Row(
              children: [
                for (final c in kSelectableClubs)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: c == kSelectableClubs.last ? 0 : 7),
                      child: _ClubChip(
                        label: c.label,
                        selected: _club == c,
                        badge: _hasGuide(c, _view),
                        onTap: () => setState(() => _club = c),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    _hasGuide(_club, _view)
                        ? Icons.check_circle
                        : Icons.brush_outlined,
                    color: _hasGuide(_club, _view)
                        ? AppColors.primary
                        : AppColors.textSub,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _loading
                          ? '저장된 가이드를 확인하는 중…'
                          : _hasGuide(_club, _view)
                              ? '${_view.label} · ${_club.label} 가이드가 저장돼 있습니다.\n촬영 화면에서 자동으로 불러옵니다.'
                              : '${_view.label} · ${_club.label} 가이드가 아직 없습니다.\n첫 스윙을 찍고 라인을 그려보세요.',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textSub, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.videocam),
              label: const Text('촬영 화면으로', style: TextStyle(fontSize: 16)),
            ),

            const SizedBox(height: 8),
            const AppFooter(),
          ],
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
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text(text,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain)),
      );
}

class _BigChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool badge;
  final VoidCallback onTap;

  const _BigChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 26,
                color: selected ? Colors.white : AppColors.textSub),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : AppColors.textMain,
              ),
            ),
            if (badge) ...[
              const SizedBox(height: 4),
              Text('가이드 있음',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: selected ? Colors.white70 : AppColors.primary,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClubChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool badge;
  final VoidCallback onTap;

  const _ClubChip({
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 62,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge)
              Icon(Icons.check_circle,
                  size: 13,
                  color: selected ? Colors.white : AppColors.primary),
            if (badge) const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

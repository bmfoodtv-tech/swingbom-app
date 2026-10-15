/// 연습일지 전체 목록 (기간 필터 · 삭제 · 수정 진입)
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'package:flutter/material.dart';

import '../config/app_footer.dart';
import '../config/constants.dart';
import '../models/practice_log.dart';
import '../services/log_service.dart';
import '../widgets/log_tile.dart';
import 'log_edit_screen.dart';

class LogListScreen extends StatefulWidget {
  const LogListScreen({super.key});

  @override
  State<LogListScreen> createState() => _LogListScreenState();
}

class _LogListScreenState extends State<LogListScreen> {
  bool _loading = true;
  String? _error;
  List<PracticeLog> _logs = const [];
  int _totalSwings = 0;
  int _totalDays = 0;

  DateTimeRange? _range;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final (page, res) = await LogService.list(
      from: _range == null ? null : _fmt(_range!.start),
      to: _range == null ? null : _fmt(_range!.end),
    );
    if (!mounted) return;

    if (page == null) {
      setState(() {
        _loading = false;
        _error = res.message;
      });
      return;
    }
    setState(() {
      _loading = false;
      _logs = page.logs;
      _totalSwings = page.totalSwings;
      _totalDays = page.totalDays;
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _range,
      helpText: '조회 기간 선택',
    );
    if (picked != null) {
      setState(() => _range = picked);
      _load();
    }
  }

  Future<void> _edit(PracticeLog log) async {
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => LogEditScreen(log: log)));
    if (changed == true) {
      _changed = true;
      _load();
    }
  }

  Future<void> _delete(PracticeLog log) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('연습일지 삭제'),
        content: Text('${log.practiceDate} 일지를 삭제할까요?'),
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

    final res = await LogService.delete(log.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.message),
      backgroundColor: res.success ? null : AppColors.danger,
    ));
    if (res.success) {
      _changed = true;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('연습일지'),
          actions: [
            IconButton(
              tooltip: '기간 선택',
              icon: const Icon(Icons.date_range),
              onPressed: _pickRange,
            ),
            if (_range != null)
              IconButton(
                tooltip: '기간 해제',
                icon: const Icon(Icons.filter_alt_off),
                onPressed: () {
                  setState(() => _range = null);
                  _load();
                },
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const LogEditScreen()));
            if (changed == true) {
              _changed = true;
              _load();
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('작성'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 합계 바
              Container(
                width: double.infinity,
                color: AppColors.primary.withValues(alpha: 0.06),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _range == null
                            ? '전체 기간'
                            : '${_fmt(_range!.start)} ~ ${_fmt(_range!.end)}',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSub),
                      ),
                    ),
                    Text(
                      '$_totalDays일 · $_totalSwings회',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!,
                                    style: const TextStyle(
                                        color: AppColors.danger)),
                                const SizedBox(height: 10),
                                OutlinedButton(
                                    onPressed: _load,
                                    child: const Text('다시 시도')),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: _logs.isEmpty
                                ? ListView(
                                    children: const [
                                      SizedBox(height: 100),
                                      Center(
                                        child: Text('해당 기간의 연습일지가 없습니다.',
                                            style: TextStyle(
                                                color: AppColors.textSub)),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    padding:
                                        const EdgeInsets.fromLTRB(16, 14, 16, 90),
                                    itemCount: _logs.length,
                                    itemBuilder: (_, i) => LogTile(
                                      log: _logs[i],
                                      onTap: () => _edit(_logs[i]),
                                      onDelete: () => _delete(_logs[i]),
                                    ),
                                  ),
                          ),
              ),
              const AppFooter(padding: EdgeInsets.only(bottom: 6, top: 2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 연습 화면 — 촬영 · 0.25배속 비교 · 가이드 드로잉/편집 (Phase 3~4 핵심)
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
///
/// 상태 흐름
///   [대기] ──(자동 시작)──▶ [녹화중] ──정지──▶ [검토: 0.25배속 + 가이드 오버레이]
///      ▲                                              │
///      └───────────────── 다음 스윙 ◀─────────────────┘
///
/// 저장 정책
///   · 녹화본은 **임시 폴더**에 만든다.
///   · 사용자가 [기기에 저장]을 누를 때만 갤러리(앨범 "스윙봄")에 저장한다.
///   · 저장하지 않고 다음 스윙으로 넘어가면 임시 파일은 삭제한다.
library;

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../config/constants.dart';
import '../models/shape.dart';
import '../models/swing_guide.dart';
import '../services/guide_service.dart';
import '../services/log_service.dart';
import '../services/overlay_export.dart';
import '../services/settings_service.dart';
import '../widgets/drawing_canvas.dart';
import 'log_edit_screen.dart';

enum _Stage { loading, preview, recording, review }

/// 재생 배속 (0.25배속이 기본)
const List<double> kSpeeds = [0.25, 0.5, 1.0, 2.0];

class PracticeScreen extends StatefulWidget {
  final ClubType clubType;
  final ViewType viewType;

  const PracticeScreen({
    super.key,
    required this.clubType,
    required this.viewType,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with WidgetsBindingObserver {
  // 카메라
  CameraController? _cam;
  List<CameraDescription> _cameras = const [];
  int _camIndex = 0;

  // 재생
  VideoPlayerController? _player;
  String? _videoPath;
  bool _savedToGallery = false;
  bool _savingVideo = false;
  double _speed = kSpeeds.first; // 0.25배속 기본

  // 상태
  _Stage _stage = _Stage.loading;
  String? _fatal;
  int _sessionSwings = 0;

  /// 오늘 일지에 기록된 누적 스윙 수 (서버 응답값)
  int _loggedSwings = 0;

  /// 대기 화면에 들어가면 셔터를 누르지 않아도 바로 녹화를 시작한다
  bool _autoRecord = true;

  /// 촬영 프레임 — 요청값(_fps)과 실제 적용된 값(_activeFps)
  int? _fps;
  int? _activeFps;

  /// 사용자가 실제로 라인을 그린 화면 폭 — 합성 시 선 굵기 비례에 쓴다
  Size? _stageSize;

  // 가이드
  late SwingGuide _guide;
  bool _guideDirty = false;
  bool _saving = false;

  // 드로잉 / 편집
  CanvasMode _mode = CanvasMode.view;
  ShapeType _tool = ShapeType.line;
  Color _color = kDrawColors.first;
  double _stroke = 3;
  int? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _guide = SwingGuide(clubType: widget.clubType, viewType: widget.viewType);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    _player?.dispose();
    super.dispose();
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      cam.dispose();
    } else if (state == AppLifecycleState.resumed && _stage == _Stage.preview) {
      // 복귀 시에는 놀라지 않도록 자동 녹화를 걸지 않는다
      _initCamera(_camIndex, autoStart: false);
    }
  }

  // ── 초기화 ──────────────────────────────────────────────
  Future<void> _boot() async {
    _fps = await SettingsService.loadFps();
    _autoRecord = await SettingsService.loadAutoRecord();
    unawaited(_cleanupTempSwings());

    final loaded = await GuideService.load(widget.clubType, widget.viewType);
    if (!mounted) return;
    setState(() => _guide = loaded.guide);
    if (loaded.warning != null) _toast(loaded.warning!);

    final granted = await Permission.camera.request();
    if (!mounted) return;
    if (!granted.isGranted) {
      setState(() {
        _stage = _Stage.preview;
        _fatal = '카메라 권한이 필요합니다.\n설정에서 권한을 허용한 뒤 다시 들어와 주세요.';
      });
      return;
    }

    try {
      _cameras = await availableCameras();
    } catch (_) {
      _cameras = const [];
    }
    if (_cameras.isEmpty) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.preview;
        _fatal = '사용 가능한 카메라를 찾지 못했습니다.';
      });
      return;
    }

    _camIndex =
        _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    if (_camIndex < 0) _camIndex = 0;

    await _initCamera(_camIndex, autoStart: _autoRecord);
  }

  Future<void> _initCamera(int index, {required bool autoStart}) async {
    await _disposeCam();

    // 요청한 프레임이 기기에서 안 되면 단계적으로 낮춰 재시도한다.
    // (고프레임은 기종·해상도에 따라 초기화 자체가 실패할 수 있다)
    final candidates = <int?>[];
    for (final f in <int?>[_fps, 60, null]) {
      if (!candidates.contains(f)) candidates.add(f);
    }

    CameraController? ok;
    int? okFps;
    Object? lastErr;

    for (final f in candidates) {
      final c = CameraController(
        _cameras[index],
        ResolutionPreset.high,
        enableAudio: false, // 스윙 영상에 소리는 불필요 → 마이크 권한도 요구하지 않음
        fps: f,
      );
      try {
        await c.initialize();
        ok = c;
        okFps = f;
        break;
      } catch (e) {
        lastErr = e;
        try {
          await c.dispose();
        } catch (_) {/* 무시 */}
      }
    }

    if (ok == null) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.preview;
        _fatal = '카메라를 시작하지 못했습니다.'
            '\n$lastErr';
      });
      return;
    }
    if (!mounted) {
      await ok.dispose();
      return;
    }

    final downgraded = okFps != _fps;
    setState(() {
      _cam = ok;
      _camIndex = index;
      _activeFps = okFps;
      _fatal = null;
      _stage = _Stage.preview;
    });
    if (downgraded) {
      _toast(okFps == null
          ? '${FpsOption.fromFps(_fps).label} 촬영을 지원하지 않아 기기 기본값으로 촬영합니다.'
          : '${FpsOption.fromFps(_fps).label} 촬영을 지원하지 않아 ${okFps}fps로 촬영합니다.');
    }

    if (autoStart) await _startRecording();
  }

  Future<void> _disposeCam() async {
    final c = _cam;
    _cam = null;
    if (c == null) return;
    try {
      if (c.value.isRecordingVideo) await c.stopVideoRecording();
    } catch (_) {/* 무시 */}
    try {
      await c.dispose();
    } catch (_) {/* 무시 */}
  }

  /// 지난 세션에서 저장하지 않고 남은 임시 영상 정리
  Future<void> _cleanupTempSwings() async {
    try {
      final dir = await getTemporaryDirectory();
      final swingDir = Directory('${dir.path}/swb_swings');
      if (!swingDir.existsSync()) return;
      final cutoff = DateTime.now().subtract(const Duration(hours: 6));
      for (final f in swingDir.listSync().whereType<File>()) {
        if (f.statSync().modified.isBefore(cutoff)) {
          try {
            await f.delete();
          } catch (_) {/* 무시 */}
        }
      }
    } catch (_) {/* 무시 */}
  }

  Future<void> _changeFps(int? fps) async {
    if (fps == _fps) return;
    setState(() {
      _fps = fps;
      _stage = _Stage.loading;
    });
    await SettingsService.saveFps(fps);
    await _initCamera(_camIndex, autoStart: false);
  }

  Future<void> _toggleAutoRecord() async {
    final next = !_autoRecord;
    setState(() => _autoRecord = next);
    await SettingsService.saveAutoRecord(next);
  }

  /// 전/후면 카메라 전환.
  /// 자동 녹화 때문에 곧바로 녹화 상태로 들어가므로, **녹화 중에도** 전환할 수 있어야 한다.
  /// 녹화 중이면 현재 촬영본을 버리고 전환한 뒤, 자동 녹화면 다시 시작한다.
  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;

    final wasRecording = _cam?.value.isRecordingVideo ?? false;
    if (wasRecording) {
      try {
        final f = await _cam!.stopVideoRecording();
        await _safeDelete(f.path); // 전환 전 촬영본은 버린다
      } catch (_) {/* 무시 */}
      _toast('카메라를 전환하고 다시 촬영합니다.');
    }

    setState(() => _stage = _Stage.loading);
    await _initCamera(
      (_camIndex + 1) % _cameras.length,
      autoStart: wasRecording || _autoRecord,
    );
  }

  // ── 녹화 ────────────────────────────────────────────────
  Future<void> _startRecording() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) return;
    if (cam.value.isRecordingVideo) return;
    try {
      await cam.startVideoRecording();
      if (!mounted) return;
      setState(() => _stage = _Stage.recording);
    } catch (_) {
      _toast('녹화를 시작하지 못했습니다.');
    }
  }

  Future<void> _stopRecording() async {
    final cam = _cam;
    if (cam == null || !cam.value.isRecordingVideo) return;
    try {
      final file = await cam.stopVideoRecording();

      // 임시 폴더에 보관 — 갤러리 저장은 사용자가 [기기에 저장]을 누를 때만
      final dir = await getTemporaryDirectory();
      final swingDir = Directory('${dir.path}/swb_swings');
      if (!swingDir.existsSync()) swingDir.createSync(recursive: true);
      final path =
          '${swingDir.path}/swing_${DateTime.now().millisecondsSinceEpoch}.mp4';
      await File(file.path).copy(path);
      await _safeDelete(file.path);

      await _openPlayer(path);

      // 스윙 1회를 오늘 연습일지에 바로 누적한다.
      // (대시보드 통계가 "연습을 하면 바로" 반영되도록 — 서버가 오늘 일지를 만들거나 더한다)
      unawaited(_bumpTodayLog());

      if (!mounted) return;
      setState(() {
        _videoPath = path;
        _savedToGallery = false;
        _sessionSwings++;
        _stage = _Stage.review;
        _selected = null;
        // 가이드가 없으면 바로 그리기, 있으면 0.25배속 비교부터
        _mode = _guide.isEmpty ? CanvasMode.draw : CanvasMode.view;
      });
    } catch (_) {
      _toast('녹화를 저장하지 못했습니다.');
      if (mounted) setState(() => _stage = _Stage.preview);
    }
  }

  Future<void> _openPlayer(String path) async {
    await _player?.dispose();
    final p = VideoPlayerController.file(File(path));
    await p.initialize();
    await p.setLooping(true);
    await p.setPlaybackSpeed(_speed);
    await p.seekTo(Duration.zero);
    if (!mounted) {
      await p.dispose();
      return;
    }
    setState(() => _player = p);
    // 가이드가 있으면 촬영 직후 곧바로 0.25배속으로 비교 재생
    if (!_guide.isEmpty) await p.play();
  }

  Future<void> _setSpeed(double s) async {
    setState(() => _speed = s);
    await _player?.setPlaybackSpeed(s);
  }

  Future<void> _safeDelete(String path) async {
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {/* 무시 */}
  }

  // ── 기기(갤러리) 저장 — 사용자가 누를 때만 ────────────────
  Future<bool> _ensureGalleryAccess() async {
    if (await Gal.hasAccess(toAlbum: true)) return true;
    final ok = await Gal.requestAccess(toAlbum: true);
    if (!ok) _toast('사진 저장 권한이 필요합니다.');
    return ok;
  }

  /// [기기에 저장] — 원본 / 가이드 합성 중 선택
  Future<void> _showSaveOptions() async {
    if (_videoPath == null || _savingVideo) return;

    final hasGuide = _guide.shapes.isNotEmpty;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('기기에 저장',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white70),
              title: const Text('원본 영상',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('촬영한 그대로 저장 (빠름)',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              onTap: () => Navigator.pop(c, 'original'),
            ),
            ListTile(
              enabled: hasGuide,
              leading: Icon(Icons.layers,
                  color: hasGuide ? AppColors.primaryLight : Colors.white24),
              title: Text('가이드 합성 영상',
                  style: TextStyle(
                      color: hasGuide ? Colors.white : Colors.white38,
                      fontSize: 14)),
              subtitle: Text(
                  hasGuide
                      ? '라인이 영상에 그대로 박힙니다 (변환에 시간이 걸립니다)'
                      : '그려둔 가이드가 없습니다',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
              onTap: hasGuide ? () => Navigator.pop(c, 'guided') : null,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == 'original') await _saveOriginal();
    if (choice == 'guided') await _saveComposited();
  }

  Future<void> _saveOriginal() async {
    final path = _videoPath;
    if (path == null) return;

    setState(() => _savingVideo = true);
    try {
      if (!await _ensureGalleryAccess()) return;
      await Gal.putVideo(path, album: kAppName);
      if (!mounted) return;
      setState(() => _savedToGallery = true);
      _toast('갤러리 "$kAppName" 앨범에 저장했습니다.');
    } on GalException catch (e) {
      _toast('기기 저장 실패: ${e.type.message}');
    } catch (_) {
      _toast('기기에 저장하지 못했습니다.');
    } finally {
      if (mounted) setState(() => _savingVideo = false);
    }
  }

  /// 가이드 라인을 영상에 구워서 저장 (Phase 5)
  Future<void> _saveComposited() async {
    final path = _videoPath;
    final player = _player;
    if (path == null || player == null) return;

    setState(() => _savingVideo = true);
    _toast('가이드를 영상에 합성하는 중입니다…');

    String? outPath;
    try {
      if (!await _ensureGalleryAccess()) return;

      final res = await OverlayExport.burnGuide(
        videoPath: path,
        shapes: _guide.shapes,
        videoSize: player.value.size,
        stageWidth: _stageSize?.width,
      );
      if (!res.success) {
        _toast(res.error ?? '영상 합성에 실패했습니다.');
        return;
      }
      outPath = res.path;

      await Gal.putVideo(outPath!, album: kAppName);
      if (!mounted) return;
      setState(() => _savedToGallery = true);
      _toast('가이드 합성 영상을 "$kAppName" 앨범에 저장했습니다.');
    } on GalException catch (e) {
      _toast('기기 저장 실패: ${e.type.message}');
    } catch (_) {
      _toast('합성 영상을 저장하지 못했습니다.');
    } finally {
      if (outPath != null) await _safeDelete(outPath);
      if (mounted) setState(() => _savingVideo = false);
    }
  }

  // ── 다음 스윙 ───────────────────────────────────────────
  Future<void> _nextSwing() async {
    if (_guideDirty && (await _confirmDiscard()) != true) return;

    await _player?.dispose();
    // 저장하지 않은 영상은 남기지 않는다
    if (_videoPath != null && !_savedToGallery) await _safeDelete(_videoPath!);

    if (!mounted) return;
    setState(() {
      _player = null;
      _videoPath = null;
      _savedToGallery = false;
      _selected = null;
      _mode = CanvasMode.view;
      _stage = _Stage.preview;
    });

    if (_autoRecord) await _startRecording();
  }

  Future<bool?> _confirmDiscard() => showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('저장하지 않은 가이드'),
          content: const Text('수정한 가이드가 아직 저장되지 않았습니다.\n저장하지 않고 넘어갈까요?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('저장 안 함',
                  style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      );

  /// 뒤로가기 — 미저장 가이드 + 연습 카운트 반영 안내
  Future<void> _handleBack() async {
    if (_guideDirty && (await _confirmDiscard()) != true) return;
    if (_videoPath != null && !_savedToGallery) await _safeDelete(_videoPath!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ── 연습 카운트 → 연습일지 ────────────────────────────────
  /// 스윙 1회를 오늘 일지에 누적 (없으면 서버가 오늘 일지를 새로 만든다)
  Future<void> _bumpTodayLog() async {
    final res = await LogService.bump(count: 1);
    if (!mounted) return;
    if (!res.success) {
      // 통계 누적 실패가 촬영을 막지는 않는다. 알리기만 한다.
      _toast('연습일지에 기록하지 못했습니다. ${res.message}');
      return;
    }
    setState(() =>
        _loggedSwings = (res.data['swing_count'] as num?)?.toInt() ?? 0);
  }

  String _todayStr() {
    final t = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}';
  }

  /// 오늘 일지 열기 — 장소·메모를 채우거나 카운트를 손볼 때.
  /// 스윙 수는 이미 자동 누적되어 있으므로 **기존 일지를 불러와 수정**한다.
  Future<void> _openTodayLog() async {
    final log = await LogService.byDate(_todayStr());
    if (!mounted) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LogEditScreen(log: log)),
    );
    if (saved == true && mounted) {
      _toast('연습일지를 저장했습니다.');
      unawaited(_refreshLoggedCount());
    }
  }

  Future<void> _refreshLoggedCount() async {
    final log = await LogService.byDate(_todayStr());
    if (mounted && log != null) setState(() => _loggedSwings = log.swingCount);
  }

  // ── 드로잉 / 편집 ────────────────────────────────────────
  void _addShape(Shape s) {
    setState(() {
      _guide = _guide.copyWith(shapes: [..._guide.shapes, s]);
      _guideDirty = true;
    });
  }

  void _updateShape(int index, Shape s) {
    if (index < 0 || index >= _guide.shapes.length) return;
    final list = [..._guide.shapes];
    list[index] = s;
    setState(() {
      _guide = _guide.copyWith(shapes: list);
      _guideDirty = true;
    });
  }

  void _deleteSelected() {
    final i = _selected;
    if (i == null || i < 0 || i >= _guide.shapes.length) return;
    final list = [..._guide.shapes]..removeAt(i);
    setState(() {
      _guide = _guide.copyWith(shapes: list);
      _selected = null;
      _guideDirty = true;
    });
  }

  /// 편집 모드에서 색/굵기를 바꾸면 선택된 도형에 즉시 적용된다
  void _applyStyleToSelected({Color? color, double? stroke}) {
    final i = _selected;
    if (_mode != CanvasMode.edit || i == null) return;
    if (i < 0 || i >= _guide.shapes.length) return;
    final s = _guide.shapes[i].copyWith(
      colorValue: color?.toARGB32(),
      strokeWidth: stroke,
    );
    _updateShape(i, s);
  }

  void _undo() {
    if (_guide.shapes.isEmpty) return;
    setState(() {
      _guide = _guide.copyWith(
          shapes: _guide.shapes.sublist(0, _guide.shapes.length - 1));
      _selected = null;
      _guideDirty = true;
    });
  }

  Future<void> _clearAll() async {
    if (_guide.shapes.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('전체 지우기'),
        content: Text('${_guide.shapes.length}개 도형을 모두 지울까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('지우기', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _guide = _guide.copyWith(shapes: const []);
      _selected = null;
      _guideDirty = true;
    });
  }

  Future<void> _saveGuide() async {
    setState(() => _saving = true);
    final res = await GuideService.save(_guide);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (res.success) _guideDirty = false;
    });
    _toast(res.success
        ? '가이드를 저장했습니다. (${_guide.shapes.length}개 도형)'
        : '기기에는 저장했지만 서버 저장에 실패했습니다. ${res.message}');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── 화면 ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(
            '${widget.viewType.label} · ${widget.clubType.label}',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            IconButton(
              tooltip: _autoRecord ? '자동 녹화 켜짐' : '자동 녹화 꺼짐',
              icon: Icon(_autoRecord ? Icons.bolt : Icons.bolt_outlined,
                  color: _autoRecord ? AppColors.accent : Colors.white54),
              onPressed: _toggleAutoRecord,
            ),
            PopupMenuButton<int?>(
              tooltip: '촬영 프레임',
              color: const Color(0xFF1E1E1E),
              icon: const Icon(Icons.speed_outlined),
              initialValue: _fps,
              onSelected: _changeFps,
              itemBuilder: (_) => FpsOption.all
                  .map((o) => PopupMenuItem<int?>(
                        value: o.fps,
                        child: Row(
                          children: [
                            Icon(
                              o.fps == _fps
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 16,
                              color: o.fps == _fps
                                  ? AppColors.primaryLight
                                  : Colors.white38,
                            ),
                            const SizedBox(width: 9),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(o.label,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13)),
                                Text(o.hint,
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 10.5)),
                              ],
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            if (_cameras.length > 1 &&
                (_stage == _Stage.preview || _stage == _Stage.recording))
              IconButton(
                tooltip: '전/후면 전환',
                icon: const Icon(Icons.cameraswitch),
                onPressed: _flipCamera,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Text('스윙 $_sessionSwings',
                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: _buildStage()),
              _buildControls(),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  kCopyright,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 영상/프리뷰 + 가이드 오버레이 (둘의 좌표계를 정확히 일치시킨다)
  Widget _buildStage() {
    if (_fatal != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white38, size: 44),
              const SizedBox(height: 14),
              Text(_fatal!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.5)),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => openAppSettings(),
                icon: const Icon(Icons.settings),
                label: const Text('앱 설정 열기'),
              ),
            ],
          ),
        ),
      );
    }

    if (_stage == _Stage.loading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white70));
    }

    final isReview = _stage == _Stage.review && _player != null;
    final aspect = isReview
        ? _player!.value.aspectRatio
        : (_cam != null && _cam!.value.isInitialized
            ? 1 / _cam!.value.aspectRatio
            : 9 / 16);

    return Center(
      child: AspectRatio(
        aspectRatio: aspect,
        child: LayoutBuilder(builder: (context, box) {
          _stageSize = Size(box.maxWidth, box.maxHeight);
          return Stack(
          fit: StackFit.expand,
          children: [
            if (isReview)
              GestureDetector(
                onTap: _mode == CanvasMode.view ? _togglePlay : null,
                child: VideoPlayer(_player!),
              )
            else if (_cam != null && _cam!.value.isInitialized)
              CameraPreview(_cam!)
            else
              const ColoredBox(color: Colors.black),

            DrawingCanvas(
              shapes: _guide.shapes,
              mode: isReview ? _mode : CanvasMode.view,
              tool: _tool,
              color: _color,
              strokeWidth: _stroke,
              onShapeAdded: _addShape,
              selectedIndex: _selected,
              onSelectionChanged: (i) => setState(() => _selected = i),
              onShapeUpdated: _updateShape,
            ),

            if (_stage == _Stage.recording)
              const Positioned(top: 12, left: 12, child: _RecBadge()),

            // 촬영 화면 위 전/후면 전환 (앱바보다 손이 닿기 쉽다)
            if (!isReview && _cameras.length > 1)
              Positioned(
                right: 12,
                bottom: 12,
                child: _RoundIconButton(
                  icon: Icons.cameraswitch,
                  tooltip: '전/후면 전환',
                  onTap: _flipCamera,
                ),
              ),

            if (isReview)
              Positioned(
                top: 12,
                left: 12,
                child: _Chip(
                    text: '${_fmtSpeed(_speed)} 재생',
                    icon: Icons.slow_motion_video),
              ),

            if (_stage == _Stage.preview && _guide.shapes.isNotEmpty)
              Positioned(
                top: 12,
                left: 12,
                child: _Chip(
                    text: '저장된 가이드 ${_guide.shapes.length}개',
                    icon: Icons.check_circle),
              ),
            ],
          );
        }),
      ),
    );
  }

  void _togglePlay() {
    final p = _player;
    if (p == null) return;
    p.value.isPlaying ? p.pause() : p.play();
    setState(() {});
  }

  static String _fmtSpeed(double s) =>
      s == s.roundToDouble() ? '${s.toInt()}배속' : '$s배속';

  Widget _buildControls() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: switch (_stage) {
        _Stage.review => _reviewControls(),
        _Stage.recording => _recordingControls(),
        _ => _previewControls(),
      },
    );
  }

  // 대기 화면
  Widget _previewControls() {
    final ready = _cam != null && _cam!.value.isInitialized;
    return Column(
      children: [
        Text(
          [
            _autoRecord ? '자동 녹화 켜짐 · 바로 촬영이 시작됩니다' : '셔터를 눌러 녹화를 시작하세요',
            _activeFps == null ? '기기 기본 프레임' : '${_activeFps}fps 촬영',
          ].join('  ·  '),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, color: Colors.white54),
        ),
        const SizedBox(height: 8),
        _ShutterButton(onTap: ready ? _startRecording : null),
        if (_sessionSwings > 0)
          TextButton.icon(
            onPressed: _openTodayLog,
            icon: const Icon(Icons.edit_note, size: 18),
            label: Text(
                '오늘 연습일지 (${_loggedSwings > 0 ? _loggedSwings : _sessionSwings}회 기록됨)'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryLight),
          )
        else
          const SizedBox(height: 6),
      ],
    );
  }

  Widget _recordingControls() {
    return Column(
      children: [
        const Text('녹화 중 — 스윙 후 정지를 누르세요',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 8),
        _ShutterButton(recording: true, onTap: _stopRecording),
        const SizedBox(height: 6),
      ],
    );
  }

  // 검토 화면
  Widget _reviewControls() {
    final p = _player;
    final hasSelection = _mode == CanvasMode.edit && _selected != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (p != null) _Scrubber(controller: p),

        // 배속 선택 (0.25배속 기본)
        _SpeedBar(speed: _speed, onChanged: _setSpeed),

        const SizedBox(height: 6),

        // 모드 전환
        Row(
          children: [
            Expanded(
              child: SegmentedButton<CanvasMode>(
                style: SegmentedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E1E),
                  foregroundColor: Colors.white70,
                  selectedBackgroundColor: AppColors.primaryLight,
                  selectedForegroundColor: Colors.black,
                  side: const BorderSide(color: Color(0xFF333333)),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                segments: const [
                  ButtonSegment(
                      value: CanvasMode.view,
                      icon: Icon(Icons.visibility, size: 16),
                      label: Text('비교', style: TextStyle(fontSize: 12))),
                  ButtonSegment(
                      value: CanvasMode.draw,
                      icon: Icon(Icons.brush, size: 16),
                      label: Text('그리기', style: TextStyle(fontSize: 12))),
                  ButtonSegment(
                      value: CanvasMode.edit,
                      icon: Icon(Icons.open_with, size: 16),
                      label: Text('수정', style: TextStyle(fontSize: 12))),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() {
                  _mode = s.first;
                  _selected = null;
                }),
              ),
            ),
            IconButton(
              tooltip: '되돌리기',
              onPressed: _guide.shapes.isEmpty ? null : _undo,
              icon: const Icon(Icons.undo),
              color: Colors.white,
              disabledColor: Colors.white24,
            ),
            IconButton(
              tooltip: '전체 지우기',
              onPressed: _guide.shapes.isEmpty ? null : _clearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
              color: Colors.white,
              disabledColor: Colors.white24,
            ),
          ],
        ),

        if (_mode == CanvasMode.edit)
          _EditHint(
            hasSelection: hasSelection,
            onDelete: _deleteSelected,
          ),

        if (_mode == CanvasMode.draw || hasSelection) ...[
          const SizedBox(height: 4),
          _ToolBar(
            showTools: _mode == CanvasMode.draw,
            tool: _tool,
            color: _color,
            stroke: _stroke,
            onTool: (t) => setState(() => _tool = t),
            onColor: (c) {
              setState(() => _color = c);
              _applyStyleToSelected(color: c);
            },
            onStroke: (s) {
              setState(() => _stroke = s);
              _applyStyleToSelected(stroke: s);
            },
          ),
        ],

        const SizedBox(height: 8),

        // 기기 저장 · 가이드 저장
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _savingVideo ? null : _showSaveOptions,
                icon: _savingVideo
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white70)),
                      )
                    : Icon(
                        _savedToGallery
                            ? Icons.check_circle
                            : Icons.download_for_offline_outlined,
                        size: 18),
                label: Text(_savedToGallery ? '저장됨' : '기기에 저장',
                    style: const TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _savedToGallery ? AppColors.primaryLight : Colors.white,
                  side: const BorderSide(color: Color(0xFF444444)),
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveGuide,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : Icon(_guideDirty ? Icons.save : Icons.check, size: 18),
                label: Text(_guideDirty ? '가이드 저장' : '가이드 저장됨',
                    style: const TextStyle(fontSize: 13)),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: _guideDirty
                      ? AppColors.primaryLight
                      : const Color(0xFF2E2E2E),
                  foregroundColor: _guideDirty ? Colors.black : Colors.white54,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            onPressed: _nextSwing,
            icon: const Icon(Icons.replay, size: 18),
            label: Text(_autoRecord ? '다음 스윙 (바로 녹화)' : '다음 스윙'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF444444)),
              minimumSize: const Size.fromHeight(40),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ── 부품 위젯 ─────────────────────────────────────────────

class _ShutterButton extends StatelessWidget {
  final bool recording;
  final VoidCallback? onTap;

  const _ShutterButton({this.recording = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: onTap == null ? Colors.white24 : Colors.white, width: 3),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: recording ? 24 : 46,
            height: recording ? 24 : 46,
            decoration: BoxDecoration(
              color: onTap == null ? Colors.white24 : AppColors.danger,
              borderRadius: BorderRadius.circular(recording ? 5 : 23),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.black54,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const Padding(
              padding: EdgeInsets.all(11),
              child: Icon(Icons.cameraswitch, color: Colors.white, size: 22),
            ),
          ),
        ),
      );
}

class _RecBadge extends StatelessWidget {
  const _RecBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fiber_manual_record, color: AppColors.danger, size: 12),
            SizedBox(width: 5),
            Text('REC',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Chip({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primaryLight, size: 13),
            const SizedBox(width: 5),
            Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      );
}

/// 배속 선택 — 0.25배속이 기본
class _SpeedBar extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onChanged;

  const _SpeedBar({required this.speed, required this.onChanged});

  String _label(double s) => s == s.roundToDouble() ? '${s.toInt()}x' : '${s}x';

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.speed, size: 15, color: Colors.white38),
        const SizedBox(width: 8),
        ...kSpeeds.map((s) {
          final on = (s - speed).abs() < 0.001;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onChanged(s),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  color: on ? AppColors.primaryLight : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _label(s),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: on ? FontWeight.bold : FontWeight.normal,
                    color: on ? Colors.black : Colors.white70,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// 편집 모드 안내 + 선택 도형 삭제
class _EditHint extends StatelessWidget {
  final bool hasSelection;
  final VoidCallback onDelete;

  const _EditHint({required this.hasSelection, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hasSelection
                  ? '도형을 끌어 이동 · 끝점 핸들을 끌어 크기 조절'
                  : '수정할 도형을 화면에서 눌러 선택하세요',
              style: const TextStyle(fontSize: 11.5, color: Colors.white54),
            ),
          ),
          if (hasSelection)
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('선택 삭제', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

/// 프레임 스크럽바 — 원하는 프레임에서 멈춰 가이드를 그린다
class _Scrubber extends StatefulWidget {
  final VideoPlayerController controller;
  const _Scrubber({required this.controller});

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_tick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_tick);
    super.dispose();
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  String _fmt(Duration d) {
    final ms = (d.inMilliseconds % 1000) ~/ 100;
    return '${d.inSeconds}.${ms}s';
  }

  Future<void> _step(int ms) async {
    final v = widget.controller.value;
    await widget.controller.pause();
    final next = v.position + Duration(milliseconds: ms);
    await widget.controller.seekTo(
      next < Duration.zero
          ? Duration.zero
          : (next > v.duration ? v.duration : next),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.controller.value;
    final total = v.duration.inMilliseconds.clamp(1, 1 << 30);
    final pos = v.position.inMilliseconds.clamp(0, total);

    return Row(
      children: [
        IconButton(
          tooltip: '이전 프레임',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.keyboard_arrow_left),
          color: Colors.white70,
          onPressed: () => _step(-50),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(v.isPlaying ? Icons.pause : Icons.play_arrow),
          color: Colors.white,
          onPressed: () async {
            if (v.isPlaying) {
              await widget.controller.pause();
            } else {
              await widget.controller.play();
            }
          },
        ),
        IconButton(
          tooltip: '다음 프레임',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.keyboard_arrow_right),
          color: Colors.white70,
          onPressed: () => _step(50),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: AppColors.primaryLight,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: pos.toDouble(),
              max: total.toDouble(),
              onChanged: (val) async {
                await widget.controller.pause();
                await widget.controller
                    .seekTo(Duration(milliseconds: val.round()));
              },
            ),
          ),
        ),
        SizedBox(
          width: 66,
          child: Text(
            '${_fmt(v.position)} / ${_fmt(v.duration)}',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 10.5, color: Colors.white54),
          ),
        ),
      ],
    );
  }
}

/// 드로잉 툴바 — 도구 / 색상 / 굵기
class _ToolBar extends StatelessWidget {
  final bool showTools;
  final ShapeType tool;
  final Color color;
  final double stroke;
  final ValueChanged<ShapeType> onTool;
  final ValueChanged<Color> onColor;
  final ValueChanged<double> onStroke;

  const _ToolBar({
    required this.showTools,
    required this.tool,
    required this.color,
    required this.stroke,
    required this.onTool,
    required this.onColor,
    required this.onStroke,
  });

  IconData _icon(ShapeType t) => switch (t) {
        ShapeType.line => Icons.show_chart,
        ShapeType.freehand => Icons.gesture,
        ShapeType.circle => Icons.circle_outlined,
        ShapeType.rect => Icons.crop_square,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showTools) ...[
          Row(
            children: ShapeType.values.map((t) {
              final on = t == tool;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onTool(t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            on ? AppColors.primaryLight : const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Icon(_icon(t),
                              size: 17,
                              color: on ? Colors.black : Colors.white70),
                          const SizedBox(height: 1),
                          Text(t.label,
                              style: TextStyle(
                                  fontSize: 9.5,
                                  color: on ? Colors.black : Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            ...kDrawColors.map((c) {
              final on = c.toARGB32() == color.toARGB32();
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onColor(c),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: on ? Colors.white : Colors.white24,
                        width: on ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 4),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  activeTrackColor: Colors.white70,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: stroke,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '굵기 ${stroke.toInt()}',
                  onChanged: onStroke,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

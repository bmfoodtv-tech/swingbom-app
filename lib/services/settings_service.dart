/// 촬영 환경설정 (기기별로 기억)
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'local_store.dart';

/// 촬영 프레임 옵션.
/// 0.25배속으로 볼 때 부드러움이 크게 달라진다.
///   60fps  → 0.25배속에서 초당 15프레임
///   120fps → 0.25배속에서 초당 30프레임 (권장)
class FpsOption {
  final int? fps; // null = 기기 기본값(자동)
  final String label;
  final String hint;

  const FpsOption(this.fps, this.label, this.hint);

  static const auto = FpsOption(null, '자동', '기기 기본 프레임');
  static const f60 = FpsOption(60, '60fps', '0.25배속에서 초당 15프레임');
  static const f120 = FpsOption(120, '120fps', '0.25배속에서 초당 30프레임 · 권장');
  static const f240 = FpsOption(240, '240fps', '지원 기기에서만 동작');

  static const List<FpsOption> all = [auto, f60, f120, f240];

  static FpsOption fromFps(int? v) =>
      all.firstWhere((e) => e.fps == v, orElse: () => auto);
}

class SettingsService {
  static const _kFps = 'swb_pref_fps';
  static const _kAutoRecord = 'swb_pref_auto_record';

  /// 촬영 프레임 (기본 120fps — 슬로모션 품질 우선)
  static Future<int?> loadFps() async {
    final raw = await LocalStore.read(_kFps);
    if (raw == null) return FpsOption.f120.fps;
    if (raw == 'auto') return null;
    return int.tryParse(raw);
  }

  static Future<void> saveFps(int? fps) =>
      LocalStore.write(_kFps, fps == null ? 'auto' : '$fps');

  /// 자동 녹화 시작 (기본 켜짐)
  static Future<bool> loadAutoRecord() async {
    final raw = await LocalStore.read(_kAutoRecord);
    return raw == null ? true : raw == '1';
  }

  static Future<void> saveAutoRecord(bool on) =>
      LocalStore.write(_kAutoRecord, on ? '1' : '0');
}

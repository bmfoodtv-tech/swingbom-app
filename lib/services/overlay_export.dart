/// 가이드 라인 합성 영상 만들기 (Phase 5)
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
///
/// 처리 흐름
///   1) 가이드 도형을 **영상 해상도 그대로** 투명 PNG 로 렌더링
///   2) ffmpeg overlay 필터로 원본 영상 위에 굽는다
///   3) 결과 mp4 경로를 돌려준다 (갤러리 저장은 호출한 쪽에서)
///
/// 화면과 같은 `paintGuideShapes()` 를 쓰므로 라인 위치가 어긋나지 않는다.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/shape.dart';
import '../widgets/guide_painting.dart';

class OverlayExportResult {
  final String? path;
  final String? error;

  const OverlayExportResult.ok(this.path) : error = null;
  const OverlayExportResult.fail(this.error) : path = null;

  bool get success => path != null;
}

class OverlayExport {
  /// 가이드 도형을 투명 PNG 바이트로 렌더링한다.
  ///
  /// [size] 는 영상 픽셀 크기. [stageWidth] 는 사용자가 실제로 그렸던
  /// 화면 폭으로, 선 굵기를 영상 크기에 비례해 키우는 데 쓴다.
  static Future<Uint8List?> renderGuidePng({
    required List<Shape> shapes,
    required Size size,
    double? stageWidth,
  }) async {
    if (shapes.isEmpty) return null;
    if (size.width < 2 || size.height < 2) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size.width, size.height),
    );

    final ref = (stageWidth == null || stageWidth < 1)
        ? kGuideRefWidth
        : stageWidth;
    paintGuideShapes(
      canvas,
      size,
      shapes,
      strokeScale: size.width / ref,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.round(),
      size.height.round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    return data?.buffer.asUint8List();
  }

  /// 원본 영상 위에 가이드를 구워 새 mp4 를 만든다.
  static Future<OverlayExportResult> burnGuide({
    required String videoPath,
    required List<Shape> shapes,
    required Size videoSize,
    double? stageWidth,
  }) async {
    if (shapes.isEmpty) {
      return const OverlayExportResult.fail('합성할 가이드 라인이 없습니다.');
    }

    final w = videoSize.width.round();
    final h = videoSize.height.round();
    if (w < 2 || h < 2) {
      return const OverlayExportResult.fail('영상 크기를 확인하지 못했습니다.');
    }

    final png = await renderGuidePng(
      shapes: shapes,
      size: Size(w.toDouble(), h.toDouble()),
      stageWidth: stageWidth,
    );
    if (png == null) {
      return const OverlayExportResult.fail('가이드 이미지를 만들지 못했습니다.');
    }

    final tmp = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final pngPath = '${tmp.path}/swb_overlay_$stamp.png';
    final outPath = '${tmp.path}/swb_guided_$stamp.mp4';

    try {
      await File(pngPath).writeAsBytes(png, flush: true);

      // overlay 는 원본과 같은 크기로 맞춘 뒤 좌상단(0,0)에 얹는다.
      // 원본에 회전 메타데이터가 있어도 ffmpeg 가 필터 전에 자동 회전을 적용하므로
      // videoSize(표시 기준 크기)와 일치한다.
      const filter =
          '[1:v]scale=W_:H_[ov];[0:v][ov]overlay=0:0:format=auto';

      // 기기에 따라 특정 인코더가 없을 수 있어 순서대로 시도한다.
      const encoders = [
        '-c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p',
        '-c:v mpeg4 -q:v 3',
      ];

      String? lastLog;
      for (final enc in encoders) {
        final cmd = '-y '
            '-i "$videoPath" '
            '-i "$pngPath" '
            '-filter_complex "${filter.replaceFirst('W_', '$w').replaceFirst('H_', '$h')}" '
            '$enc '
            '-movflags +faststart -an '
            '"$outPath"';

        final session = await FFmpegKit.execute(cmd);
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc)) {
          return OverlayExportResult.ok(outPath);
        }
        lastLog = await session.getAllLogsAsString();
      }

      final tail = (lastLog ?? '').trim();
      return OverlayExportResult.fail(
        '영상 합성에 실패했습니다.'
        '${tail.isEmpty ? '' : ' (${tail.substring(tail.length > 180 ? tail.length - 180 : 0)})'}',
      );
    } catch (e) {
      return OverlayExportResult.fail('영상 합성 중 오류가 발생했습니다. $e');
    } finally {
      try {
        final f = File(pngPath);
        if (f.existsSync()) await f.delete();
      } catch (_) {/* 무시 */}
    }
  }
}

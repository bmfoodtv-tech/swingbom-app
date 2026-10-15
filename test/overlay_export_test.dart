// Phase 5 — 가이드 합성 렌더링 / 저작권 푸터 테스트
// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:swingbom/config/app_footer.dart';
import 'package:swingbom/config/constants.dart';
import 'package:swingbom/models/shape.dart';
import 'package:swingbom/services/overlay_export.dart';
import 'package:swingbom/services/settings_service.dart';

const _shapes = [
  Shape(
    type: ShapeType.circle,
    points: [Offset(0.58, 0.30), Offset(0.63, 0.33)],
    colorValue: 0xFFFF0000,
    strokeWidth: 3,
  ),
  Shape(
    type: ShapeType.line,
    points: [Offset(0.45, 0.20), Offset(0.70, 0.75)],
    colorValue: 0xFFFFEB3B,
    strokeWidth: 4,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('가이드 합성 PNG 렌더링', () {
    test('영상 해상도 크기의 PNG 바이트를 만든다', () async {
      final bytes = await OverlayExport.renderGuidePng(
        shapes: _shapes,
        size: const Size(1080, 1920),
        stageWidth: 390,
      );

      expect(bytes, isNotNull);
      // PNG 시그니처 확인
      expect(bytes!.sublist(0, 8),
          [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(bytes.length, greaterThan(100));
    });

    test('도형이 없으면 null 을 돌려준다', () async {
      final bytes = await OverlayExport.renderGuidePng(
        shapes: const [],
        size: const Size(1080, 1920),
      );
      expect(bytes, isNull);
    });

    test('크기가 비정상이면 null 을 돌려준다', () async {
      final bytes = await OverlayExport.renderGuidePng(
        shapes: _shapes,
        size: Size.zero,
      );
      expect(bytes, isNull);
    });

    test('가이드가 없으면 합성을 시도하지 않고 실패로 알린다', () async {
      final res = await OverlayExport.burnGuide(
        videoPath: 'not-used.mp4',
        shapes: const [],
        videoSize: const Size(1080, 1920),
      );
      expect(res.success, isFalse);
      expect(res.error, contains('가이드'));
    });
  });

  group('촬영 설정', () {
    test('프레임 옵션에 자동/60/120/240 이 있다', () {
      expect(FpsOption.all.map((e) => e.fps).toList(), [null, 60, 120, 240]);
    });

    test('fromFps 는 모르는 값이면 자동으로 떨어진다', () {
      expect(FpsOption.fromFps(120), FpsOption.f120);
      expect(FpsOption.fromFps(999), FpsOption.auto);
    });
  });

  group('저작권 표기', () {
    testWidgets('푸터 문구는 지정된 문구 그대로다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppFooter())),
      );
      expect(find.text('ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실'), findsOneWidget);
      expect(kCopyright, 'ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실');
    });
  });
}

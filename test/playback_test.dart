// Phase 4 — 배속 설정과 가이드 미세조정 규칙 테스트
// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실

import 'package:flutter_test/flutter_test.dart';
import 'package:swingbom/models/shape.dart';
import 'package:swingbom/screens/practice_screen.dart';

void main() {
  group('재생 배속', () {
    test('기본 배속은 0.25배속이다', () {
      expect(kSpeeds.first, 0.25);
    });

    test('0.25 / 0.5 / 1 / 2 배속을 제공한다', () {
      expect(kSpeeds, [0.25, 0.5, 1.0, 2.0]);
    });
  });

  group('가이드 미세조정 (불러온 라인 위치 보정)', () {
    test('이동해도 도형 형태(점 개수·종류)는 유지된다', () {
      const s = Shape(
        type: ShapeType.circle,
        points: [Offset(0.50, 0.30), Offset(0.55, 0.33)],
        colorValue: 0xFFFF0000,
        strokeWidth: 3,
      );
      final moved = s.translated(0.05, -0.02);

      expect(moved.type, s.type);
      expect(moved.points.length, s.points.length);
      expect(moved.colorValue, s.colorValue);
      expect(moved.strokeWidth, s.strokeWidth);
      expect(moved.points[0].dx, closeTo(0.55, 0.0001));
      expect(moved.points[0].dy, closeTo(0.28, 0.0001));
    });

    test('색·굵기만 바꿔도 좌표는 그대로다', () {
      const s = Shape(
        type: ShapeType.line,
        points: [Offset(0.45, 0.20), Offset(0.70, 0.75)],
        colorValue: 0xFFFF0000,
      );
      final restyled = s.copyWith(colorValue: 0xFF00E5FF, strokeWidth: 6);

      expect(restyled.points, s.points);
      expect(restyled.colorValue, 0xFF00E5FF);
      expect(restyled.strokeWidth, 6);
    });
  });
}

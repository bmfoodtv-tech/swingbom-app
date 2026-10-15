// 가이드 도형 직렬화 테스트 — 정규화 좌표가 서버 왕복 후에도 보존되는지 확인
// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실


import 'package:flutter_test/flutter_test.dart';
import 'package:swingbom/config/constants.dart';
import 'package:swingbom/models/shape.dart';
import 'package:swingbom/models/swing_guide.dart';

void main() {
  group('Shape', () {
    test('JSON 왕복 후 좌표·색·굵기가 보존된다', () {
      const s = Shape(
        type: ShapeType.circle,
        points: [Offset(0.58, 0.30), Offset(0.63, 0.33)],
        colorValue: 0xFFFF0000,
        strokeWidth: 3,
      );

      final back = Shape.fromJson(s.toJson());
      expect(back.type, ShapeType.circle);
      expect(back.points.length, 2);
      expect(back.points[0].dx, closeTo(0.58, 0.0001));
      expect(back.points[1].dy, closeTo(0.33, 0.0001));
      expect(back.colorValue, 0xFFFF0000);
      expect(back.strokeWidth, 3);
    });

    test('toJson 은 가이드 명세와 같은 구조를 만든다', () {
      const s = Shape(
        type: ShapeType.line,
        points: [Offset(0.45, 0.20), Offset(0.70, 0.75)],
        colorValue: 0xFFFF0000,
      );
      final j = s.toJson();
      expect(j['type'], 'line');
      expect(j['points'], [
        [0.45, 0.2],
        [0.7, 0.75]
      ]);
    });

    test('translated 는 0~1 범위를 벗어나지 않는다', () {
      const s = Shape(
        type: ShapeType.line,
        points: [Offset(0.1, 0.9), Offset(0.5, 0.5)],
        colorValue: 0xFFFFFFFF,
      );
      final moved = s.translated(-0.5, 0.5);
      expect(moved.points[0].dx, 0.0);
      expect(moved.points[0].dy, 1.0);
      expect(moved.points[1].dx, closeTo(0.0, 0.0001));
      expect(moved.points[1].dy, closeTo(1.0, 0.0001));
    });
  });

  group('SwingGuide', () {
    test('encode → decode 로 도형 수가 유지된다', () {
      const guide = SwingGuide(
        clubType: ClubType.iron,
        viewType: ViewType.side,
        shapes: [
          Shape(
            type: ShapeType.circle,
            points: [Offset(0.58, 0.30), Offset(0.63, 0.33)],
            colorValue: 0xFFFF0000,
          ),
          Shape(
            type: ShapeType.freehand,
            points: [Offset(0.1, 0.1), Offset(0.2, 0.2), Offset(0.3, 0.35)],
            colorValue: 0xFF00E5FF,
            strokeWidth: 5,
          ),
        ],
      );

      final decoded = SwingGuide.decodeShapes(guide.encodeShapes());
      expect(decoded.length, 2);
      expect(decoded[1].type, ShapeType.freehand);
      expect(decoded[1].points.length, 3);
      expect(decoded[1].strokeWidth, 5);
    });

    test('로컬 캐시 키에 swb_ 구분자가 들어간다', () {
      const g = SwingGuide(clubType: ClubType.driver, viewType: ViewType.front);
      expect(g.key, 'swb_guide_driver_front');
    });

    test('깨진 JSON 은 빈 목록으로 처리된다', () {
      expect(SwingGuide.decodeShapes('not-json'), isEmpty);
      expect(SwingGuide.decodeShapes(null), isEmpty);
      expect(SwingGuide.decodeShapes(''), isEmpty);
    });
  });
}

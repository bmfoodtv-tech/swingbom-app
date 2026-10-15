/// 가이드 도형 1개
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
///
/// 좌표는 **정규화 좌표(0.0~1.0)** 로 저장한다.
/// 기기 해상도·화면 크기와 무관하게 같은 위치에 겹쳐 그리기 위함이다.
///   line     : [start, end]
///   circle   : [center, edge]
///   rect     : [topLeft, bottomRight]
///   freehand : [p0, p1, p2, ...]
library;

import 'dart:ui';

enum ShapeType { line, freehand, circle, rect }

extension ShapeTypeX on ShapeType {
  String get code => name;
  String get label => switch (this) {
        ShapeType.line => '직선',
        ShapeType.freehand => '자유선',
        ShapeType.circle => '원',
        ShapeType.rect => '사각형',
      };
  static ShapeType fromCode(String c) => ShapeType.values.firstWhere(
        (e) => e.name == c,
        orElse: () => ShapeType.line,
      );
}

class Shape {
  final ShapeType type;
  final List<Offset> points; // 정규화 좌표(0~1)
  final int colorValue;
  final double strokeWidth;

  const Shape({
    required this.type,
    required this.points,
    required this.colorValue,
    this.strokeWidth = 3,
  });

  Color get color => Color(colorValue);

  Shape copyWith({
    ShapeType? type,
    List<Offset>? points,
    int? colorValue,
    double? strokeWidth,
  }) =>
      Shape(
        type: type ?? this.type,
        points: points ?? this.points,
        colorValue: colorValue ?? this.colorValue,
        strokeWidth: strokeWidth ?? this.strokeWidth,
      );

  /// 전체 도형을 dx, dy 만큼 이동 (정규화 단위, Phase 4 미세조정용)
  Shape translated(double dx, double dy) => copyWith(
        points: points
            .map((p) => Offset(
                  (p.dx + dx).clamp(0.0, 1.0),
                  (p.dy + dy).clamp(0.0, 1.0),
                ))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        'type': type.code,
        'points': points.map((p) => [_r(p.dx), _r(p.dy)]).toList(),
        'colorValue': colorValue,
        'strokeWidth': strokeWidth,
      };

  static double _r(double v) => double.parse(v.toStringAsFixed(4));

  factory Shape.fromJson(Map<String, dynamic> j) {
    final raw = (j['points'] as List? ?? const []);
    return Shape(
      type: ShapeTypeX.fromCode((j['type'] as String?) ?? 'line'),
      points: raw.map((e) {
        final p = e as List;
        return Offset(
          (p[0] as num).toDouble(),
          (p[1] as num).toDouble(),
        );
      }).toList(growable: false),
      colorValue: (j['colorValue'] as num?)?.toInt() ?? 0xFFFF0000,
      strokeWidth: (j['strokeWidth'] as num?)?.toDouble() ?? 3,
    );
  }
}

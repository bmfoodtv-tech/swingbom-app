/// 가이드 도형 렌더링 (화면 오버레이 · 영상 합성 공용)
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
///
/// 화면(DrawingCanvas)과 영상 합성(OverlayExport)이 **같은 코드로** 그려야
/// 화면에서 본 라인과 저장된 영상의 라인이 어긋나지 않는다.
library;

import 'package:flutter/material.dart';
import '../models/shape.dart';

/// 도형 굵기 기준 폭 — 이 폭에서 strokeWidth 가 1:1 로 보인다.
/// 영상(예: 1080px)에 그릴 때는 strokeScale 로 비례 확대한다.
const double kGuideRefWidth = 390;

Offset _abs(Offset n, Size s) => Offset(n.dx * s.width, n.dy * s.height);

void _path(Canvas canvas, List<Offset> pts, Shape sh, Paint paint) {
  switch (sh.type) {
    case ShapeType.line:
      canvas.drawLine(pts[0], pts[1], paint);
      break;
    case ShapeType.freehand:
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
      break;
    case ShapeType.circle:
      canvas.drawCircle(pts[0], (pts[1] - pts[0]).distance, paint);
      break;
    case ShapeType.rect:
      canvas.drawRect(Rect.fromPoints(pts[0], pts[1]), paint);
      break;
  }
}

/// 도형 하나 그리기
void paintShape(
  Canvas canvas,
  Size size,
  Shape sh, {
  bool selected = false,
  double strokeScale = 1,
  double handleRadius = 8.7,
}) {
  final pts = sh.points.map((p) => _abs(p, size)).toList();
  if (pts.length < 2) return;

  final w = sh.strokeWidth * strokeScale;

  // 어두운 배경에서도 잘 보이도록 얇은 그림자선을 먼저 깐다
  final shadow = Paint()
    ..color = const Color(0x66000000)
    ..strokeWidth = w + 2 * strokeScale
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  final paint = Paint()
    ..color = sh.color
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  _path(canvas, pts, sh, shadow);

  if (selected) {
    final glow = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = w + 6 * strokeScale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    _path(canvas, pts, sh, glow);
  }

  _path(canvas, pts, sh, paint);

  if (selected && sh.type != ShapeType.freehand) {
    final handle = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final ring = Paint()
      ..color = sh.color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    for (final p in pts.take(2)) {
      canvas.drawCircle(p, handleRadius, handle);
      canvas.drawCircle(p, handleRadius, ring);
    }
  }
}

/// 도형 전체 그리기
void paintGuideShapes(
  Canvas canvas,
  Size size,
  List<Shape> shapes, {
  int? selectedIndex,
  double strokeScale = 1,
}) {
  for (var i = 0; i < shapes.length; i++) {
    paintShape(
      canvas,
      size,
      shapes[i],
      selected: i == selectedIndex,
      strokeScale: strokeScale,
    );
  }
}

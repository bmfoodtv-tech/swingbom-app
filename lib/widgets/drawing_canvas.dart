/// 가이드 드로잉 오버레이 (CustomPainter + GestureDetector)
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
///
/// 정규화 좌표(0~1)로 저장된 도형을 실제 위젯 크기에 맞춰 그린다.
/// 영상/프리뷰 위에 Stack으로 정확히 겹쳐 놓아야 좌표가 일치한다.
///
/// 모드
///   view : 보기 전용 (제스처 없음)
///   draw : 새 도형 그리기
///   edit : 도형 선택 → 이동 / 핸들 드래그로 크기 조절 (어드레스 변동 대응)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/shape.dart';
import 'guide_painting.dart';

enum CanvasMode { view, draw, edit }

/// 핸들·선택 판정 반경 (픽셀)
const double _kHandleRadius = 14;
const double _kHitSlop = 20;

class DrawingCanvas extends StatefulWidget {
  final List<Shape> shapes;
  final CanvasMode mode;

  /// draw 모드에서 사용할 도구·색·굵기
  final ShapeType tool;
  final Color color;
  final double strokeWidth;

  /// 도형 하나가 완성되면 호출 (draw 모드)
  final ValueChanged<Shape>? onShapeAdded;

  /// edit 모드 — 선택 상태와 변경 콜백
  final int? selectedIndex;
  final ValueChanged<int?>? onSelectionChanged;
  final void Function(int index, Shape shape)? onShapeUpdated;

  const DrawingCanvas({
    super.key,
    required this.shapes,
    this.mode = CanvasMode.view,
    this.tool = ShapeType.line,
    this.color = const Color(0xFFFF0000),
    this.strokeWidth = 3,
    this.onShapeAdded,
    this.selectedIndex,
    this.onSelectionChanged,
    this.onShapeUpdated,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

enum _DragKind { none, newShape, move, handle }

class _DrawingCanvasState extends State<DrawingCanvas> {
  // 새 도형 그리기용
  Offset? _start;
  Offset? _current;
  final List<Offset> _freehand = [];

  // 편집용
  _DragKind _drag = _DragKind.none;
  int _handleIndex = -1;
  Offset _lastPos = Offset.zero;
  Shape? _dragShape; // 드래그 중인 도형의 작업본

  Size _size = Size.zero;

  Offset _norm(Offset local) => Offset(
        _size.width == 0 ? 0 : (local.dx / _size.width).clamp(0.0, 1.0),
        _size.height == 0 ? 0 : (local.dy / _size.height).clamp(0.0, 1.0),
      );

  Offset _abs(Offset n) => Offset(n.dx * _size.width, n.dy * _size.height);

  // ── 히트 테스트 ────────────────────────────────────────
  static double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    return (p - Offset(a.dx + ab.dx * t, a.dy + ab.dy * t)).distance;
  }

  double _distToShape(Offset p, Shape s) {
    final pts = s.points.map(_abs).toList();
    if (pts.length < 2) return double.infinity;

    switch (s.type) {
      case ShapeType.line:
        return _distToSegment(p, pts[0], pts[1]);

      case ShapeType.freehand:
        var best = double.infinity;
        for (var i = 0; i < pts.length - 1; i++) {
          best = math.min(best, _distToSegment(p, pts[i], pts[i + 1]));
        }
        return best;

      case ShapeType.circle:
        final r = (pts[1] - pts[0]).distance;
        return ((p - pts[0]).distance - r).abs();

      case ShapeType.rect:
        final rect = Rect.fromPoints(pts[0], pts[1]);
        final c = [
          rect.topLeft,
          rect.topRight,
          rect.bottomRight,
          rect.bottomLeft,
        ];
        var best = double.infinity;
        for (var i = 0; i < 4; i++) {
          best = math.min(best, _distToSegment(p, c[i], c[(i + 1) % 4]));
        }
        return best;
    }
  }

  /// 화면 좌표 p 에서 가장 가까운 도형 인덱스 (없으면 null)
  int? _hitShape(Offset p) {
    int? best;
    var bestD = _kHitSlop;
    // 나중에 그린 도형이 위에 있으므로 역순 검사
    for (var i = widget.shapes.length - 1; i >= 0; i--) {
      final d = _distToShape(p, widget.shapes[i]);
      if (d <= bestD) {
        bestD = d;
        best = i;
        break; // 가장 위에 있는 것 우선
      }
    }
    return best;
  }

  /// 선택된 도형의 핸들(끝점) 인덱스 (없으면 -1)
  int _hitHandle(Offset p) {
    final i = widget.selectedIndex;
    if (i == null || i < 0 || i >= widget.shapes.length) return -1;
    final s = widget.shapes[i];
    if (s.type == ShapeType.freehand) return -1; // 자유선은 이동만
    final pts = s.points.map(_abs).toList();
    for (var h = 0; h < pts.length && h < 2; h++) {
      if ((p - pts[h]).distance <= _kHandleRadius + 6) return h;
    }
    return -1;
  }

  // ── 제스처: 그리기 ──────────────────────────────────────
  void _drawStart(DragStartDetails d) {
    setState(() {
      _drag = _DragKind.newShape;
      _start = d.localPosition;
      _current = d.localPosition;
      _freehand
        ..clear()
        ..add(d.localPosition);
    });
  }

  void _drawUpdate(DragUpdateDetails d) {
    if (_start == null) return;
    setState(() {
      _current = d.localPosition;
      if (widget.tool == ShapeType.freehand) _freehand.add(d.localPosition);
    });
  }

  void _drawEnd() {
    if (_start == null || _current == null) return;

    final List<Offset> pts;
    if (widget.tool == ShapeType.freehand) {
      pts = _thin(_freehand).map(_norm).toList();
    } else {
      pts = [_norm(_start!), _norm(_current!)];
    }
    final tooSmall = widget.tool != ShapeType.freehand &&
        (_start! - _current!).distance < 8;

    setState(() {
      _drag = _DragKind.none;
      _start = null;
      _current = null;
      _freehand.clear();
    });

    if (tooSmall || pts.length < 2) return;

    widget.onShapeAdded?.call(Shape(
      type: widget.tool,
      points: pts,
      colorValue: widget.color.toARGB32(),
      strokeWidth: widget.strokeWidth,
    ));
  }

  // ── 제스처: 편집 ────────────────────────────────────────
  void _editStart(DragStartDetails d) {
    final p = d.localPosition;

    final h = _hitHandle(p);
    if (h >= 0) {
      setState(() {
        _drag = _DragKind.handle;
        _handleIndex = h;
        _lastPos = p;
        _dragShape = widget.shapes[widget.selectedIndex!];
      });
      return;
    }

    final hit = _hitShape(p);
    if (hit == null) {
      widget.onSelectionChanged?.call(null);
      setState(() => _drag = _DragKind.none);
      return;
    }

    if (hit != widget.selectedIndex) widget.onSelectionChanged?.call(hit);
    setState(() {
      _drag = _DragKind.move;
      _lastPos = p;
      _dragShape = widget.shapes[hit];
    });
  }

  void _editUpdate(DragUpdateDetails d) {
    final idx = widget.selectedIndex;
    final base = _dragShape;
    if (idx == null || base == null || _drag == _DragKind.none) return;

    final p = d.localPosition;
    final delta = p - _lastPos;
    _lastPos = p;

    Shape next;
    if (_drag == _DragKind.move) {
      next = base.translated(
        _size.width == 0 ? 0 : delta.dx / _size.width,
        _size.height == 0 ? 0 : delta.dy / _size.height,
      );
    } else {
      final pts = [...base.points];
      if (_handleIndex < 0 || _handleIndex >= pts.length) return;
      pts[_handleIndex] = _norm(p);
      next = base.copyWith(points: pts);
    }

    _dragShape = next;
    widget.onShapeUpdated?.call(idx, next);
  }

  void _editEnd() {
    setState(() {
      _drag = _DragKind.none;
      _handleIndex = -1;
      _dragShape = null;
    });
  }

  void _editTap(TapUpDetails d) {
    final hit = _hitShape(d.localPosition);
    widget.onSelectionChanged?.call(hit);
  }

  /// 자유선 점 솎아내기 (3px 미만 간격 제거)
  static List<Offset> _thin(List<Offset> src) {
    if (src.length < 3) return src;
    final out = <Offset>[src.first];
    for (final p in src.skip(1)) {
      if ((p - out.last).distance >= 3) out.add(p);
    }
    if (out.last != src.last) out.add(src.last);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        _size = Size(c.maxWidth, c.maxHeight);

        // 그리는 중인 임시 도형
        Shape? preview;
        if (widget.mode == CanvasMode.draw &&
            _start != null &&
            _current != null) {
          final pts = widget.tool == ShapeType.freehand
              ? _freehand.map(_norm).toList()
              : [_norm(_start!), _norm(_current!)];
          if (pts.length >= 2) {
            preview = Shape(
              type: widget.tool,
              points: pts,
              colorValue: widget.color.toARGB32(),
              strokeWidth: widget.strokeWidth,
            );
          }
        }

        final painter = _GuidePainter(
          shapes: widget.shapes,
          preview: preview,
          selectedIndex:
              widget.mode == CanvasMode.edit ? widget.selectedIndex : null,
        );

        if (widget.mode == CanvasMode.view) {
          return IgnorePointer(
            child: CustomPaint(size: Size.infinite, painter: painter),
          );
        }

        final isDraw = widget.mode == CanvasMode.draw;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: isDraw ? null : _editTap,
          onPanStart: isDraw ? _drawStart : _editStart,
          onPanUpdate: isDraw ? _drawUpdate : _editUpdate,
          onPanEnd: (_) => isDraw ? _drawEnd() : _editEnd(),
          child: CustomPaint(size: Size.infinite, painter: painter),
        );
      },
    );
  }
}

class _GuidePainter extends CustomPainter {
  final List<Shape> shapes;
  final Shape? preview;
  final int? selectedIndex;

  _GuidePainter({required this.shapes, this.preview, this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    // 화면과 영상 합성이 같은 코드로 그리도록 guide_painting.dart 를 공유한다
    paintGuideShapes(canvas, size, shapes, selectedIndex: selectedIndex);
    final p = preview;
    if (p != null) paintShape(canvas, size, p);
  }

  @override
  bool shouldRepaint(covariant _GuidePainter old) => true;
}

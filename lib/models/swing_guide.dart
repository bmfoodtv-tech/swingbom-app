/// 스윙 가이드 (클럽 + 뷰 조합별 도형 묶음)
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'dart:convert';

import '../config/constants.dart';
import 'shape.dart';

class SwingGuide {
  final ClubType clubType;
  final ViewType viewType;
  final List<Shape> shapes;
  final DateTime? updatedAt;

  const SwingGuide({
    required this.clubType,
    required this.viewType,
    this.shapes = const [],
    this.updatedAt,
  });

  bool get isEmpty => shapes.isEmpty;

  /// 서버 저장 키와 동일한 로컬 캐시 키
  String get key => 'swb_guide_${clubType.code}_${viewType.code}';

  String get label => '${viewType.label} · ${clubType.label}';

  SwingGuide copyWith({List<Shape>? shapes, DateTime? updatedAt}) => SwingGuide(
        clubType: clubType,
        viewType: viewType,
        shapes: shapes ?? this.shapes,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// 서버 shapes_json 필드에 담기는 문자열 (도형 배열만)
  String encodeShapes() =>
      jsonEncode(shapes.map((e) => e.toJson()).toList(growable: false));

  static List<Shape> decodeShapes(String? json) {
    if (json == null || json.trim().isEmpty) return const [];
    try {
      final raw = jsonDecode(json);
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Shape.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

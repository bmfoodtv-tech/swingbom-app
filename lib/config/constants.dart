/// 스윙봄(SwingBom) 공통 상수
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'package:flutter/material.dart';

/// 저작권 문구 (앱 화면 하단·관리자 웹 하단에 항상 표기)
const String kCopyright = 'ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실';

const String kAppName = '스윙봄';
const String kAppNameEn = 'SwingBom';

/// 클럽 종류
///
/// `wood` 는 화면에서 `utility`(유틸/우드) 로 합쳐 표시한다.
/// 서버에 이미 저장된 wood 가이드를 읽기 위해 값 자체는 남겨둔다.
enum ClubType { driver, iron, utility, wood, approach }

extension ClubTypeX on ClubType {
  String get code => name;
  String get label => switch (this) {
        ClubType.driver => '드라이버',
        ClubType.iron => '아이언',
        ClubType.utility => '유틸/우드',
        ClubType.wood => '우드',
        ClubType.approach => '어프로치',
      };
  static ClubType fromCode(String c) => ClubType.values
      .firstWhere((e) => e.name == c, orElse: () => ClubType.driver);
}

/// 클럽 선택 화면에 표시할 목록 — 유틸/우드를 한 버튼으로 합쳐 4개 (한 줄)
const List<ClubType> kSelectableClubs = [
  ClubType.driver,
  ClubType.iron,
  ClubType.utility,
  ClubType.approach,
];

/// 촬영 뷰
enum ViewType { front, side }

extension ViewTypeX on ViewType {
  String get code => name;
  String get label => this == ViewType.front ? '정면' : '측면';
  static ViewType fromCode(String c) =>
      ViewType.values.firstWhere((e) => e.name == c, orElse: () => ViewType.front);
}

/// 색상 팔레트 (골프 그린 계열)
class AppColors {
  static const primary = Color(0xFF166534);
  static const primaryLight = Color(0xFF22C55E);
  static const surface = Color(0xFFF8FAFC);
  static const card = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const textMain = Color(0xFF0F172A);
  static const textSub = Color(0xFF64748B);
  static const danger = Color(0xFFDC2626);
  static const accent = Color(0xFFF59E0B);
}

/// 드로잉 색상 팔레트 (Phase 3에서 사용)
const List<Color> kDrawColors = [
  Color(0xFFFF0000),
  Color(0xFFFFEB3B),
  Color(0xFF00E5FF),
  Color(0xFF00E676),
  Color(0xFFFFFFFF),
  Color(0xFFFF00FF),
];

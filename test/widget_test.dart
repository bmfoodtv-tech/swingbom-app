// 스윙봄(SwingBom) 기본 위젯 테스트
// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:swingbom/config/constants.dart';
import 'package:swingbom/config/app_footer.dart';

void main() {
  testWidgets('저작권 푸터가 지정된 문구를 표시한다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppFooter())),
    );
    expect(find.text(kCopyright), findsOneWidget);
    expect(kCopyright, 'ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실');
  });

  test('클럽·뷰 코드값이 가이드 부록과 일치한다', () {
    expect(ClubType.values.map((e) => e.code).toList(),
        ['driver', 'iron', 'utility', 'wood', 'approach']);
    expect(ViewType.values.map((e) => e.code).toList(), ['front', 'side']);
    expect(ClubType.iron.label, '아이언');
    expect(ViewType.side.label, '측면');
  });
}

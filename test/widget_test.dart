import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:assence/main.dart';

void main() {
  testWidgets('앱이 홈 피드와 하단 탭을 렌더링한다', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Assence'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });
}

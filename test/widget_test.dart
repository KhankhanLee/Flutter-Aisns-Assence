import 'package:assence/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('앱이 홈 피드와 하단 탭을 렌더링한다', (WidgetTester tester) async {
    final AppStores stores = await createTestStores(FakeGemini());
    await tester.pumpWidget(AssenceApp(stores: stores));
    await tester.pump();

    expect(find.text('Assence'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.text('hayeon_daily'), findsWidgets);
    expect(find.text('좋아요 1,240개'), findsOneWidget);
  });

  testWidgets('API 키가 없으면 안내 배너를 보여준다', (WidgetTester tester) async {
    final AppStores stores =
        await createTestStores(FakeGemini(configured: false));
    await tester.pumpWidget(AssenceApp(stores: stores));
    await tester.pump();

    expect(find.textContaining('Gemini API 키가 설정되지 않아'), findsOneWidget);
  });

  testWidgets('좋아요를 누르면 카운트가 1 늘어난다', (WidgetTester tester) async {
    final AppStores stores = await createTestStores(FakeGemini());
    await tester.pumpWidget(AssenceApp(stores: stores));
    await tester.pump();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await tester.pump();
    await tester.tap(find.byTooltip('좋아요').hitTestable().first);
    await tester.pumpAndSettle();

    expect(find.text('좋아요 1,241개'), findsOneWidget);
  });

  testWidgets('피드에서 댓글을 달면 페르소나 답글이 보이고 알림 뱃지가 생긴다',
      (WidgetTester tester) async {
    final FakeGemini gemini = FakeGemini(reply: '고마워요 ☕️');
    final AppStores stores = await createTestStores(gemini);
    await tester.pumpWidget(AssenceApp(stores: stores));
    await tester.pump();

    await tester.enterText(
        find.widgetWithText(TextField, '댓글 달기...').first, '라떼 맛있어 보여요');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(
        find.textContaining('라떼 맛있어 보여요', findRichText: true), findsOneWidget);
    expect(find.textContaining('고마워요 ☕️', findRichText: true), findsOneWidget);
    expect(find.widgetWithText(Badge, '1'), findsOneWidget);
  });

  testWidgets('채팅 화면을 닫았다 다시 열어도 대화가 남아 있다', (WidgetTester tester) async {
    final AppStores stores =
        await createTestStores(FakeGemini(reply: '안녕하세요!'));
    await tester.pumpWidget(AssenceApp(stores: stores));
    await tester.pump();

    await tester.tap(find.byTooltip('AI 채팅'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '안녕');
    await tester.tap(find.byTooltip('보내기'));
    await tester.pumpAndSettle();
    expect(find.text('안녕하세요!'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('AI 채팅'));
    await tester.pumpAndSettle();

    expect(find.text('안녕'), findsOneWidget);
    expect(find.text('안녕하세요!'), findsOneWidget);
  });

  testWidgets('검색 탭에서 해시태그로 게시물을 거르고 페르소나를 찾는다', (WidgetTester tester) async {
    final AppStores stores = await createTestStores(FakeGemini());
    await tester.pumpWidget(AssenceApp(stores: stores));
    await tester.pump();

    await tester.tap(find.byTooltip('검색'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('grid_seed_hayeon_cafe')),
        findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'AI 포스트 및 페르소나 검색 (#해시태그)'), '#러닝');
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('grid_seed_suyeon_running')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('grid_seed_hayeon_cafe')),
        findsNothing);

    await tester.enterText(find.widgetWithText(TextField, '#러닝'), '수연');
    await tester.pump();
    await tester.tap(find.text('suyeon_fit'));
    await tester.pumpAndSettle();

    expect(find.text('메시지 보내기'), findsOneWidget);
    await tester.tap(find.text('메시지 보내기'));
    await tester.pumpAndSettle();
    expect(find.text('수연에게 첫 메시지를 보내보세요 👋'), findsOneWidget);
  });

  testWidgets('저장한 게시물이 프로필 저장됨 탭에 보인다', (WidgetTester tester) async {
    final AppStores stores = await createTestStores(FakeGemini());
    stores.feed.toggleBookmark('seed_naeun_book');
    await tester.pumpWidget(AssenceApp(stores: stores));
    await tester.pump();

    await tester.tap(find.byTooltip('프로필'));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 올린 게시물이 없어요'), findsOneWidget);

    await tester.tap(find.text('저장됨').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('grid_seed_naeun_book')),
        findsOneWidget);
  });
}

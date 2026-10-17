import 'package:assence/app.dart';
import 'package:assence/pages/home_page.dart';
import 'package:assence/pages/splash_page.dart';
import 'package:assence/pages/story/story_upload_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('앱이 홈 피드와 하단 탭을 렌더링한다', (WidgetTester tester) async {
    final AppStores stores = await createTestStores(FakeGemini());
    await tester.pumpWidget(AssenceApp(stores: stores, showSplash: false));
    await tester.pump();

    expect(find.text('Assence'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.text('hayeon_daily'), findsWidgets);
    expect(find.text('좋아요 1,240개'), findsOneWidget);
  });

  testWidgets('API 키가 없으면 안내 배너를 보여준다', (WidgetTester tester) async {
    final AppStores stores = await createTestStores(
      FakeGemini(configured: false),
    );
    await tester.pumpWidget(AssenceApp(stores: stores, showSplash: false));
    await tester.pump();

    expect(find.textContaining('Gemini API 키가 설정되지 않아'), findsOneWidget);
  });

  testWidgets('좋아요를 누르면 카운트가 1 늘어난다', (WidgetTester tester) async {
    final AppStores stores = await createTestStores(FakeGemini());
    await tester.pumpWidget(AssenceApp(stores: stores, showSplash: false));
    await tester.pump();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await tester.pump();
    await tester.tap(find.byTooltip('좋아요').hitTestable().first);
    await tester.pumpAndSettle();

    expect(find.text('좋아요 1,241개'), findsOneWidget);
  });

  testWidgets('피드에서 댓글을 달면 페르소나 답글이 보이고 알림 뱃지가 생긴다', (
    WidgetTester tester,
  ) async {
    final FakeGemini gemini = FakeGemini(reply: '고마워요 ☕️');
    final AppStores stores = await createTestStores(gemini);
    await tester.pumpWidget(AssenceApp(stores: stores, showSplash: false));
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextField, '댓글 달기...').first,
      '라떼 맛있어 보여요',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('라떼 맛있어 보여요', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('고마워요 ☕️', findRichText: true), findsOneWidget);
    expect(find.widgetWithText(Badge, '1'), findsOneWidget);
  });

  testWidgets('채팅 화면을 닫았다 다시 열어도 대화가 남아 있다', (WidgetTester tester) async {
    final AppStores stores = await createTestStores(
      FakeGemini(reply: '안녕하세요!'),
    );
    await tester.pumpWidget(AssenceApp(stores: stores, showSplash: false));
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
    await tester.pumpWidget(AssenceApp(stores: stores, showSplash: false));
    await tester.pump();

    await tester.tap(find.byTooltip('검색'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('grid_seed_hayeon_cafe')),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'AI 포스트 및 페르소나 검색 (#해시태그)'),
      '#러닝',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('grid_seed_suyeon_running')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('grid_seed_hayeon_cafe')),
      findsNothing,
    );

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
    await tester.pumpWidget(AssenceApp(stores: stores, showSplash: false));
    await tester.pump();

    await tester.tap(find.byTooltip('프로필'));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 올린 게시물이 없어요'), findsOneWidget);

    await tester.tap(find.text('저장됨').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('grid_seed_naeun_book')),
      findsOneWidget,
    );
  });

  testWidgets('알림 탭은 답글 알림을 보여주고, 나가면 읽음 처리된다', (WidgetTester tester) async {
    final AppStores stores = await createTestStores(FakeGemini(reply: '반가워요'));
    await stores.feed.addComment('seed_hayeon_cafe', '안녕하세요');
    await tester.pumpWidget(AssenceApp(stores: stores, showSplash: false));
    await tester.pump();
    expect(find.widgetWithText(Badge, '1'), findsOneWidget);

    await tester.tap(find.byTooltip('알림'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('답글을 남겼어요: 반가워요', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('홈'));
    await tester.pumpAndSettle();
    expect(stores.notifications.unreadCount, 0);
    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('작성 탭은 사진을 고르기 전에는 공유할 수 없다', (WidgetTester tester) async {
    final AppStores stores = await createTestStores(FakeGemini());
    await tester.pumpWidget(AssenceApp(stores: stores, showSplash: false));
    await tester.pump();

    await tester.tap(find.byTooltip('게시물 작성'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('새 게시물'), const Offset(0, -600));
    await tester.pumpAndSettle();
    final FilledButton share = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '공유하기'),
    );
    expect(share.onPressed, isNull);
  });

  testWidgets('페르소나 스토리를 넘겨 보고, 답장은 DM으로 전송된다', (WidgetTester tester) async {
    final AppStores stores = await createTestStores(
      FakeGemini(reply: '답장 고마워요'),
    );
    await tester.pumpWidget(AssenceApp(stores: stores, showSplash: false));
    await tester.pump();

    await tester.tap(find.text('공감 친구'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('하연 ·'));
    // 스토리 뷰어는 자동 넘김 애니메이션 때문에 pumpAndSettle을 쓸 수 없다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('hayeon_daily'), findsOneWidget);

    // 오른쪽을 누르면 다음 스토리(나은)로 넘어간다.
    await tester.tapAt(const Offset(700, 300));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('naeun_night'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '저도 비 오는 날 좋아해요');
    await tester.tap(find.byTooltip('답장 보내기'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      stores.chat.historyOf('naeun').first.text,
      contains('저도 비 오는 날 좋아해요'),
    );
    expect(stores.chat.historyOf('naeun').last.text, '답장 고마워요');

    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
  });

  testWidgets('글만으로 내 스토리를 올리면 내 스토리에서 볼 수 있다', (WidgetTester tester) async {
    final AppStores stores = await createTestStores(FakeGemini());
    await tester.pumpWidget(AssenceApp(stores: stores, showSplash: false));
    await tester.pump();
    Navigator.of(
      tester.element(find.byType(HomePage)),
    ).push(MaterialPageRoute<void>(builder: (_) => const StoryUploadPage()));
    await tester.pumpAndSettle();

    final Finder upload = find.widgetWithText(FilledButton, '스토리 올리기');
    expect(tester.widget<FilledButton>(upload).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '오늘도 화이팅');
    await tester.pump();
    await tester.tap(upload);
    await tester.pump();

    expect(stores.stories.myActiveStories.single.text, '오늘도 화이팅');
    expect(stores.stories.myActiveStories.single.imagePath, isEmpty);
  });

  testWidgets('시작 화면에서 로고를 보여준 뒤 홈 피드로 넘어간다', (WidgetTester tester) async {
    final AppStores stores = await createTestStores(FakeGemini());
    await tester.pumpWidget(AssenceApp(stores: stores));
    await tester.pump();

    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.text('AI 친구들과 함께하는 SNS'), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);

    await tester.pump(SplashPage.duration);
    await tester.pumpAndSettle();
    expect(find.byType(SplashPage), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('설정에서 프로필 닉네임을 바꾸면 프로필과 댓글에 반영된다', (WidgetTester tester) async {
    final AppStores stores = await createTestStores(FakeGemini());
    await stores.feed.addComment('seed_hayeon_cafe', '첫 댓글');
    await tester.pumpWidget(AssenceApp(stores: stores, showSplash: false));
    await tester.pump();

    await tester.tap(find.byTooltip('프로필'));
    await tester.pumpAndSettle();
    expect(find.text('my_assence'), findsOneWidget);

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('프로필 편집'));
    await tester.pumpAndSettle();

    final Finder handleField = find.widgetWithText(TextField, '사용자 이름');
    // 규칙 위반과 페르소나 계정명 중복은 저장하지 않는다.
    await tester.enterText(handleField, 'Bad Name!');
    await tester.tap(find.text('완료'));
    await tester.pump();
    expect(find.textContaining('영문 소문자'), findsWidgets);
    await tester.enterText(handleField, 'hayeon_daily');
    await tester.tap(find.text('완료'));
    await tester.pump();
    expect(find.text('이미 사용 중인 사용자 이름이에요.'), findsOneWidget);

    await tester.enterText(handleField, 'dldbswo_05');
    await tester.enterText(find.widgetWithText(TextField, '이름'), '윤재');
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    expect(stores.profile.handle, 'dldbswo_05');
    expect(stores.profile.name, '윤재');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('dldbswo_05'), findsOneWidget);
    expect(find.text('윤재'), findsOneWidget);

    await tester.tap(find.byTooltip('홈'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('dldbswo_05 첫 댓글', findRichText: true),
      findsOneWidget,
    );
  });
}

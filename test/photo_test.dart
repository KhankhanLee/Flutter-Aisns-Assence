import 'dart:convert';
import 'dart:typed_data';

import 'package:assence/app.dart';
import 'package:assence/data/seed_data.dart';
import 'package:assence/models/chat_message.dart';
import 'package:assence/models/comment.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/post.dart';
import 'package:assence/pages/chat_room_page.dart';
import 'package:assence/pages/profile_edit_page.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/state/user_profile_store.dart';
import 'package:assence/utils/humanize.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

import 'test_helpers.dart';

final ChatImage _photo = (
  bytes: Uint8List.fromList(<int>[1, 2, 3]),
  mimeType: 'image/jpeg',
);

/// 차례대로 정해진 답을 돌려주는 Gemini.
class _ScriptedGemini extends FakeGemini {
  final List<String> replies;

  _ScriptedGemini(this.replies);

  @override
  Future<String> generateReply({
    required String persona,
    required List<ChatMessage> history,
    ChatImage? image,
    bool background = false,
  }) async {
    await super.generateReply(
      persona: persona,
      history: history,
      image: image,
      background: background,
    );
    return replies.removeAt(0);
  }
}

void main() {
  group('답에 섞인 계획·설정 문장', () {
    const String leaked =
        '지은이로서 짧게 답글 달기. 사용자가 "하아.." 게시물이라 힘들어 보일 수 있으니 '
        '가볍게 곁에 있어 주는 느낌으로. 사진은 아직 안 보였다는 설정 유지. '
        '사진 안 보이는데 ㅋㅋ 뭔데 그래 진짜 궁금하게 하네, 그냥 말해줘 ㅠㅠ';

    test('스크린샷처럼 앞에 붙은 계획 문장은 잘라 낸다', () {
      expect(leaksMeta(leaked), isTrue);
      expect(
        humanizeReply(leaked, maxEmoji: 0),
        '사진 안 보이는데 ㅋㅋ 뭔데 그래 진짜 궁금하게 하네, 그냥 말해줘 ㅠㅠ',
      );
    });

    test('<reply> 안의 말만 쓰고, 태그가 없으면 그대로 둔다', () {
      expect(extractReply('생각: 짧게 답하자\n<reply>헐 무슨 일이야</reply>'), '헐 무슨 일이야');
      expect(extractReply('<reply>닫는 태그가 없어'), '닫는 태그가 없어');
      expect(extractReply('그냥 답'), '그냥 답');
      expect(
        humanizeReply('<reply>오늘 뭐 먹었어?</reply>', maxEmoji: 0),
        '오늘 뭐 먹었어?',
      );
    });

    test('평범한 답은 건드리지 않는다', () {
      for (final String text in <String>[
        '사용자 이름 바꿨어? 몰라봤잖아 ㅋㅋ',
        '오늘 캐릭터 케이크 먹었어',
        '좋아 내일 봐.',
      ]) {
        expect(leaksMeta(text), isFalse, reason: text);
        expect(humanizeReply(text, maxEmoji: 0), text);
      }
      // 전부 계획 문장이면 지우지 않고 그대로 둔다(빈 답보다 낫다).
      const String allMeta = '지은이로서 짧게 답글 달기.';
      expect(stripMetaLines(allMeta), allMeta);
    });

    test('계획 문장이 섞인 답이 오면 한 번 다시 받는다', () async {
      final _ScriptedGemini gemini = _ScriptedGemini(<String>[
        leaked,
        '<reply>헐 무슨 일인데 ㅠㅠ</reply>',
      ]);
      final String reply = await gemini.generateChatReply(
        persona: seedPersonas.first,
        history: <ChatMessage>[
          ChatMessage(role: ChatMessage.userRole, text: '하아..'),
        ],
      );
      expect(reply, '헐 무슨 일인데 ㅠㅠ');
      expect(gemini.personas, hasLength(2));
      expect(gemini.personas.first, contains('<reply>'));
    });
  });

  group('내 게시물 사진을 AI가 본다', () {
    test('첫 반응 댓글과, AI 댓글에 단 답글에 게시물 사진을 함께 보낸다', () async {
      final FakeGemini gemini = FakeGemini(reply: '와 사진 분위기 좋다');
      final AppStores stores = await createTestStores(gemini);
      final List<String> loaded = <String>[];
      stores.feed.imageLoader = (String path) async {
        loaded.add(path);
        return _photo;
      };

      await stores.feed.addPost(imagePath: '/photos/me.jpg', caption: '하아..');
      expect(loaded, contains('/photos/me.jpg'));
      expect(gemini.images, everyElement(same(_photo)));

      final Post post = stores.feed.posts.first;
      final Comment aiComment = post.comments.first;
      gemini.images.clear();
      await stores.feed.addComment(
        post.id,
        '사진 보면 알잖아',
        replyToId: aiComment.id,
      );
      expect(gemini.images.single, same(_photo));
      expect(gemini.requests.last.last.text, contains('게시물 사진'));
    });

    test('페르소나 게시물 댓글에는 사진을 보내지 않는다', () async {
      final FakeGemini gemini = FakeGemini(reply: '고마워');
      final AppStores stores = await createTestStores(gemini);
      stores.feed.imageLoader = (String path) async => _photo;
      await stores.feed.addComment('seed_hayeon_cafe', '분위기 좋다');
      expect(gemini.images.single, isNull);
    });
  });

  group('DM 사진', () {
    test('사진만 보내도 전송되고, AI가 그 사진을 보고 답한다', () async {
      final FakeGemini gemini = FakeGemini(reply: '헐 여기 어디야?');
      final AppStores stores = await createTestStores(gemini);
      stores.chat
        ..bubbleGap = (() => Duration.zero)
        ..imageLoader = ((String path) async => _photo);

      await stores.chat.send('hayeon', '', imagePath: '/photos/sea.jpg');

      final List<ChatMessage> history = stores.chat.historyOf('hayeon');
      expect(history.first.imagePath, '/photos/sea.jpg');
      expect(history.first.text, isEmpty);
      expect(history.last.text, '헐 여기 어디야?');
      expect(gemini.images.single, same(_photo));
      expect(gemini.personas.single, contains('사진을 보냈어'));
      expect(
        ChatMessage.fromJson(history.first.toJson()).imagePath,
        '/photos/sea.jpg',
      );
    });

    test('글도 사진도 없으면 보내지 않는다', () async {
      final FakeGemini gemini = FakeGemini();
      final AppStores stores = await createTestStores(gemini);
      await stores.chat.send('hayeon', '   ');
      expect(stores.chat.historyOf('hayeon'), isEmpty);
      expect(gemini.requests, isEmpty);
    });

    test('이번 사진만 직접 보내고, 예전 사진은 "(사진을 보냈어)" 글로만 남긴다', () async {
      late Map<String, dynamic> body;
      final GeminiService service = GeminiService(
        apiKey: 'k',
        client: MockClient((http.Request r) async {
          body = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(<String, dynamic>{
                'candidates': <dynamic>[
                  <String, dynamic>{
                    'content': <String, dynamic>{
                      'parts': <dynamic>[
                        <String, String>{'text': '<reply>예쁘다</reply>'},
                      ],
                    },
                  },
                ],
              }),
            ),
            200,
          );
        }),
      );
      final String reply = await service.generateChatReply(
        persona: seedPersonas.first,
        history: <ChatMessage>[
          ChatMessage(
            role: ChatMessage.userRole,
            text: '어제 간 곳',
            imagePath: '/photos/old.jpg',
          ),
          ChatMessage(role: ChatMessage.modelRole, text: '좋다'),
          ChatMessage(
            role: ChatMessage.userRole,
            text: '',
            imagePath: '/photos/new.jpg',
          ),
        ],
        image: _photo,
      );
      expect(reply, '예쁘다');
      final List<dynamic> contents = body['contents'] as List<dynamic>;
      expect(contents.first['parts'].last['text'], '(사진을 보냈어) 어제 간 곳');
      expect(contents.first['parts'].first.containsKey('inline_data'), isFalse);
      expect(contents.last['parts'].first['inline_data']['data'], 'AQID');
      expect(contents.last['parts'].last['text'], '(사진을 보냈어)');
    });
  });

  group('프로필 사진', () {
    test('저장하고 다시 열어도 남고, 예전 프로필 데이터도 읽힌다', () async {
      final LocalStore local = await openTestStore(<String, Object>{
        'user_profile': jsonEncode(<String, String>{
          'handle': 'old_me',
          'name': '나',
          'bio': '',
        }),
      });
      final UserProfileStore profile = UserProfileStore(local);
      expect(profile.avatarPath, isNull);
      profile.setAvatar('/avatars/me.jpg');
      profile.update(handle: 'new_me', name: '윤재', bio: '안녕');
      final UserProfileStore reopened = UserProfileStore(local);
      expect(reopened.avatarPath, '/avatars/me.jpg');
      expect(reopened.handle, 'new_me');
      reopened.setAvatar(null);
      expect(UserProfileStore(local).avatarPath, isNull);
    });
  });

  group('화면', () {
    Future<AppStores> pump(WidgetTester tester, Widget page) async {
      final AppStores stores = await createTestStores(
        FakeGemini(reply: '와 예쁘다'),
      );
      stores.chat.bubbleGap = () => Duration.zero;
      await tester.pumpWidget(AssenceApp(stores: stores, showSplash: false));
      await tester.pump();
      Navigator.of(
        tester.element(find.byType(Scaffold).first),
      ).push(MaterialPageRoute<void>(builder: (_) => page));
      await tester.pumpAndSettle();
      return stores;
    }

    testWidgets('프로필 편집에서 사진을 고르면 내 프로필 사진이 바뀐다', (WidgetTester tester) async {
      final List<ImageSource> asked = <ImageSource>[];
      final AppStores stores = await pump(
        tester,
        ProfileEditPage(
          pickPhoto: (ImageSource source) async {
            asked.add(source);
            return 'images/Hayeon/Cafe.jpg';
          },
        ),
      );

      await tester.tap(find.text('사진 변경'));
      await tester.pumpAndSettle();
      expect(find.text('사진 삭제'), findsNothing);
      await tester.tap(find.text('갤러리에서 선택'));
      await tester.pumpAndSettle();

      expect(asked, <ImageSource>[ImageSource.gallery]);
      expect(stores.profile.avatarPath, 'images/Hayeon/Cafe.jpg');
      final CircleAvatar avatar = tester.widget<CircleAvatar>(
        find.byType(CircleAvatar).first,
      );
      expect(avatar.backgroundImage, isA<AssetImage>());

      await tester.tap(find.text('사진 변경'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 삭제'));
      await tester.pumpAndSettle();
      expect(stores.profile.avatarPath, isNull);
    });

    testWidgets('DM에서 사진을 골라 보내면 사진 말풍선이 보인다', (WidgetTester tester) async {
      final Persona hayeon = seedPersonas.first;
      final AppStores stores = await pump(
        tester,
        ChatRoomPage(
          personaId: hayeon.id,
          pickPhoto: (ImageSource source) async => 'images/Hayeon/Cafe.jpg',
        ),
      );

      final IconButton sendButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send),
      );
      expect(sendButton.onPressed, isNull);

      await tester.tap(find.byTooltip('사진 보내기'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('사진 빼기'), findsOneWidget);

      await tester.tap(find.byTooltip('보내기'));
      await tester.pumpAndSettle();

      final List<ChatMessage> history = stores.chat.historyOf(hayeon.id);
      expect(history.first.imagePath, 'images/Hayeon/Cafe.jpg');
      expect(history.last.text, '와 예쁘다');
      expect(find.byTooltip('사진 빼기'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName == 'images/Hayeon/Cafe.jpg',
        ),
        findsOneWidget,
      );
    });
  });
}

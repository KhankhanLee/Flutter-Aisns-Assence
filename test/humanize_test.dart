import 'package:assence/utils/humanize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('humanizeReply', () {
    test('스크린샷 같은 마크다운 답변을 평범한 글로 바꾼다', () {
      const String raw =
          '요즘 내 뇌 용량 99%를 차지하고 있는 건 딱 세 가지야.\n\n'
          '**1. 스마트 글래스 (feat. 폰 없는 세상)**\n'
          '나 요즘 스마트 안경에 완전히 꽂혔거든.\n\n'
          '## 성수동 팝업\n'
          '- 로봇 팔이 브루잉해 주는 커피\n'
          '* `생성형 AI` 조향';
      expect(
        humanizeReply(raw, maxEmoji: 0),
        '요즘 내 뇌 용량 99%를 차지하고 있는 건 딱 세 가지야.\n\n'
        '스마트 글래스 (feat. 폰 없는 세상)\n'
        '나 요즘 스마트 안경에 완전히 꽂혔거든.\n\n'
        '성수동 팝업\n'
        '로봇 팔이 브루잉해 주는 커피\n'
        '생성형 AI 조향',
      );
    });

    test('이모지는 허용 개수만 앞에서부터 남기고, ㅋㅋ·ㅠㅠ·해시태그는 둔다', () {
      expect(
        humanizeReply('ㅋㅋㅋ 진짜? 😂 대박 🔥✨ ㅠㅠ #일상', maxEmoji: 0),
        'ㅋㅋㅋ 진짜? 대박 ㅠㅠ #일상',
      );
      expect(humanizeReply('좋아 😊 고마워 ❤️ 👩‍💻', maxEmoji: 1), '좋아 😊 고마워');
      // ZWJ로 이어진 이모지도 하나로 보고 통째로 지운다.
      expect(humanizeReply('작업 중 👩‍💻', maxEmoji: 0), '작업 중');
    });

    test('이름표와 감싼 따옴표를 지운다', () {
      expect(
        humanizeReply('지은: "아 그거 나도 봤어"', maxEmoji: 0, speaker: '지은'),
        '아 그거 나도 봤어',
      );
      expect(humanizeReply('“응 알겠어”', maxEmoji: 0), '응 알겠어');
      // 문장 안의 따옴표는 그대로
      expect(humanizeReply('그거 "진짜" 맛있어', maxEmoji: 0), '그거 "진짜" 맛있어');
    });

    test('isEmoji는 한글 자모와 기본 기호를 이모지로 보지 않는다', () {
      for (final String c in <String>['ㅋ', 'ㅠ', '가', '!', '~', '♡', '→', '%']) {
        expect(isEmoji(c), isFalse, reason: c);
      }
      for (final String c in <String>['😂', '🔥', '✨', '❤️', '☕', '⭐', '1️⃣']) {
        expect(isEmoji(c), isTrue, reason: c);
      }
    });
  });

  group('splitIntoBubbles', () {
    test('빈 줄로 나누고, 빈 줄이 없으면 줄바꿈으로 나눈다', () {
      expect(splitIntoBubbles('아 그거?\n\n나도 봤어'), <String>['아 그거?', '나도 봤어']);
      expect(splitIntoBubbles('아 그거?\n나도 봤어'), <String>['아 그거?', '나도 봤어']);
      expect(splitIntoBubbles('한 줄'), <String>['한 줄']);
      expect(splitIntoBubbles('  \n '), isEmpty);
    });

    test('최대 3개까지만 두고 남는 건 마지막 말풍선에 붙인다', () {
      expect(splitIntoBubbles('a\n\nb\n\nc\n\nd\n\ne'), <String>[
        'a',
        'b',
        'c d e',
      ]);
    });
  });

  test('singleParagraph', () {
    expect(singleParagraph('고마워!\n 다음에 봐'), '고마워! 다음에 봐');
  });
}

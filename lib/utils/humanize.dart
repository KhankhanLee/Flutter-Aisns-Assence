import 'package:characters/characters.dart';

/// Gemini 답변에서 사람이 SNS·DM에서 잘 안 쓰는 표현을 걷어낸다.
///
/// - 마크다운(굵게 `**`, 제목 `#`, 목록 `-`·`1.`, 코드 백틱)
/// - 답변 전체를 감싼 따옴표, 앞에 붙은 자기 이름표("지은: ...")
/// - [maxEmoji]개를 넘는 이모지 (앞에서부터 남긴다)
///
/// ㅋㅋ·ㅠㅠ 같은 글자, 해시태그, 문단 사이 빈 줄은 그대로 둔다.
String humanizeReply(String text, {required int maxEmoji, String? speaker}) {
  String out = stripMetaLines(extractReply(text.replaceAll('\r\n', '\n')));

  out = out
      .replaceAllMapped(
        RegExp(r'\*\*(.+?)\*\*', dotAll: true),
        (Match m) => m.group(1)!,
      )
      .replaceAllMapped(
        RegExp(r'__(.+?)__', dotAll: true),
        (Match m) => m.group(1)!,
      )
      .replaceAll('**', '')
      .replaceAll('`', '');

  final List<String> lines = <String>[
    for (final String line in out.split('\n'))
      line
          .replaceFirst(RegExp(r'^\s*#{1,6}\s+'), '')
          .replaceFirst(RegExp(r'^\s*[-*•·]\s+'), '')
          .replaceFirst(RegExp(r'^\s*\d{1,2}[.)]\s+'), '')
          // 한 줄짜리 *강조*는 별표만 뗀다.
          .replaceAllMapped(
            RegExp(r'(^|\s)\*([^*\n]+)\*(?=\s|$)'),
            (Match m) => '${m.group(1)}${m.group(2)}',
          )
          .trim(),
  ];
  out = lines.join('\n');

  if (speaker != null && speaker.isNotEmpty) {
    out = out.replaceFirst(
      RegExp('^\\s*${RegExp.escape(speaker)}\\s*[:：]\\s*'),
      '',
    );
  }
  out = _stripWrappingQuotes(out.trim());
  out = _limitEmoji(out, maxEmoji);

  return out
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAll(RegExp(r' +\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// 모델에게 보낼 말만 `<reply>…</reply>` 안에 쓰게 한다. 태그가 있으면 그 안만,
/// 없으면 전체를 쓰고 남은 태그 조각은 지운다.
String extractReply(String text) {
  final Iterable<RegExpMatch> tagged = RegExp(
    r'<reply>([\s\S]*?)(?:</reply>|$)',
  ).allMatches(text);
  final String body = tagged.isEmpty
      ? text
      : tagged.map((RegExpMatch m) => m.group(1)!.trim()).join('\n\n');
  return body.replaceAll(RegExp(r'</?reply>'), '').trim();
}

/// 답에 "지은이로서 짧게 답글 달기. … 설정 유지." 같은 계획·설정 설명이 섞였는지.
bool leaksMeta(String text) => _metaPatterns.any(text.contains);

final List<Pattern> _metaPatterns = <Pattern>[
  RegExp(r'로서\s*\S*\s*(짧게\s*)?(답글|답장|댓글|대답)\s*(달기|하기|쓰기)'),
  RegExp(r'(설정|캐릭터|톤)(을|를)?\s*유지'),
  RegExp(r'느낌으로\s*[.)]'),
  RegExp(r'사용자(가|에게|의|를)\s'),
  '캐릭터로서',
  '(답변)',
];

/// 앞쪽의 계획·설정 설명 문장을 잘라 낸다. 전부 그런 문장이면 그대로 둔다.
String stripMetaLines(String text) {
  final List<String> sentences = text
      .split(RegExp(r'(?<=[.!?])\s+|\n+'))
      .where((String s) => s.trim().isNotEmpty)
      .toList();
  int first = 0;
  while (first < sentences.length && leaksMeta(sentences[first])) {
    first++;
  }
  if (first == 0 || first == sentences.length) return text;
  final String rest = sentences.sublist(first).join(' ');
  final int at = text.indexOf(sentences[first]);
  return at < 0 ? rest : text.substring(at).trim();
}

/// 캐릭터를 벗어나 "AI라서 만날 수 없어"처럼 답했는지.
/// IT 얘기에서 AI를 언급하는 건 괜찮으므로, 자기 자신을 AI로 말하는 표현만 본다.
bool breaksCharacter(String text) {
  const List<String> phrases = <String>[
    'AI라서',
    'AI이기 때문',
    '저는 AI',
    '나는 AI',
    '난 AI',
    'AI인 저',
    'AI인 나',
    '인공지능이라',
    '인공지능이기',
    '언어 모델',
    '언어모델',
    '챗봇이라',
    '실제로 만날 수',
    '직접 만날 수',
    '실제로는 만날',
    '물리적으로',
    '화면 밖으로',
  ];
  return phrases.any(text.contains);
}

/// 한 문단짜리 댓글로 만든다 (줄바꿈을 공백으로).
String singleParagraph(String text) =>
    text.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();

/// DM 답장을 말풍선 단위로 나눈다. 빈 줄로 나누고, 빈 줄이 없으면 줄바꿈으로 나눈다.
/// 최대 [maxBubbles]개까지만 두고 남는 문장은 마지막 말풍선에 붙인다.
List<String> splitIntoBubbles(String text, {int maxBubbles = 3}) {
  List<String> parts = text
      .split(RegExp(r'\n\s*\n'))
      .map((String p) => p.trim())
      .where((String p) => p.isNotEmpty)
      .toList();
  if (parts.length == 1) {
    parts = parts.single
        .split('\n')
        .map((String p) => p.trim())
        .where((String p) => p.isNotEmpty)
        .toList();
  }
  if (parts.isEmpty) return <String>[];
  if (parts.length <= maxBubbles) return parts;
  return <String>[
    ...parts.take(maxBubbles - 1),
    parts.skip(maxBubbles - 1).join(' '),
  ];
}

String _stripWrappingQuotes(String text) {
  const Map<String, String> pairs = <String, String>{
    '"': '"',
    '“': '”',
    "'": "'",
    '「': '」',
  };
  for (final MapEntry<String, String> pair in pairs.entries) {
    if (text.length > 1 &&
        text.startsWith(pair.key) &&
        text.endsWith(pair.value) &&
        !text.substring(1, text.length - 1).contains(pair.key)) {
      return text.substring(1, text.length - 1).trim();
    }
  }
  return text;
}

String _limitEmoji(String text, int maxEmoji) {
  int kept = 0;
  final StringBuffer buffer = StringBuffer();
  for (final String grapheme in text.characters) {
    if (isEmoji(grapheme)) {
      if (kept >= maxEmoji) continue;
      kept++;
    }
    buffer.write(grapheme);
  }
  return buffer.toString();
}

/// 글자 하나(grapheme)가 그림 이모지인지. 한글·ㅋㅋ·ㅠㅠ·기본 기호는 해당하지 않는다.
bool isEmoji(String grapheme) {
  // ♡ ♥ ★ ☆ 는 문자 메시지에서 글자처럼 쓰여서 이모지로 치지 않는다.
  const Set<int> textSymbols = <int>{0x2605, 0x2606, 0x2661, 0x2665};
  if (grapheme.runes.length == 1 &&
      textSymbols.contains(grapheme.runes.first)) {
    return false;
  }
  for (final int rune in grapheme.runes) {
    if ((rune >= 0x1F000 && rune <= 0x1FAFF) || // 이모티콘·그림 문자·국기 등
        (rune >= 0x2600 && rune <= 0x27BF) || // ☀️ ✨ ❤ 같은 기호
        (rune >= 0x2B00 && rune <= 0x2BFF) || // ⭐ ⬆
        (rune >= 0x2300 && rune <= 0x23FF) || // ⌛ ⏰
        rune == 0xFE0F || // 이모지 모양 선택자
        rune == 0x20E3) {
      // 키캡 (1️⃣)
      return true;
    }
  }
  return false;
}

int _idCounter = 0;

/// 같은 마이크로초에 여러 개를 만들어도 겹치지 않는 로컬 ID.
String newId(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

/// 1240 → "1,240"
String formatCount(int value) {
  final String digits = value.abs().toString();
  final StringBuffer buffer = StringBuffer(value < 0 ? '-' : '');
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String formatTimeAgo(DateTime time, {DateTime? now}) {
  final Duration diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return '${time.year}.${time.month}.${time.day}';
}

/// 앞으로 남은 시간: "곧", "40분 후", "5시간 후", "내일 오후 3시", "3일 후".
String formatTimeUntil(DateTime time, {DateTime? now}) {
  final DateTime current = now ?? DateTime.now();
  final Duration diff = time.difference(current);
  if (diff.inMinutes < 1) return '곧';
  if (diff.inHours < 1) return '${diff.inMinutes}분 후';
  if (diff.inHours < 12) return '${diff.inHours}시간 후';
  final DateTime tomorrow = DateTime(
    current.year,
    current.month,
    current.day + 1,
  );
  if (time.year == tomorrow.year &&
      time.month == tomorrow.month &&
      time.day == tomorrow.day) {
    final String period = time.hour < 12 ? '오전' : '오후';
    final int hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '내일 $period $hour시';
  }
  if (diff.inDays < 1) return '${diff.inHours}시간 후';
  return '${diff.inDays}일 후';
}

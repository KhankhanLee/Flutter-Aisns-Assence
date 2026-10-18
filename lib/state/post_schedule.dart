import 'dart:math';

/// 페르소나가 실제 사람처럼 띄엄띄엄 게시물을 올리도록 하는 일정 규칙.
class PostingHabit {
  /// 일주일에 올리는 게시물 수 (평균).
  final double postsPerWeek;

  /// 주로 활동하는 시각. [endHour]가 24를 넘으면 다음 날 새벽까지라는 뜻.
  final int startHour;
  final int endHour;

  const PostingHabit({
    required this.postsPerWeek,
    required this.startHour,
    required this.endHour,
  });

  Duration get averageInterval =>
      Duration(minutes: (7 * 24 * 60 / postsPerWeek).round());

  /// [from] 이후 다음 게시 시각. 평균 간격의 60~140% 사이에서 고르고,
  /// 활동 시간대 밖이면 가장 가까운 활동 시간대로 옮긴다.
  DateTime nextAfter(DateTime from, Random random) {
    final double factor = 0.6 + random.nextDouble() * 0.8;
    final DateTime raw = from.add(
      Duration(minutes: (averageInterval.inMinutes * factor).round()),
    );
    return fitActiveHours(raw, random);
  }

  /// [time]이 활동 시간대 안이면 그대로, 아니면 다음 활동 시간대 안의 임의 시각.
  DateTime fitActiveHours(DateTime time, Random random) {
    if (isActiveAt(time)) return time;
    // 오늘 시작 시각이 이미 지났으면 다음 날 시작 시각부터.
    final DateTime start = nextWindowStart(time);
    final int windowMinutes = (endHour - startHour) * 60;
    return start.add(Duration(minutes: random.nextInt(max(1, windowMinutes))));
  }

  /// [time] 이후 처음 시작되는 활동 시간대의 시작 시각.
  DateTime nextWindowStart(DateTime time) {
    DateTime start = DateTime(time.year, time.month, time.day, startHour);
    if (!start.isAfter(time)) start = start.add(const Duration(days: 1));
    return start;
  }

  bool isActiveAt(DateTime time) {
    final int hour = time.hour;
    if (endHour <= 24) return hour >= startHour && hour < endHour;
    // 자정을 넘기는 시간대 (예: 21시~다음 날 2시)
    return hour >= startHour || hour < endHour - 24;
  }
}

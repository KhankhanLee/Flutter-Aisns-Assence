import 'package:assence/services/local_store.dart';

/// AI 친구들이 알아서 하는 활동(친구 댓글, 스토리 문구, 먼저 보내는 DM)에 쓰는
/// 하루 AI 요청 수 상한. 무료 Gemini 한도를 사용자의 DM·댓글용으로 남겨 둔다.
/// 예약 게시물과 내 스토리를 보고 보내는 DM은 원래 드물어서 여기서 세지 않는다.
class AiBudget {
  static const String _storageKey = 'ai_budget';
  static const int dailyLimit = 30;

  final LocalStore _local;
  final DateTime Function() _now;

  AiBudget(this._local, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  String get _today {
    final DateTime now = _now();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// 오늘 쓴 횟수.
  int get used {
    final Object? saved = _local.readJson(_storageKey);
    if (saved is Map<String, dynamic> && saved['day'] == _today) {
      return saved['used'] as int? ?? 0;
    }
    return 0;
  }

  bool get hasRoom => used < dailyLimit;

  /// 한 번 쓸 수 있으면 세고 true, 오늘 다 썼으면 false.
  bool trySpend() {
    final int count = used;
    if (count >= dailyLimit) return false;
    _local.writeJson(_storageKey, <String, Object>{
      'day': _today,
      'used': count + 1,
    });
    return true;
  }
}

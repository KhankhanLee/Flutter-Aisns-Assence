import 'package:workmanager/workmanager.dart';
import 'package:assence/app.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/services/notification_service.dart';
import 'package:assence/state/activity_runner.dart';

/// 앱이 닫혀 있어도 AI 친구 활동을 처리하고 폰 알림을 띄우는 백그라운드 작업.
///
/// 앱과 백그라운드 작업은 같은 SharedPreferences를 쓴다. 서로 덮어쓰지 않도록
/// - 앱이 화면에 떠 있으면([AppPresence]) 백그라운드 작업은 아무것도 하지 않고,
/// - 백그라운드 작업이 돌고 나면 [revisionKey]를 올려, 앱이 다시 열릴 때
///   저장된 내용을 새로 읽게 한다.
class BackgroundActivity {
  static const String taskName = 'assence_activity';
  static const String revisionKey = 'bg_revision';
  static const Duration frequency = Duration(hours: 1);

  /// 알림 설정에 맞춰 주기 작업을 등록하거나 취소한다.
  static Future<void> sync({required bool enabled}) async {
    await Workmanager().initialize(callbackDispatcher);
    if (enabled) {
      await Workmanager().registerPeriodicTask(
        taskName,
        taskName,
        frequency: frequency,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } else {
      await Workmanager().cancelByUniqueName(taskName);
    }
  }

  /// 할 차례가 된 활동을 처리하고, 알림 설정이 허용하는 것만 [notifier]로 띄운다.
  /// 띄운 알림 수를 돌려준다.
  static Future<int> run({
    required LocalStore local,
    required GeminiService gemini,
    required Notifier notifier,
    DateTime Function()? now,
  }) async {
    final DateTime Function() clock = now ?? DateTime.now;
    await local.reload();
    if (AppPresence.isForeground(local, clock())) return 0;

    final AppStores stores = AppStores.create(local, gemini, now: now);
    if (!stores.notificationSettings.enabled) return 0;
    final List<ActivityEvent> events = await stores.runner.runDue();
    final Object? revision = local.readJson(revisionKey);
    await local.writeJson(revisionKey, (revision is int ? revision : 0) + 1);

    int shown = 0;
    for (final ActivityEvent event in events) {
      if (!stores.notificationSettings.allows(event.kind)) continue;
      await notifier.show(
        event: event,
        personaName: stores.runner.nameOf(event.personaId),
      );
      shown++;
    }
    return shown;
  }
}

/// workmanager가 앱이 닫혀 있을 때 부르는 진입점.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((String task, Map<String, dynamic>? input) async {
    try {
      await BackgroundActivity.run(
        local: await LocalStore.open(),
        gemini: GeminiService.fromEnvironment(),
        notifier: LocalNotifier(),
      );
    } catch (_) {
      // 실패해도 다음 주기에 다시 시도한다.
    }
    return true;
  });
}

/// 앱이 화면에 떠 있는지 저장해 둔다. 백그라운드 작업은 이 표시가 최근이면 건너뛴다.
class AppPresence {
  static const String _key = 'app_foreground';

  /// 표시가 이보다 오래됐으면 앱이 강제 종료된 것으로 본다.
  static const Duration staleAfter = Duration(minutes: 20);

  static Future<void> markForeground(LocalStore local, DateTime now) =>
      local.writeJson(_key, now.toIso8601String());

  static Future<void> markBackground(LocalStore local) =>
      local.writeJson(_key, null);

  static bool isForeground(LocalStore local, DateTime now) {
    final Object? saved = local.readJson(_key);
    if (saved is! String) return false;
    final DateTime? at = DateTime.tryParse(saved);
    return at != null && now.difference(at) < staleAfter;
  }
}

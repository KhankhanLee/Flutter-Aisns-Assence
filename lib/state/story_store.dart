import 'package:flutter/foundation.dart';
import 'package:assence/data/seed_data.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/story.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/utils/format.dart';

class StoryStore extends ChangeNotifier {
  static const String _storageKey = 'my_stories';

  final LocalStore _local;
  final DateTime Function() _now;
  final List<Story> _personaStories;
  final List<Story> _myStories = <Story>[]; // 오래된 순

  StoryStore(this._local, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        _personaStories = buildSeedPersonaStories((now ?? DateTime.now)()) {
    final Object? saved = _local.readJson(_storageKey);
    if (saved is List<dynamic>) {
      _myStories.addAll(saved
          .map((dynamic json) => Story.fromJson(json as Map<String, dynamic>)));
    }
  }

  /// 24시간이 지나지 않은 내 스토리.
  List<Story> get myActiveStories =>
      _myStories.where((Story s) => s.isActive(_now())).toList();

  /// [personaIds] 순서대로, 아직 만료되지 않은 페르소나 스토리.
  List<Story> storiesOf(List<String> personaIds) => <Story>[
        for (final String id in personaIds)
          ..._personaStories
              .where((Story s) => s.authorId == id && s.isActive(_now())),
      ];

  void addMyStory({required String imagePath, required String text}) {
    _myStories.add(Story(
      id: newId('story'),
      authorId: myUserId,
      imagePath: imagePath,
      text: text.trim(),
      createdAt: _now(),
    ));
    // 만료된 스토리는 저장할 때 정리한다.
    _myStories.removeWhere((Story s) => !s.isActive(_now()));
    _local.writeJson(
        _storageKey, _myStories.map((Story s) => s.toJson()).toList());
    notifyListeners();
  }
}

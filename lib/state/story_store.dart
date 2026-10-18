import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:assence/data/seed_data.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/story.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/state/ai_budget.dart';
import 'package:assence/state/post_schedule.dart';
import 'package:assence/utils/format.dart';

/// 스토리 DM을 보낼 차례가 된 페르소나와 그 스토리.
typedef DueStoryReply = ({Story story, StoryView view});

class StoryStore extends ChangeNotifier {
  static const String _storageKey = 'my_stories';
  static const String _likedKey = 'liked_stories';
  static const String _personaStoriesKey = 'persona_stories';
  static const String _scheduleKey = 'persona_next_story';

  /// 한 번 확인할 때 새로 올리는 페르소나 스토리 수 상한.
  static const int maxStoriesPerCheck = 2;

  /// 내 스토리를 페르소나가 볼 확률, 본 사람이 좋아요를 누를 확률.
  static const double viewChance = 0.85;
  static const double likeChance = 0.4;

  /// 스토리 하나에 페르소나 한 명이 DM을 보낼 확률 (많아야 한 명).
  static const double replyChance = 0.6;

  final LocalStore _local;
  final DateTime Function() _now;
  final Random _random;
  final List<Story> _personaStories = <Story>[]; // 오래된 순
  final Map<String, DateTime> _nextStoryAt = <String, DateTime>{};
  final List<Story> _myStories = <Story>[]; // 오래된 순
  final Set<String> _liked = <String>{}; // 내가 좋아요한 페르소나 스토리 ID

  StoryStore(this._local, {DateTime Function()? now, Random? random})
    : _now = now ?? DateTime.now,
      _random = random ?? Random() {
    // 페르소나 스토리는 저장해 두고, 처음 실행할 때만 시드로 시작한다.
    final Object? personaSaved = _local.readJson(_personaStoriesKey);
    if (personaSaved is List<dynamic>) {
      _personaStories.addAll(
        personaSaved.map(
          (dynamic json) => Story.fromJson(json as Map<String, dynamic>),
        ),
      );
    } else {
      _personaStories.addAll(buildSeedPersonaStories(_now()).reversed.toList());
      _savePersonaStories();
    }
    final Object? schedule = _local.readJson(_scheduleKey);
    if (schedule is Map<String, dynamic>) {
      schedule.forEach((String id, dynamic time) {
        _nextStoryAt[id] = DateTime.parse(time as String);
      });
    }
    for (final MapEntry<String, PostingHabit> habit
        in personaStoryHabits.entries) {
      _nextStoryAt.putIfAbsent(
        habit.key,
        () => habit.value.nextAfter(
          _latestStoryOf(habit.key)?.createdAt ?? _now(),
          _random,
        ),
      );
    }
    _saveSchedule();

    final Object? saved = _local.readJson(_storageKey);
    if (saved is List<dynamic>) {
      _myStories.addAll(
        saved.map(
          (dynamic json) => Story.fromJson(json as Map<String, dynamic>),
        ),
      );
    }
    final Object? liked = _local.readJson(_likedKey);
    if (liked is List<dynamic>) _liked.addAll(liked.cast<String>());
    _planMissingViews();
  }

  /// 조회 일정이 생기기 전 버전에서 올린 스토리에도 지금부터 일정을 만든다.
  void _planMissingViews() {
    final DateTime now = _now();
    bool changed = false;
    for (int i = 0; i < _myStories.length; i++) {
      final Story story = _myStories[i];
      if (story.views.isNotEmpty || !story.isActive(now)) continue;
      _myStories[i] = Story(
        id: story.id,
        authorId: story.authorId,
        imagePath: story.imagePath,
        text: story.text,
        createdAt: story.createdAt,
        views: _planViews(story.createdAt, from: now),
      );
      changed = true;
    }
    if (changed) _save();
  }

  /// 24시간이 지나지 않은 내 스토리.
  List<Story> get myActiveStories =>
      _myStories.where((Story s) => s.isActive(_now())).toList();

  Story? _latestStoryOf(String personaId) =>
      _personaStories.where((Story s) => s.authorId == personaId).lastOrNull;

  /// 페르소나별 다음 스토리 예정 시각 (설정 화면 표시용).
  Map<String, DateTime> get nextStoryTimes =>
      Map<String, DateTime>.unmodifiable(_nextStoryAt);

  /// 스토리 예정 시각이 지난 페르소나가 새 스토리를 올린다. 올린 스토리를 돌려준다.
  /// 사진은 그 페르소나의 사진 중에서 고르고(최근 스토리 사진은 피함), 문구는
  /// AI가 쓴다. AI 키가 없으면 사진만 올리고, 요청이 실패하거나 오늘 예산을 다
  /// 썼으면 한 시간 뒤로 미룬다.
  Future<List<Story>> runScheduledStories({
    required GeminiService gemini,
    required List<Persona> personas,
    required AiBudget budget,
  }) async {
    final DateTime now = _now();
    final List<Story> posted = <Story>[];
    final List<String> due =
        _nextStoryAt.keys
            .where((String id) => !_nextStoryAt[id]!.isAfter(now))
            .toList()
          ..sort(
            (String a, String b) =>
                _nextStoryAt[a]!.compareTo(_nextStoryAt[b]!),
          );
    for (final String id in due) {
      final PostingHabit habit = personaStoryHabits[id]!;
      final Persona? persona = personas
          .where((Persona p) => p.id == id)
          .firstOrNull;
      final List<PersonaPhoto>? pool = personaPhotos[id];
      if (persona == null || pool == null) {
        _nextStoryAt[id] = habit.nextAfter(now, _random);
        continue;
      }
      if (posted.length >= maxStoriesPerCheck) {
        _nextStoryAt[id] = habit.fitActiveHours(
          now.add(Duration(minutes: 30 + _random.nextInt(120))),
          _random,
        );
        continue;
      }
      final String? lastPhoto = _latestStoryOf(id)?.imagePath;
      final List<PersonaPhoto> choices = pool
          .where((PersonaPhoto p) => p.path != lastPhoto)
          .toList();
      final List<PersonaPhoto> from = choices.isEmpty ? pool : choices;
      final PersonaPhoto photo = from[_random.nextInt(from.length)];

      String text = '';
      if (gemini.isConfigured) {
        if (!budget.trySpend()) {
          _nextStoryAt[id] = now.add(const Duration(hours: 1));
          continue;
        }
        try {
          final String? topic =
              persona.lifeTopics.isNotEmpty && _random.nextBool()
              ? persona.lifeTopics[_random.nextInt(persona.lifeTopics.length)]
              : null;
          text = await gemini.generateStoryText(
            persona: persona,
            photoDescription: photo.description,
            topic: topic,
          );
        } on GeminiException {
          _nextStoryAt[id] = now.add(const Duration(hours: 1));
          continue;
        }
      }
      final Story story = Story(
        id: newId('story_$id'),
        authorId: id,
        imagePath: photo.path,
        text: text,
        createdAt: now,
      );
      _personaStories.add(story);
      posted.add(story);
      _nextStoryAt[id] = habit.nextAfter(now, _random);
    }
    _personaStories.removeWhere((Story s) => !s.isActive(now));
    _savePersonaStories();
    _saveSchedule();
    if (posted.isNotEmpty) notifyListeners();
    return posted;
  }

  void _savePersonaStories() => _local.writeJson(
    _personaStoriesKey,
    _personaStories.map((Story s) => s.toJson()).toList(),
  );

  void _saveSchedule() => _local.writeJson(
    _scheduleKey,
    _nextStoryAt.map(
      (String id, DateTime time) =>
          MapEntry<String, String>(id, time.toIso8601String()),
    ),
  );

  /// [personaIds] 순서대로, 아직 만료되지 않은 페르소나 스토리.
  List<Story> storiesOf(List<String> personaIds) => <Story>[
    for (final String id in personaIds)
      ..._personaStories.where(
        (Story s) => s.authorId == id && s.isActive(_now()),
      ),
  ];

  /// 내 스토리를 지금까지 본 페르소나 (최근에 본 순).
  List<StoryView> viewersOf(Story story) {
    final DateTime now = _now();
    return story.views.where((StoryView v) => !v.at.isAfter(now)).toList()
      ..sort((StoryView a, StoryView b) => b.at.compareTo(a.at));
  }

  bool isLiked(String storyId) => _liked.contains(storyId);

  void toggleLike(String storyId) {
    if (!_liked.remove(storyId)) _liked.add(storyId);
    _local.writeJson(_likedKey, _liked.toList());
    notifyListeners();
  }

  Story addMyStory({required String imagePath, required String text}) {
    final DateTime now = _now();
    final Story story = Story(
      id: newId('story'),
      authorId: myUserId,
      imagePath: imagePath,
      text: text.trim(),
      createdAt: now,
      views: _planViews(now),
    );
    _myStories.add(story);
    // 만료된 스토리는 저장할 때 정리한다.
    _myStories.removeWhere((Story s) => !s.isActive(now));
    _save();
    notifyListeners();
    return story;
  }

  /// 스토리를 올린 순간 페르소나별로 언제 볼지, 좋아요를 누를지, DM을 보낼지 정한다.
  /// 실제 SNS처럼 지금 활동 중인 친구는 대부분 몇 분 안에 보고(그중 한 명은 꼭 본다),
  /// 활동 시간이 아닌 친구는 다음 활동 시간이 시작되고 얼마 뒤에 본다.
  /// [from]은 일정을 짜기 시작하는 시각 (예전 스토리를 보정할 때는 지금).
  List<StoryView> _planViews(DateTime created, {DateTime? from}) {
    final DateTime start = from ?? created;
    final DateTime expires = created.add(Story.lifetime);
    bool activeNow(Persona p) => personaHabits[p.id]?.isActiveAt(start) ?? true;
    final List<Persona> active = seedPersonas.where(activeNow).toList();
    final String? sureViewer = active.isEmpty
        ? null
        : active[_random.nextInt(active.length)].id;

    final List<StoryView> views = <StoryView>[];
    for (final Persona persona in seedPersonas) {
      final bool sure = persona.id == sureViewer;
      if (!sure && _random.nextDouble() >= viewChance) continue;
      final PostingHabit? habit = personaHabits[persona.id];
      final DateTime at;
      if (habit == null || habit.isActiveAt(start)) {
        // 대부분 처음 10분 안 (평균 6분 지수분포, 2~20분). 일부는 한참 뒤에 본다.
        if (sure || _random.nextDouble() < 0.7) {
          final double minutes = (2 - 6 * log(1 - _random.nextDouble()))
              .clamp(2, 20)
              .toDouble();
          at = start.add(Duration(seconds: (minutes * 60).round()));
        } else {
          at = start.add(Duration(minutes: 20 + _random.nextInt(220)));
        }
      } else {
        at = habit
            .nextWindowStart(start)
            .add(Duration(minutes: _random.nextInt(60)));
      }
      if (!at.isBefore(expires)) continue;
      views.add(
        StoryView(
          personaId: persona.id,
          at: at,
          liked: _random.nextDouble() < likeChance,
        ),
      );
    }
    if (views.isNotEmpty && _random.nextDouble() < replyChance) {
      final StoryView view = views[_random.nextInt(views.length)];
      view.replyAt = view.at.add(Duration(minutes: 1 + _random.nextInt(9)));
    }
    return views;
  }

  /// DM을 보낼 시각이 지났는데 아직 안 보낸 것.
  List<DueStoryReply> dueReplies() {
    final DateTime now = _now();
    return <DueStoryReply>[
      for (final Story story in myActiveStories)
        for (final StoryView view in story.views)
          if (!view.replied &&
              view.replyAt != null &&
              !view.replyAt!.isAfter(now))
            (story: story, view: view),
    ];
  }

  void markReplied(StoryView view) {
    view.replied = true;
    _save();
    notifyListeners();
  }

  void _save() => _local.writeJson(
    _storageKey,
    _myStories.map((Story s) => s.toJson()).toList(),
  );
}

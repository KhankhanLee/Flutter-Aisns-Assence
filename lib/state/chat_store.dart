import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:assence/models/chat_message.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/story.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/image_bytes.dart';
import 'package:assence/services/local_store.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/utils/humanize.dart';

/// 페르소나별 DM 기록. 각 페르소나가 독립된 대화 노드처럼 자기 history를 가진다.
class ChatStore extends ChangeNotifier {
  static const String _storageKey = 'chat_histories';
  static const String _lastReadKey = 'chat_last_read';

  final LocalStore _local;
  final GeminiService _gemini;
  final PersonaStore _personas;

  final Map<String, List<ChatMessage>> _histories =
      <String, List<ChatMessage>>{};
  final Set<String> _pending = <String>{};
  final Map<String, String> _errors = <String, String>{};
  final Map<String, DateTime> _lastReadAt = <String, DateTime>{};

  /// 나눠 보내는 말풍선 사이의 간격. 테스트에서는 0으로 바꾼다.
  Duration Function() bubbleGap = () =>
      Duration(milliseconds: 600 + Random().nextInt(600));

  /// 스토리 사진을 AI 요청용으로 읽는다. 테스트에서는 바꿔 끼운다.
  Future<ChatImage?> Function(String path) imageLoader = loadChatImage;

  ChatStore(this._local, this._gemini, this._personas) {
    final Object? lastRead = _local.readJson(_lastReadKey);
    if (lastRead is Map<String, dynamic>) {
      lastRead.forEach((String personaId, dynamic time) {
        _lastReadAt[personaId] = DateTime.parse(time as String);
      });
    }
    final Object? saved = _local.readJson(_storageKey);
    if (saved is Map<String, dynamic>) {
      saved.forEach((String personaId, dynamic messages) {
        _histories[personaId] = (messages as List<dynamic>)
            .map((dynamic m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList();
      });
    }
  }

  List<ChatMessage> historyOf(String personaId) =>
      List<ChatMessage>.unmodifiable(_histories[personaId] ?? <ChatMessage>[]);

  bool isPending(String personaId) => _pending.contains(personaId);

  /// 마지막 요청이 실패했을 때의 안내 문구. 대화 기록에는 넣지 않는다.
  String? errorOf(String personaId) => _errors[personaId];

  ChatMessage? lastMessageOf(String personaId) {
    final List<ChatMessage>? history = _histories[personaId];
    return history == null || history.isEmpty ? null : history.last;
  }

  /// 마지막으로 대화방을 본 뒤에 페르소나가 보낸 답장이 있는지.
  bool isUnread(String personaId) {
    final ChatMessage? last = lastMessageOf(personaId);
    if (last == null || last.isUser) return false;
    final DateTime? readAt = _lastReadAt[personaId];
    return readAt == null || last.createdAt.isAfter(readAt);
  }

  /// 읽지 않은 답장이 있는 대화방 수 (DM 아이콘 뱃지).
  int get unreadCount => _histories.keys
      .where((String id) => _personas.byId(id) != null && isUnread(id))
      .length;

  void markRead(String personaId) {
    if (!isUnread(personaId)) return;
    _lastReadAt[personaId] = DateTime.now();
    _local.writeJson(
      _lastReadKey,
      _lastReadAt.map(
        (String id, DateTime time) =>
            MapEntry<String, String>(id, time.toIso8601String()),
      ),
    );
    notifyListeners();
  }

  /// [story]를 주면 그 스토리에 대한 답장으로 보낸다.
  Future<void> send(String personaId, String text, {Story? story}) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty || isPending(personaId)) return;

    _histories
        .putIfAbsent(personaId, () => <ChatMessage>[])
        .add(
          ChatMessage(
            role: ChatMessage.userRole,
            text: trimmed,
            story: story?.toShared(),
          ),
        );
    await _requestReply(personaId);
  }

  /// [personaId]가 내 [story]를 보고 먼저 DM을 보낸다. 성공하면 true.
  /// 사용자가 기다리는 요청이 아니라서 실패하면 화면에 오류를 띄우지 않고,
  /// 다음 확인 때 다시 시도한다.
  Future<bool> receiveStoryReaction(String personaId, Story story) async {
    final Persona? persona = _personas.byId(personaId);
    if (persona == null) return true; // 삭제된 캐릭터는 보낼 필요가 없다.
    if (isPending(personaId)) return false;

    _pending.add(personaId);
    notifyListeners();
    try {
      final String reply = await _gemini.generateStoryReaction(
        persona: persona,
        story: story.toShared(),
        history: historyOf(personaId),
        image: await imageLoader(story.imagePath),
      );
      await _addBubbles(personaId, reply, story: story.toShared());
      return true;
    } on GeminiException {
      return false;
    } finally {
      _pending.remove(personaId);
      _save();
      notifyListeners();
    }
  }

  /// 실패한 마지막 메시지에 대한 답변을 다시 요청한다.
  Future<void> retry(String personaId) async {
    final List<ChatMessage>? history = _histories[personaId];
    if (history == null || history.isEmpty || !history.last.isUser) return;
    await _requestReply(personaId);
  }

  void clearHistory(String personaId) {
    _histories.remove(personaId);
    _errors.remove(personaId);
    _save();
    notifyListeners();
  }

  Future<void> _requestReply(String personaId) async {
    final Persona? persona = _personas.byId(personaId);
    if (persona == null) return;

    _pending.add(personaId);
    _errors.remove(personaId);
    _save();
    notifyListeners();

    try {
      final String reply = await _gemini.generateChatReply(
        persona: persona,
        history: historyOf(personaId),
      );
      await _addBubbles(personaId, reply);
    } on GeminiException catch (e) {
      _errors[personaId] = e.userMessage;
    } finally {
      _pending.remove(personaId);
      _save();
      notifyListeners();
    }
  }

  /// 사람처럼 짧은 말풍선 여러 개로 나눠, 조금씩 간격을 두고 도착하게 한다.
  /// [story]는 첫 말풍선에 붙인다.
  Future<void> _addBubbles(
    String personaId,
    String reply, {
    SharedStory? story,
  }) async {
    final List<String> bubbles = splitIntoBubbles(reply);
    for (int i = 0; i < bubbles.length; i++) {
      if (i > 0) {
        notifyListeners();
        await Future<void>.delayed(bubbleGap());
      }
      // 기다리는 동안 대화가 삭제됐으면 답장을 버린다. 스토리 DM은 새 대화를 연다.
      final List<ChatMessage>? history = story != null
          ? _histories.putIfAbsent(personaId, () => <ChatMessage>[])
          : _histories[personaId];
      if (history == null) break;
      history.add(
        ChatMessage(
          role: ChatMessage.modelRole,
          text: bubbles[i],
          story: i == 0 ? story : null,
        ),
      );
    }
  }

  Future<void> _save() => _local.writeJson(
    _storageKey,
    _histories.map(
      (String id, List<ChatMessage> messages) => MapEntry<String, dynamic>(
        id,
        messages.map((ChatMessage m) => m.toJson()).toList(),
      ),
    ),
  );
}

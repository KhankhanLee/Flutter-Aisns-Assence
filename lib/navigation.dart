import 'package:flutter/material.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/pages/chat_list_page.dart';
import 'package:assence/pages/chat_room_page.dart';
import 'package:assence/pages/persona_profile_page.dart';
import 'package:assence/pages/post_detail_page.dart';

/// [personaId]가 있으면 그 페르소나와의 대화방, 없으면 DM 목록을 연다.
Future<void> openChat(BuildContext context, {String? personaId}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => personaId == null
          ? const ChatListPage()
          : ChatRoomPage(personaId: personaId),
    ),
  );
}

/// 알림을 누르고 들어왔을 때 갈 곳. 홈 화면이 뜨면 [takePendingTarget]으로 꺼내 간다.
String? _pendingTarget;

void setPendingTarget(String target) => _pendingTarget = target;

String? takePendingTarget() {
  final String? target = _pendingTarget;
  _pendingTarget = null;
  return target;
}

/// 알림 payload(`chat:<personaId>` / `post:<postId>`)에 맞는 화면을 연다.
Future<void> openTarget(BuildContext context, String target) async {
  final int colon = target.indexOf(':');
  if (colon < 0) return;
  final String id = target.substring(colon + 1);
  switch (target.substring(0, colon)) {
    case 'chat':
      await openChat(context, personaId: id);
    case 'post':
      await openPost(context, id);
  }
}

Future<void> openPost(BuildContext context, String postId) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => PostDetailPage(postId: postId)),
  );
}

/// 페르소나 프로필로 이동한다. 내 계정이면 아무 것도 하지 않는다.
Future<void> openAuthorProfile(BuildContext context, String authorId) async {
  if (authorId == myUserId) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PersonaProfilePage(personaId: authorId),
    ),
  );
}

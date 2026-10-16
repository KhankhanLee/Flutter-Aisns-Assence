import 'package:flutter/material.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/pages/chat_page.dart';
import 'package:assence/pages/persona_profile_page.dart';
import 'package:assence/pages/post_detail_page.dart';

Future<void> openChat(BuildContext context, {String? personaId}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => ChatPage(initialPersonaId: personaId),
  ));
}

Future<void> openPost(BuildContext context, String postId) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PostDetailPage(postId: postId),
  ));
}

/// 페르소나 프로필로 이동한다. 내 계정이면 아무 것도 하지 않는다.
Future<void> openAuthorProfile(BuildContext context, String authorId) async {
  if (authorId == myUserId) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PersonaProfilePage(personaId: authorId),
  ));
}

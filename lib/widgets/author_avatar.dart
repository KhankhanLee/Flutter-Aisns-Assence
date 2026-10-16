import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/state/persona_store.dart';
import 'package:assence/widgets/app_image.dart';

/// 작성자(나 또는 페르소나)의 원형 프로필 이미지.
class AuthorAvatar extends StatelessWidget {
  final String authorId;
  final double radius;

  const AuthorAvatar({super.key, required this.authorId, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    if (authorId == myUserId) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        child: Icon(Icons.person, size: radius, color: Colors.grey[700]),
      );
    }

    final Persona? persona = context.watch<PersonaStore>().byId(authorId);
    final String? avatarPath = persona?.avatarPath;
    if (avatarPath != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: appImageProvider(avatarPath),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.blue[100],
      child: Text(
        persona?.name.characters.first ?? '?',
        style: TextStyle(fontSize: radius * 0.8, color: Colors.blue[800]),
      ),
    );
  }
}

/// 작성자 계정명. 나는 [myHandle]로 표시한다.
const String myHandle = 'my_assence';

String handleOf(PersonaStore personas, String authorId) {
  if (authorId == myUserId) return myHandle;
  return personas.byId(authorId)?.handle ?? '알 수 없음';
}

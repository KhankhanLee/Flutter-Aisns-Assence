import 'package:flutter/material.dart';

/// Gemini API 키가 없을 때 AI 기능이 동작하지 않는다는 것을 알려주는 배너.
class ApiKeyBanner extends StatelessWidget {
  const ApiKeyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber[100],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Text(
        'Gemini API 키가 설정되지 않아 AI 답변이 비활성화되어 있어요.\n'
        'flutter run --dart-define=GEMINI_API_KEY=<키> 로 실행해 주세요.',
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}

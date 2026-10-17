import 'package:flutter/material.dart';
import 'package:assence/pages/api_key_page.dart';

/// Gemini API 키가 없을 때 AI 기능이 꺼져 있음을 알리고, 누르면 키 입력 화면으로 간다.
class ApiKeyBanner extends StatelessWidget {
  const ApiKeyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.amber[100],
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ApiKeyPage())),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(Icons.key_outlined, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Gemini API 키가 설정되지 않아 AI 답변이 비활성화되어 있어요.\n'
                  '여기를 눌러 API 키를 입력하세요.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

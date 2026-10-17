import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/state/persona_store.dart';

/// 커스텀 AI 캐릭터를 만든다. 만들면 새 [Persona]를 돌려준다.
Future<Persona?> showAddCharacterDialog(BuildContext context) =>
    showDialog<Persona>(
      context: context,
      builder: (_) => const _AddCharacterDialog(),
    );

class _AddCharacterDialog extends StatefulWidget {
  const _AddCharacterDialog();

  @override
  State<_AddCharacterDialog> createState() => _AddCharacterDialogState();
}

class _AddCharacterDialogState extends State<_AddCharacterDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  final TextEditingController _prompt = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('나만의 AI 캐릭터 만들기'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '캐릭터 이름 (예: 민서)'),
            ),
            TextField(
              controller: _bio,
              decoration: const InputDecoration(
                labelText: '한 줄 소개 (예: 패션 에디터)',
              ),
            ),
            TextField(
              controller: _prompt,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '페르소나/성격 설정',
                hintText: '예: 너는 솔직하고 프렌치 감성을 좋아하는 패션 에디터야.',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            final String name = _name.text.trim();
            final String prompt = _prompt.text.trim();
            if (name.isEmpty || prompt.isEmpty) return;
            final Persona created = context.read<PersonaStore>().addCustom(
              name: name,
              prompt: prompt,
              bio: _bio.text.trim(),
            );
            Navigator.pop(context, created);
          },
          child: const Text('생성'),
        ),
      ],
    );
  }
}

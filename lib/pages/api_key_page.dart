import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/state/ai_settings_store.dart';
import 'package:assence/state/feed_store.dart';

/// 폰에서 바로 Gemini API 키를 입력하고 연결을 확인하는 화면.
class ApiKeyPage extends StatefulWidget {
  const ApiKeyPage({super.key});

  static const String keyPageUrl = 'https://aistudio.google.com/apikey';

  @override
  State<ApiKeyPage> createState() => _ApiKeyPageState();
}

class _ApiKeyPageState extends State<ApiKeyPage> {
  final TextEditingController _key = TextEditingController();
  bool _obscure = true;
  String? _result;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _key.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    FocusScope.of(context).unfocus();
    final AiSettingsStore ai = context.read<AiSettingsStore>();
    setState(() => _result = null);
    try {
      final String reply = await ai.saveAndTest(_key.text);
      if (!mounted) return;
      // 키를 넣기 전에 게시 예정 시각이 지난 AI 친구가 있으면 지금 올린다.
      context.read<FeedStore>().runScheduledPosts();
      setState(() {
        _success = true;
        _result = '연결 성공! (모델: ${ai.model})\nAI 응답: $reply';
        _key.clear();
      });
    } on GeminiException catch (e) {
      if (!mounted) return;
      setState(() {
        _success = false;
        _result = '연결 실패: ${e.userMessage}';
      });
    }
  }

  Future<void> _clear() async {
    await context.read<AiSettingsStore>().clearKey();
    if (!mounted) return;
    setState(() {
      _success = false;
      _result = '저장된 키를 삭제했어요.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final AiSettingsStore ai = context.watch<AiSettingsStore>();
    final bool canSave = !ai.isTesting && _key.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Gemini API 키')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            color: ai.isConfigured ? Colors.green[50] : Colors.orange[50],
            child: ListTile(
              leading: Icon(
                ai.isConfigured ? Icons.check_circle : Icons.info_outline,
                color: ai.isConfigured ? Colors.green : Colors.orange,
              ),
              title: Text(ai.isConfigured ? '키가 설정되어 있어요' : '키가 아직 없어요'),
              subtitle: Text(
                ai.isConfigured
                    ? '${ai.maskedKey} · 모델 ${ai.model}'
                    : 'AI 답글·DM·게시물을 쓰려면 키가 필요해요',
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('키 발급 방법', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            '1. 폰 브라우저에서 아래 주소를 열고 구글 계정으로 로그인\n'
            '2. "API 키 만들기(Create API key)"를 눌러 키 복사\n'
            '3. 아래 칸에 붙여넣고 "저장하고 연결 테스트" 누르기',
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              const Expanded(
                child: SelectableText(
                  ApiKeyPage.keyPageUrl,
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: '주소 복사',
                onPressed: () {
                  Clipboard.setData(
                    const ClipboardData(text: ApiKeyPage.keyPageUrl),
                  );
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('주소를 복사했어요.')));
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'API 키 붙여넣기',
              hintText: 'AIza...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                tooltip: _obscure ? '키 보기' : '키 숨기기',
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: canSave ? _saveAndTest : null,
            child: ai.isTesting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('저장하고 연결 테스트'),
          ),
          if (_result != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _success ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_result!),
            ),
          ],
          if (ai.isConfigured) ...<Widget>[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: ai.isTesting ? null : _clear,
              child: const Text('저장된 키 삭제'),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            '키는 이 폰 안에만 저장되고 Google Gemini API 호출에만 쓰여요. '
            '무료 키는 분당 호출 수가 제한되어 있어서, AI 답이 늦거나 '
            '"요청이 너무 많아요"가 뜨면 잠시 뒤 다시 시도해 주세요.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

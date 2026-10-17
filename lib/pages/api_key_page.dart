import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:assence/services/claude_client.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/state/ai_settings_store.dart';
import 'package:assence/state/feed_store.dart';

/// 폰에서 바로 AI(Gemini 또는 Claude) API 키를 입력하고 연결을 확인하는 화면.
/// 위에서 고른 AI가 앱의 답글·DM·게시물에 쓰인다.
class ApiKeyPage extends StatefulWidget {
  const ApiKeyPage({super.key});

  static const String keyPageUrl = 'https://aistudio.google.com/apikey';
  static const String claudeKeyPageUrl =
      'https://console.anthropic.com/settings/keys';

  @override
  State<ApiKeyPage> createState() => _ApiKeyPageState();
}

class _ApiKeyPageState extends State<ApiKeyPage> {
  final TextEditingController _key = TextEditingController();
  bool _obscure = true;
  String? _result;
  bool _success = false;
  late AiProvider _tab = context.read<AiSettingsStore>().provider;

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

  bool get _isClaude => _tab == AiProvider.claude;

  void _selectTab(AiProvider tab) {
    setState(() {
      _tab = tab;
      _result = null;
      _key.clear();
    });
    // 이미 키가 있는 AI를 고르면 바로 그 AI를 쓴다.
    final AiSettingsStore ai = context.read<AiSettingsStore>();
    if (ai.hasKey(tab)) ai.selectProvider(tab);
  }

  Future<void> _saveAndTest() async {
    FocusScope.of(context).unfocus();
    final AiSettingsStore ai = context.read<AiSettingsStore>();
    setState(() => _result = null);
    try {
      final String reply = await ai.saveAndTest(_key.text, provider: _tab);
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
    await context.read<AiSettingsStore>().clearKey(provider: _tab);
    if (!mounted) return;
    setState(() {
      _success = false;
      _result = '저장된 키를 삭제했어요.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final AiSettingsStore ai = context.watch<AiSettingsStore>();
    final bool hasKey = ai.hasKey(_tab);
    final bool inUse = hasKey && ai.provider == _tab;
    final bool canSave = !ai.isTesting && _key.text.trim().isNotEmpty;
    final String url = _isClaude
        ? ApiKeyPage.claudeKeyPageUrl
        : ApiKeyPage.keyPageUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 연결')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SegmentedButton<AiProvider>(
            segments: const <ButtonSegment<AiProvider>>[
              ButtonSegment<AiProvider>(
                value: AiProvider.gemini,
                label: Text('Gemini'),
              ),
              ButtonSegment<AiProvider>(
                value: AiProvider.claude,
                label: Text('Claude'),
              ),
            ],
            selected: <AiProvider>{_tab},
            onSelectionChanged: (Set<AiProvider> value) =>
                _selectTab(value.single),
          ),
          const SizedBox(height: 12),
          Card(
            color: inUse ? Colors.green[50] : Colors.orange[50],
            child: ListTile(
              leading: Icon(
                inUse ? Icons.check_circle : Icons.info_outline,
                color: inUse ? Colors.green : Colors.orange,
              ),
              title: Text(
                inUse
                    ? '지금 이 AI를 쓰고 있어요'
                    : hasKey
                    ? '키는 있지만 다른 AI를 쓰는 중이에요'
                    : '키가 아직 없어요',
              ),
              subtitle: Text(
                hasKey
                    ? '${ai.maskedKeyOf(_tab)} · 모델 ${ai.modelOf(_tab)}'
                    : 'AI 답글·DM·게시물을 쓰려면 키가 필요해요',
              ),
            ),
          ),
          if (_isClaude) ...<Widget>[
            const SizedBox(height: 16),
            const Text('모델', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioGroup<String>(
              groupValue: ai.modelOf(AiProvider.claude),
              onChanged: (String? id) {
                if (id != null) ai.setClaudeModel(id);
              },
              child: Column(
                children: <Widget>[
                  for (final ClaudeModelOption option in ai.claudeModels)
                    RadioListTile<String>(
                      value: option.id,
                      title: Text(option.label),
                      subtitle: Text(option.note),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text('키 발급 방법', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            _isClaude
                ? '1. 폰 브라우저에서 아래 주소를 열고 Anthropic 계정으로 로그인\n'
                      '2. Billing에서 크레딧 충전 (Claude Pro 구독과는 별도예요)\n'
                      '3. API Keys에서 "Create Key"를 눌러 키 복사\n'
                      '4. 아래 칸에 붙여넣고 "저장하고 연결 테스트" 누르기'
                : '1. 폰 브라우저에서 아래 주소를 열고 구글 계정으로 로그인\n'
                      '2. "API 키 만들기(Create API key)"를 눌러 키 복사\n'
                      '3. 아래 칸에 붙여넣고 "저장하고 연결 테스트" 누르기',
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: SelectableText(
                  url,
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: '주소 복사',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
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
              hintText: _isClaude ? 'sk-ant-...' : 'AIza...',
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
          if (hasKey) ...<Widget>[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: ai.isTesting ? null : _clear,
              child: const Text('저장된 키 삭제'),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            _isClaude
                ? '키는 이 폰 안에만 저장되고 Anthropic Claude API 호출에만 쓰여요. '
                      '쓴 만큼 충전한 크레딧에서 빠져나가요. 사진 직접 만들기는 Gemini 키가 있어야 돼요.'
                : '키는 이 폰 안에만 저장되고 Google Gemini API 호출에만 쓰여요. '
                      '무료 키는 한도가 작아서, 한도에 걸리면 같은 키로 쓸 수 있는 다른 모델로 '
                      '자동으로 바꿔 답해요. Claude 키도 넣어 두면 그때 Claude가 대신 답해요.',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

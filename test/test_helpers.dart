import 'package:assence/app.dart';
import 'package:assence/models/chat_message.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/local_store.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 네트워크 없이 정해진 답변을 돌려주는 Gemini.
class FakeGemini extends GeminiService {
  final List<List<ChatMessage>> requests = <List<ChatMessage>>[];
  final List<String> personas = <String>[];
  String reply;
  GeminiException? error;

  FakeGemini({this.reply = 'AI 답변', this.error, bool configured = true})
    : super(
        apiKey: configured ? 'test-key' : '',
        client: MockClient((_) => throw StateError('FakeGemini는 네트워크를 쓰지 않는다')),
      );

  @override
  Future<String> generateReply({
    required String persona,
    required List<ChatMessage> history,
  }) async {
    personas.add(persona);
    requests.add(List<ChatMessage>.of(history));
    if (!isConfigured) {
      throw const GeminiException(GeminiErrorKind.missingApiKey, 'no key');
    }
    final GeminiException? e = error;
    if (e != null) throw e;
    return reply;
  }
}

Future<LocalStore> openTestStore([
  Map<String, Object> initial = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return LocalStore.open();
}

Future<AppStores> createTestStores(FakeGemini gemini) async =>
    AppStores.create(await openTestStore(), gemini);

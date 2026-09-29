import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:assence/story_schema.dart';

class MyStoryCameraPage extends StatefulWidget {
  const MyStoryCameraPage({super.key});

  @override
  State<MyStoryCameraPage> createState() => _MyStoryCameraPageState();
}

class _MyStoryCameraPageState extends State<MyStoryCameraPage> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCamera());
  }

  Future<void> _openCamera() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final XFile? captured = await _picker.pickImage(source: ImageSource.camera);
      if (!mounted) return;

      if (captured == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = '촬영이 취소되었어요. 다시 시도하거나 템플릿을 확인해 주세요.';
        });
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => StoryUploadTemplatePage(imagePath: captured.path),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '카메라를 실행하지 못했어요. 권한을 확인해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 스토리 촬영')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 14),
                const Text('카메라를 여는 중...'),
              ] else ...[
                const Icon(Icons.camera_alt_outlined, size: 46),
                const SizedBox(height: 10),
                Text(
                  _errorMessage ?? '스토리를 촬영해 주세요.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _openCamera,
                  child: const Text('카메라 다시 열기'),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const StoryUploadTemplatePage(),
                      ),
                    );
                  },
                  child: const Text('템플릿만 먼저 보기'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class StoryUploadTemplatePage extends StatelessWidget {
  final String? imagePath;

  const StoryUploadTemplatePage({super.key, this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('스토리 업로드 템플릿')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black87,
                  child: imagePath == null
                      ? const Center(
                          child: Text(
                            '스토리 이미지 영역\n(촬영본 또는 추후 에디터 연동)',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : Image.file(
                          File(imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text(
                              '이미지를 불러올 수 없어요.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const TextField(
              decoration: InputDecoration(
                labelText: '스토리 문구',
                hintText: '오늘의 한마디를 적어보세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {},
              child: const Text('스토리 올리기 (스키마 연결 완료)'),
            ),
          ],
        ),
      ),
    );
  }
}

class PersonaStoryFeedPage extends StatelessWidget {
  final StoryEntrySchema entry;

  const PersonaStoryFeedPage({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final stories = resolvePersonaStories(entry);

    return Scaffold(
      appBar: AppBar(title: Text(entry.title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final story = stories[index];
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PersonaStoryPlaceholderPage(
                    personaName: story.personaName,
                    categoryTitle: entry.title,
                  ),
                ),
              );
            },
            child: Ink(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                image: DecorationImage(
                  image: AssetImage(story.coverImagePath),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.55), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                alignment: Alignment.bottomLeft,
                child: Text(
                  '${story.personaName} · ${story.previewText}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PersonaStoryPlaceholderPage extends StatelessWidget {
  final String personaName;
  final String categoryTitle;

  const PersonaStoryPlaceholderPage({
    super.key,
    required this.personaName,
    required this.categoryTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$personaName 스토리')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$categoryTitle 피드 스키마가 준비되었습니다.',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '이 페이지에 실제 스토리 콘텐츠(이미지/영상, 텍스트, 인터랙션)를 연결하면 됩니다.',
            ),
          ],
        ),
      ),
    );
  }
}

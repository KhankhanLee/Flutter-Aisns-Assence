import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:assence/services/media_storage.dart';
import 'package:assence/state/story_store.dart';

/// 카메라를 바로 열고, 촬영하면 업로드 화면으로 넘어간다.
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
      final XFile? captured = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1440,
        imageQuality: 85,
      );
      if (!mounted) return;

      if (captured == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = '촬영이 취소되었어요. 다시 시도하거나 글만 올릴 수 있어요.';
        });
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => StoryUploadPage(imagePath: captured.path),
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
            children: <Widget>[
              if (_isLoading) ...<Widget>[
                const CircularProgressIndicator(),
                const SizedBox(height: 14),
                const Text('카메라를 여는 중...'),
              ] else ...<Widget>[
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
                      MaterialPageRoute<void>(
                        builder: (_) => const StoryUploadPage(),
                      ),
                    );
                  },
                  child: const Text('사진 없이 글로 올리기'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 촬영한 사진(또는 글만)으로 내 스토리를 올린다. 스토리는 24시간 뒤 사라진다.
class StoryUploadPage extends StatefulWidget {
  final String? imagePath;

  const StoryUploadPage({super.key, this.imagePath});

  @override
  State<StoryUploadPage> createState() => _StoryUploadPageState();
}

class _StoryUploadPageState extends State<StoryUploadPage> {
  final TextEditingController _text = TextEditingController();
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _canUpload =>
      !_uploading && (widget.imagePath != null || _text.text.trim().isNotEmpty);

  Future<void> _upload() async {
    if (!_canUpload) return;
    setState(() => _uploading = true);

    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final StoryStore stories = context.read<StoryStore>();
    try {
      final String? source = widget.imagePath;
      final String saved = source == null
          ? ''
          : await persistPickedImage(source, folder: 'stories');
      stories.addMyStory(imagePath: saved, text: _text.text);
      messenger.showSnackBar(
        const SnackBar(content: Text('스토리를 올렸어요. 24시간 동안 보여요!')),
      );
      navigator.pop();
    } on FileSystemException {
      messenger.showSnackBar(
        const SnackBar(content: Text('사진을 저장하지 못했어요. 다시 시도해 주세요.')),
      );
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? imagePath = widget.imagePath;
    return Scaffold(
      appBar: AppBar(title: const Text('스토리 올리기')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black87,
                  child: imagePath == null
                      ? const Center(
                          child: Text(
                            '사진 없이 글만 올리는 스토리예요.\n아래에 오늘의 한마디를 적어주세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : Image.file(
                          File(imagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(
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
            TextField(
              controller: _text,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: '스토리 문구',
                hintText: '오늘의 한마디를 적어보세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: _canUpload ? _upload : null,
              child: const Text('스토리 올리기'),
            ),
          ],
        ),
      ),
    );
  }
}

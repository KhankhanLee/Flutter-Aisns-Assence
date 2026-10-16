import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:assence/services/media_storage.dart';
import 'package:assence/state/feed_store.dart';

/// 사진과 문구로 내 게시물을 올린다. 올리고 나면 페르소나들이 반응 댓글을 단다.
class ComposePage extends StatefulWidget {
  final VoidCallback? onPosted;

  const ComposePage({super.key, this.onPosted});

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _caption = TextEditingController();
  String? _imagePath;
  bool _posting = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1440,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() => _imagePath = picked.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러오지 못했어요. 카메라/사진 권한을 확인해 주세요.')),
      );
    }
  }

  Future<void> _submit() async {
    final String? source = _imagePath;
    if (source == null || _posting) return;
    setState(() => _posting = true);

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final FeedStore feed = context.read<FeedStore>();
    try {
      final String saved = await persistPickedImage(source, folder: 'posts');
      // 게시물은 바로 피드에 추가되고, AI 반응 댓글은 뒤에서 이어서 달린다.
      feed.addPost(imagePath: saved, caption: _caption.text);
      if (!mounted) return;
      setState(() {
        _imagePath = null;
        _caption.clear();
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('게시물이 올라갔어요. AI 친구들의 반응을 기다려 보세요!')),
      );
      widget.onPosted?.call();
    } on FileSystemException {
      messenger.showSnackBar(
        const SnackBar(content: Text('사진을 저장하지 못했어요. 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? imagePath = _imagePath;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          '새 게시물',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imagePath == null
                ? Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Text(
                        '사진을 선택해 주세요',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : Image.file(File(imagePath), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('앨범'),
                onPressed: _posting ? null : () => _pick(ImageSource.gallery),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('카메라'),
                onPressed: _posting ? null : () => _pick(ImageSource.camera),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _caption,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: '문구 입력',
            hintText: '오늘의 이야기와 #해시태그를 남겨보세요',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: imagePath == null || _posting ? null : _submit,
          child: _posting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('공유하기'),
        ),
      ],
    );
  }
}

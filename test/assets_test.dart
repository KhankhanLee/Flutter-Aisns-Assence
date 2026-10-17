import 'dart:io';
import 'dart:ui' as ui;

import 'package:assence/data/seed_data.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/post.dart';
import 'package:assence/models/story.dart';
import 'package:flutter_test/flutter_test.dart';

/// 시드 데이터가 가리키는 사진이 모두 실제로 열리는 이미지인지 확인한다.
/// (예전 images/Hayeon/Cafe.jpg는 1바이트짜리 빈 파일이라 피드에 사진이 안 떴다.)
void main() {
  final DateTime now = DateTime(2026);
  final Set<String> paths = <String>{
    for (final Persona p in seedPersonas)
      if (p.avatarPath != null) p.avatarPath!,
    for (final Post p in buildSeedPosts(now)) p.imagePath,
    for (final Story s in buildSeedPersonaStories(now)) s.imagePath,
    for (final List<PersonaPhoto> photos in personaPhotos.values)
      for (final PersonaPhoto photo in photos) photo.path,
  };

  for (final String path in paths) {
    test('$path 은 열 수 있는 이미지다', () async {
      final File file = File(path);
      expect(file.existsSync(), isTrue, reason: '파일이 없어요');
      final ui.Codec codec = await ui.instantiateImageCodec(
        await file.readAsBytes(),
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      expect(frame.image.width, greaterThan(100));
      expect(frame.image.height, greaterThan(100));
    });
  }
}

import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:assence/utils/format.dart';

/// image_picker가 준 임시 파일을 앱 문서 폴더로 복사해 재시작 후에도 남게 한다.
Future<String> persistPickedImage(
  String sourcePath, {
  required String folder,
}) async {
  final Directory docs = await getApplicationDocumentsDirectory();
  final Directory target = Directory('${docs.path}/$folder');
  await target.create(recursive: true);

  final int dot = sourcePath.lastIndexOf('.');
  final String extension = dot == -1 ? '.jpg' : sourcePath.substring(dot);
  final File copied = await File(
    sourcePath,
  ).copy('${target.path}/${newId(folder)}$extension');
  return copied.path;
}

/// 사진을 골라 앱 폴더([folder])에 저장하고 경로를 돌려준다. 취소하면 null.
/// 화면에서는 테스트를 위해 이 함수를 주입받아 쓴다.
typedef PhotoPicker = Future<String?> Function(ImageSource source);

/// image_picker로 고른 사진을 [folder]에 보관한다.
PhotoPicker devicePhotoPicker({
  required String folder,
  double maxWidth = 1440,
}) => (ImageSource source) async {
  final XFile? picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: maxWidth,
    imageQuality: 85,
  );
  if (picked == null) return null;
  return persistPickedImage(picked.path, folder: folder);
};

/// 앱이 저장해 둔 사진 파일을 지운다. 없거나 지울 수 없으면 무시한다.
Future<void> deleteKeptPhoto(String? path) async {
  if (path == null) return;
  try {
    final File file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {}
}

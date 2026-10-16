import 'dart:io';

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

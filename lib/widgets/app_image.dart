import 'dart:io';

import 'package:flutter/material.dart';

/// 번들 asset 경로인지 여부. 사용자가 올린 사진은 기기 파일 경로로 저장된다.
bool isAssetPath(String path) =>
    path.startsWith('images/') || path.startsWith('assets/');

/// asset과 기기 파일을 같은 방식으로 그리는 이미지 위젯.
class AppImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;

  const AppImage(
    this.path, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    Widget fallback(
      BuildContext context,
      Object error,
      StackTrace? stackTrace,
    ) {
      return Container(
        width: width,
        height: height ?? 300,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
        ),
      );
    }

    if (isAssetPath(path)) {
      return Image.asset(
        path,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: fallback,
      );
    }
    return Image.file(
      File(path),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: fallback,
    );
  }
}

ImageProvider appImageProvider(String path) => isAssetPath(path)
    ? AssetImage(path)
    : FileImage(File(path)) as ImageProvider;

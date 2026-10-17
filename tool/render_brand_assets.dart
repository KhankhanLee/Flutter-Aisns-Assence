// 앱 아이콘·시작 화면 PNG를 AssenceMarkPainter로 그려 assets/branding/에 저장한다.
//
// 로고를 바꾼 뒤 아래 순서로 다시 생성한다:
//   flutter test tool/render_brand_assets.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:assence/widgets/assence_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _render(
  String path,
  int size,
  CustomPainter painter, {
  double cornerRadius = 0,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Size canvasSize = Size.square(size.toDouble());
  if (cornerRadius > 0) {
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        Offset.zero & canvasSize,
        Radius.circular(size * cornerRadius),
      ),
    );
  }
  painter.paint(canvas, canvasSize);
  final ui.Image image = await recorder.endRecording().toImage(size, size);
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
  final File file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(png!.buffer.asUint8List());
}

void main() {
  test('브랜드 PNG 생성', () async {
    const String dir = 'assets/branding';
    // iOS·구형 Android 아이콘: 배경을 꽉 채운 정사각형 (모서리는 OS가 깎는다)
    await _render('$dir/icon.png', 1024, const AssenceMarkPainter());
    // Android 적응형 아이콘: flutter_launcher_icons가 전경 둘레에 16% 여백을
    // 더하므로, 최종 크기가 일반 아이콘과 비슷하도록 심볼을 크게 그린다.
    await _render(
      '$dir/icon_foreground.png',
      1024,
      const AssenceMarkPainter(drawBackground: false, markScale: 0.66),
    );
    await _render(
      '$dir/icon_background.png',
      1024,
      const AssenceMarkPainter(markScale: 0),
    );
    // 시작 화면(Android 11 이하·iOS): 둥근 사각형 아이콘
    await _render(
      '$dir/splash.png',
      768,
      const AssenceMarkPainter(),
      cornerRadius: 0.23,
    );
    // Android 12+ 시작 화면: 시스템이 원형으로 자르므로 심볼을 더 작게
    await _render(
      '$dir/splash_android12.png',
      1152,
      const AssenceMarkPainter(markScale: 0.4),
    );
  });
}

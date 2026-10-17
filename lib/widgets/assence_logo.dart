import 'package:flutter/material.dart';

/// Assence 브랜드 그라데이션 (보라 → 핑크 → 오렌지).
const List<Color> assenceGradientColors = <Color>[
  Color(0xFF6A3DF0),
  Color(0xFFE6399B),
  Color(0xFFFF9A44),
];

/// Assence 심볼: 말풍선(소통) 안에 반짝임(AI)이 들어간 모양.
///
/// 앱 안의 로고, 시작 화면, 런처 아이콘이 모두 이 painter로 그려진다
/// (아이콘 PNG는 `tool/render_brand_assets.dart`로 생성).
class AssenceMarkPainter extends CustomPainter {
  /// 그라데이션 배경을 칠할지 여부. false면 투명 배경에 심볼만 그린다.
  final bool drawBackground;

  /// 캔버스에서 심볼이 차지하는 비율.
  final double markScale;

  const AssenceMarkPainter({this.drawBackground = true, this.markScale = 0.6});

  static Shader _gradient(Rect rect) => const LinearGradient(
    colors: assenceGradientColors,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(rect);

  /// 꼭짓점 4개짜리 반짝임. [k]가 작을수록 가늘다.
  static Path _sparkle(Offset c, double r, {double k = 0.22}) {
    final double d = r * k;
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + d, c.dy - d, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + d, c.dy + d, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - d, c.dy + d, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - d, c.dy - d, c.dx, c.dy - r)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect full = Offset.zero & size;
    if (drawBackground) {
      canvas.drawRect(full, Paint()..shader = _gradient(full));
    }

    if (markScale <= 0) return;

    // 심볼은 1x1 단위 상자 안에 그린 뒤 캔버스 중앙에 맞춘다.
    final double unit = size.shortestSide * markScale;
    canvas.save();
    canvas.translate((size.width - unit) / 2, (size.height - unit) / 2);
    canvas.scale(unit);

    final Paint white = Paint()..color = Colors.white;
    // 말풍선 몸통 + 왼쪽 아래 꼬리
    canvas.drawRRect(
      RRect.fromLTRBR(0, 0.04, 1, 0.80, const Radius.circular(0.26)),
      white,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0.16, 0.66)
        ..lineTo(0.08, 0.98)
        ..lineTo(0.42, 0.78)
        ..close(),
      white,
    );

    // 말풍선 안의 반짝임 (큰 것 + 작은 것)
    final Paint sparkle = Paint()
      ..shader = _gradient(const Rect.fromLTWH(0, 0, 1, 1));
    canvas.drawPath(_sparkle(const Offset(0.46, 0.43), 0.25), sparkle);
    canvas.drawPath(_sparkle(const Offset(0.76, 0.22), 0.09), sparkle);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AssenceMarkPainter oldDelegate) =>
      oldDelegate.drawBackground != drawBackground ||
      oldDelegate.markScale != markScale;
}

/// 둥근 사각형 앱 아이콘 모양의 심볼.
class AssenceMark extends StatelessWidget {
  final double size;

  const AssenceMark({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.23),
      child: CustomPaint(
        size: Size.square(size),
        painter: const AssenceMarkPainter(),
      ),
    );
  }
}

/// 심볼 + "Assence" 워드마크.
class AssenceLogo extends StatelessWidget {
  final double height;
  final Color color;

  const AssenceLogo({super.key, this.height = 28.0, this.color = Colors.black});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AssenceMark(size: height),
        SizedBox(width: height * 0.3),
        Text(
          'Assence',
          style: TextStyle(
            color: color,
            fontSize: height * 1.25,
            fontFamily: 'Billabong',
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

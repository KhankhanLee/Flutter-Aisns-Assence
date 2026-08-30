import 'package:flutter/material.dart';

class AssenceLogo extends StatelessWidget {
  final double height;
  final Color color;

  const AssenceLogo({
    super.key,
    this.height = 28.0,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Assence 'A' 심볼 엠블럼
        CustomPaint(
          size: Size(height * 0.85, height),
          painter: _AssenceSymbolPainter(color: color),
        ),
        const SizedBox(width: 8),
        // 브랜드 텍스트
        Text(
          'Assence',
          style: TextStyle(
            color: color,
            fontSize: height * 0.8,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            fontFamily: 'Aveny',
          ),
        ),
      ],
    );
  }
}

class _AssenceSymbolPainter extends CustomPainter {
  final Color color;

  _AssenceSymbolPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final Path path = Path();
    // 곡선미를 살린 현대적인 'A' 모티브 엠블럼 그리기
    path.moveTo(size.width * 0.5, 0);
    path.cubicTo(
      size.width * 0.1, size.height * 0.4,
      0, size.height * 0.7,
      0, size.height * 0.85,
    );
    path.cubicTo(
      0, size.height,
      size.width * 0.2, size.height,
      size.width * 0.4, size.height * 0.8,
    );
    path.lineTo(size.width * 0.5, size.height * 0.65);
    path.lineTo(size.width * 0.6, size.height * 0.8);
    path.cubicTo(
      size.width * 0.8, size.height,
      size.width, size.height,
      size.width, size.height * 0.85,
    );
    path.cubicTo(
      size.width, size.height * 0.7,
      size.width * 0.9, size.height * 0.4,
      size.width * 0.5, 0,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

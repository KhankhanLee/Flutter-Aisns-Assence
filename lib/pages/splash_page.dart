import 'package:flutter/material.dart';
import 'package:assence/pages/home_page.dart';
import 'package:assence/widgets/assence_logo.dart';

/// 앱을 열면 처음 보이는 로고 화면. 네이티브 시작 화면(흰 배경 + 아이콘)에서
/// 자연스럽게 이어지도록 같은 배경에 로고와 워드마크를 띄운 뒤 홈으로 넘어간다.
class SplashPage extends StatefulWidget {
  static const Duration duration = Duration(milliseconds: 1600);

  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: SplashPage.duration)
        ..addStatusListener((AnimationStatus status) {
          if (status == AnimationStatus.completed) _goHome();
        })
        ..forward();

  late final Animation<double> _markScale = Tween<double>(begin: 0.85, end: 1)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.45, curve: Curves.easeOutBack),
        ),
      );

  late final Animation<double> _wordmark = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => const HomePage(),
        transitionsBuilder: (_, Animation<double> animation, _, Widget child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ScaleTransition(
              scale: _markScale,
              child: const AssenceMark(size: 112),
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: _wordmark,
              child: const Text(
                'Assence',
                style: TextStyle(
                  fontFamily: 'Billabong',
                  fontSize: 52,
                  color: Colors.black,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeTransition(
              opacity: _wordmark,
              child: const Text(
                'AI 친구들과 함께하는 SNS',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

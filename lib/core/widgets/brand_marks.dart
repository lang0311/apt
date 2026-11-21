import 'package:flutter/material.dart';

/// 카카오 말풍선 심볼. 카카오 로그인 · 카카오톡 공유 버튼에서 같이 쓴다.
/// 노랑(`AppColors.kakao` #FEE500) 바탕 위에 검정으로 둔다 (카카오 로그인 디자인 가이드).
class KakaoSymbol extends StatelessWidget {
  const KakaoSymbol({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _KakaoSymbolPainter()),
  );
}

/// 카카오 공식 심볼 패스(18×18 기준, 카카오 로그인 버튼 리소스)를 그대로 옮겼다. 가운데 맞춰 늘린다.
class _KakaoSymbolPainter extends CustomPainter {
  const _KakaoSymbolPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const box = 18.0;
    final scale = size.width / box;
    canvas.scale(scale, scale);
    // 심볼 높이(0.6 ~ 17.1)를 세로 가운데로
    canvas.translate(0, (box - 17.1 - 0.6) / 2);
    final bubble = Path()
      ..moveTo(9, 0.6)
      ..cubicTo(4.029, 0.6, 0, 3.713, 0, 7.553)
      ..cubicTo(0, 10.05, 1.668, 12.24, 4.17, 13.466)
      ..lineTo(3.323, 16.569)
      ..cubicTo(3.248, 16.845, 3.563, 17.064, 3.805, 16.904)
      ..lineTo(7.517, 14.45)
      ..cubicTo(8.007, 14.518, 8.507, 14.553, 9, 14.553)
      ..cubicTo(13.97, 14.553, 18, 11.44, 18, 7.599)
      ..cubicTo(18, 3.713, 13.97, 0.6, 9, 0.6)
      ..close();
    canvas.drawPath(bubble, Paint()..color = const Color(0xFF000000));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Google 표준 'G' 로고(4색). 아이콘만 있는 로그인 버튼에는 글자 'G' 대신 이 로고를 쓴다
/// (Google 로그인 브랜드 가이드: 흰 바탕 + 회색 테두리 위, 색 · 모양 변경 금지).
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _GoogleMarkPainter()),
  );
}

/// Google 로그인 버튼 리소스의 48×48 'G' 패스를 그대로 옮겼다.
class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    final red = Path()
      ..moveTo(24, 9.5)
      ..cubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1)
      ..lineTo(40.06, 6.25)
      ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
      ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
      ..lineTo(10.54, 19.41)
      ..cubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5)
      ..close();
    final blue = Path()
      ..moveTo(46.98, 24.55)
      ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20)
      ..lineTo(24, 20)
      ..lineTo(24, 29.02)
      ..lineTo(36.94, 29.02)
      ..cubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.2)
      ..lineTo(39.89, 42.2)
      ..cubicTo(44.4, 38.02, 46.98, 31.84, 46.98, 24.55)
      ..close();
    final yellow = Path()
      ..moveTo(10.53, 28.59)
      ..cubicTo(10.05, 27.14, 9.77, 25.6, 9.77, 24)
      ..cubicTo(9.77, 22.4, 10.04, 20.86, 10.53, 19.41)
      ..lineTo(2.55, 13.22)
      ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24)
      ..cubicTo(0, 27.88, 0.92, 31.54, 2.56, 34.78)
      ..lineTo(10.53, 28.59)
      ..close();
    final green = Path()
      ..moveTo(24, 48)
      ..cubicTo(30.48, 48, 35.93, 45.87, 39.89, 42.19)
      ..lineTo(32.16, 36.19)
      ..cubicTo(30.01, 37.64, 27.24, 38.49, 24, 38.49)
      ..cubicTo(17.74, 38.49, 12.43, 34.27, 10.53, 28.58)
      ..lineTo(2.55, 34.77)
      ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
      ..close();
    canvas
      ..drawPath(red, Paint()..color = const Color(0xFFEA4335))
      ..drawPath(blue, Paint()..color = const Color(0xFF4285F4))
      ..drawPath(yellow, Paint()..color = const Color(0xFFFBBC05))
      ..drawPath(green, Paint()..color = const Color(0xFF34A853));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

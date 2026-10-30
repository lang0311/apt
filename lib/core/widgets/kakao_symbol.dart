import 'package:flutter/material.dart';

/// 카카오 말풍선 심볼. 카카오 로그인 · 카카오톡 공유 버튼에서 같이 쓴다.
/// 노랑(`AppColors.kakao`) 바탕 위에 둔다.
class KakaoSymbol extends StatelessWidget {
  const KakaoSymbol({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _KakaoSymbolPainter()),
  );
}

/// 카카오 말풍선 심볼. 카카오 로그인 디자인 가이드: 노랑(#FEE500) 바탕에 검정 심볼.
/// 24×24 기준 좌표를 크기에 맞춰 늘린다.
class _KakaoSymbolPainter extends CustomPainter {
  const _KakaoSymbolPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final bubble = Path()
      ..moveTo(12, 3)
      ..cubicTo(6.48, 3, 2, 6.48, 2, 10.8)
      ..cubicTo(2, 13.58, 3.86, 16.02, 6.66, 17.4)
      // 왼쪽 아래 꼬리
      ..lineTo(5.71, 20.88)
      ..cubicTo(5.63, 21.18, 5.97, 21.43, 6.23, 21.26)
      ..lineTo(10.38, 18.52)
      ..cubicTo(10.91, 18.58, 11.45, 18.61, 12, 18.61)
      ..cubicTo(17.52, 18.61, 22, 15.13, 22, 10.81)
      ..cubicTo(22, 6.49, 17.52, 3, 12, 3)
      ..close();
    canvas.drawPath(bubble, Paint()..color = const Color(0xFF000000));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/kakao_symbol.dart';
import '../../domain/auth_models.dart';

/// 간편 로그인 아이콘 버튼: 카카오(노랑 원 + 공식 말풍선) / Google(흰 원 + 공식 G) / Apple(검정 원).
/// 누르는 영역 48, 화면 낭독기 이름은 "○○로 로그인".
class SocialIconButton extends StatelessWidget {
  const SocialIconButton({super.key, required this.provider, required this.onPressed, this.loading = false});

  final SocialProvider provider;
  final VoidCallback? onPressed;
  final bool loading;

  static const size = 48.0;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (provider) {
      SocialProvider.kakao => (AppColors.kakao, const Color(0xFF191919), null),
      SocialProvider.google => (AppColors.surfaceRaised, AppColors.textPrimary, AppColors.border),
      SocialProvider.apple => (AppColors.ink, Colors.white, null),
    };
    final Widget icon = switch (provider) {
      SocialProvider.kakao => const KakaoSymbol(size: 22),
      SocialProvider.google => const SizedBox.square(dimension: 22, child: CustomPaint(painter: _GoogleMarkPainter())),
      SocialProvider.apple => Icon(Icons.apple, color: fg, size: 26),
    };
    final label = '${provider.label}로 로그인';

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: bg,
          shape: CircleBorder(side: border == null ? BorderSide.none : BorderSide(color: border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: loading ? null : onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: loading
                    ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
                    : icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Google 4색 G. 아이콘만 있는 버튼에는 글자 'G' 대신 공식 G 모양을 쓴다 (Google 브랜드 가이드).
class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    double rad(double deg) => deg * math.pi / 180;
    // 0°는 3시 방향, 시계 방향. 오른쪽 위(-40°~0°)가 G의 열린 곳.
    canvas.drawArc(rect, rad(0), rad(45), false, paint..color = _blue);
    canvas.drawArc(rect, rad(45), rad(100), false, paint..color = _green);
    canvas.drawArc(rect, rad(145), rad(70), false, paint..color = _yellow);
    canvas.drawArc(rect, rad(215), rad(105), false, paint..color = _red);
    // 가운데 가로 막대
    final center = size.height / 2;
    canvas.drawRect(
      Rect.fromLTRB(size.width / 2, center - stroke / 2, size.width, center + stroke / 2),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

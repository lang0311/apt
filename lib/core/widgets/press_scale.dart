import 'package:flutter/widgets.dart';

/// 누르는 동안 살짝 작아졌다가 돌아오는 반응 (토스 · iOS 느낌, 2026-11-23).
/// 누르기 자체는 안쪽 위젯(InkWell 등)이 받고, 이 위젯은 손가락이 닿은 동안 크기만 바꾼다.
/// 움직임 줄이기 설정이 켜져 있으면 크기를 바꾸지 않는다.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.97,
  });

  final Widget child;
  final bool enabled;

  /// 눌렸을 때 크기 (버튼 0.97, 큰 카드는 0.98 정도)
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!widget.enabled || reduce) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 90 : 160),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import 'states.dart';

/// 단계형 로딩 — 오래 걸리는 작업(추출, AI 추천)에서 진행 단계 메시지를 순서대로 보여준다.
/// 실제 진행률을 서버가 주면 그 값을 쓰도록 바꾼다 (NEEDS BACKEND: 진행 상태 조회).
class StagedLoading extends StatefulWidget {
  const StagedLoading({super.key, required this.messages, this.interval = const Duration(milliseconds: 1300)});
  final List<String> messages;
  final Duration interval;

  @override
  State<StagedLoading> createState() => _StagedLoadingState();
}

class _StagedLoadingState extends State<StagedLoading> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      // 마지막 단계에서 멈춘다 (완료처럼 보이지 않게)
      if (_index < widget.messages.length - 1) setState(() => _index++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(liveRegion: true, child: AppLoading(message: widget.messages[_index]));
  }
}

import 'package:flutter/material.dart';

import 'headers.dart';
import 'states.dart';

/// 아직 구현하지 않은 라우트의 임시 화면 (개발 단계별로 실제 화면으로 교체)
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.title, this.showBack = true});
  final String title;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (showBack) SubPageHeader(title: title) else PageTitleHeader(title: title),
            const Expanded(
              child: Center(
                child: AppEmptyState(
                  icon: Icons.construction_rounded,
                  title: '준비 중인 화면이에요',
                  description: '다음 개발 단계에서 구현돼요.',
                  compact: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

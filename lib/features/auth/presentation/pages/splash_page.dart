import 'package:flutter/material.dart';

import '../../../../core/widgets/app_logo.dart';

/// 세션 복원 중
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: AppLogo(size: 64)));
  }
}

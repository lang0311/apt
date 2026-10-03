import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../features/auth/presentation/auth_controller.dart';
import 'deep_link_coordinator.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class AptApp extends ConsumerWidget {
  const AptApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'APT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      scaffoldMessengerKey: scaffoldMessengerKey,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) {
        // 시스템 글꼴 배율은 존중하되 상한 1.3 (docs/03 §1)
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
          child: DeepLinkCoordinator(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

/// 루트 ProviderScope. 세션 만료 콜백을 auth에 연결한다.
class AptRoot extends StatelessWidget {
  const AptRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      // Riverpod 3의 자동 재시도를 끈다: 오류 상태를 즉시 보여주고 사용자가 재시도한다.
      retry: (_, _) => null,
      overrides: [
        sessionExpiredHandlerProvider.overrideWith(
          (ref) => () => ref.read(authControllerProvider.notifier).onSessionExpired(),
        ),
      ],
      child: const AptApp(),
    );
  }
}

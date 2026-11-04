import 'package:apt/app/di/repositories.dart';
import 'package:apt/core/error/app_failure.dart';
import 'package:apt/core/widgets/states.dart';
import 'package:apt/features/auth/domain/auth_models.dart';
import 'package:apt/features/auth/domain/auth_repository.dart';
import 'package:apt/features/auth/presentation/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

var _fail = false;
final _value = FutureProvider<String>((ref) async {
  if (_fail) throw const NetworkFailure();
  return '불러온 목록';
});

/// 세션은 복원되지만 서버 로그아웃 요청은 실패하는 저장소 (오프라인)
class _OfflineLogout implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => const AuthUser(id: 'u', nickname: 'u');

  @override
  Future<void> signOut() async => throw const NetworkFailure();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    _fail = false;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('새로고침이 실패해도 보이던 데이터는 남고, 이유를 스낵바로 알린다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            return Column(children: [
              AsyncValueView<String>(value: ref.watch(_value), data: Text.new),
              TextButton(
                onPressed: () {
                  ref.invalidate(_value);
                  awaitRefresh(context, [ref.read(_value.future)]);
                },
                child: const Text('새로고침'),
              ),
            ]);
          }),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('불러온 목록'), findsOneWidget);

    _fail = true;
    await tester.tap(find.text('새로고침'));
    await tester.pumpAndSettle();

    expect(find.text('불러온 목록'), findsOneWidget);
    expect(find.text('불러오지 못했어요'), findsNothing);
    expect(find.text(const NetworkFailure().message), findsOneWidget);
  });

  testWidgets('처음부터 실패하면 오류 화면을 보여 준다', (tester) async {
    _fail = true;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (_, ref, _) => AsyncValueView<String>(value: ref.watch(_value), data: Text.new)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('불러오지 못했어요'), findsOneWidget);
  });

  test('서버 로그아웃 요청이 실패해도 로그아웃된다', () async {
    final container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(_OfflineLogout())]);
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authControllerProvider).status, AuthStatus.authenticated);

    await container.read(authControllerProvider.notifier).signOut();
    expect(container.read(authControllerProvider).status, AuthStatus.unauthenticated);
  });
}

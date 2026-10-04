import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:apt/app/routes.dart';
import 'package:apt/features/auth/domain/auth_models.dart';

import 'helpers.dart';

/// 실제 기기/에뮬레이터에서 Mock 데이터로 주요 사용자 흐름을 끝까지 실행한다.
/// 실행: `flutter test integration_test -d emulator-5554`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('A. 신규 가입: 카카오 → 약관 → 프로필 → 가입 완료 → 홈', (tester) async {
    await launchApp(tester);
    await tapText(tester, '카카오로 계속하기');

    await waitFor(tester, find.text('약관 동의'));
    final cta = find.widgetWithText(InkWell, '동의하고 계속하기');
    await tapText(tester, '전체 동의');
    await tapFinder(tester, cta);

    await waitFor(tester, find.text('프로필 설정'));
    expect(find.text('여행하는 지상'), findsOneWidget); // 제안 닉네임
    await tapText(tester, '가입 완료하기');

    await waitFor(tester, find.text('가입이 완료됐어요'));
    await tapText(tester, '시작하기');
    await waitFor(tester, find.text('최근 추출한 장소'));
    expectNoErrors(tester);
  });

  testWidgets('B. 계정 충돌 → 기존 계정과 연결 → 홈', (tester) async {
    await launchApp(tester);
    // Apple 버튼은 기본 숨김(FeatureFlags.appleAuthEnabled) → 충돌 응답을 받은 상황을 라우터로 흉내낸다
    expect(find.text('Apple로 계속하기'), findsNothing);
    GoRouter.of(tester.element(find.text('Google로 계속하기'))).push(
      AppRoutes.loginConflict,
      extra: const AccountConflict(
        maskedEmail: 'jis***@gmail.com',
        existingMethodLabel: '이메일로 가입한 계정',
        provider: SocialProvider.google,
      ),
    );
    await waitFor(tester, find.text('이미 가입된 이메일이에요'));
    await tapText(tester, '기존 계정과 연결하기');
    await waitFor(tester, find.text('최근 추출한 장소'));
    expectNoErrors(tester);
  });

  testWidgets('C. 저장됨: 카테고리 필터 → 장소 상세 → 보관함 변경', (tester) async {
    await signInExisting(tester);
    await tapTab(tester, '저장됨');
    await waitFor(tester, find.text('전체 저장 장소'));

    // 맛집 카테고리 선택 → 목록 제목 변경
    await tapText(tester, '맛집');
    await waitFor(tester, find.text('맛집 저장 장소'));
    await tapText(tester, '연남식당');

    await waitFor(tester, find.text('장소 정보'));
    await tapText(tester, '보관함 변경');
    await waitFor(tester, find.text('보관함 변경하기'));
    await tapText(tester, '조용한 카페');
    await tapText(tester, '보관함 변경하기');
    await expectSnack(tester, '보관함을 변경했어요.');
    expectNoErrors(tester);
  });

  testWidgets('D. 보관함: 새 보관함 → 빈 보관함 → 저장한 장소에서 추가', (tester) async {
    await signInExisting(tester);
    await tapTab(tester, '저장됨');
    await tapText(tester, '내 보관함');
    await tapText(tester, '새 보관함 만들기');
    await waitFor(tester, find.text('보관함 이름'));
    await typeInto(tester, find.byType(TextField).last, '서울 가을 산책');
    await tester.pump(const Duration(milliseconds: 300));
    await tapText(tester, '보관함 만들기');

    await waitFor(tester, find.text('아직 저장된 장소가 없어요'));
    await tapText(tester, '저장한 장소에서 추가하기');
    await waitFor(tester, find.text('보관함에 장소 추가'));
    await tapText(tester, '카페 온더뷰');
    await tapText(tester, '보관함에 추가하기 (1)');
    await expectSnack(tester, '1곳을 보관함에 추가했어요.');
    await waitFor(tester, find.text('이 보관함으로 코스 만들기'));
    expectNoErrors(tester);
  });

  testWidgets('E. 추출: 링크 입력 → 결과 검토 → 보관함 선택 → 장소 상세', (tester) async {
    await signInExisting(tester);
    await tapTab(tester, '추출');
    await waitFor(tester, find.text('인스타그램 링크'));
    await typeInto(tester, find.byType(TextField).first, 'https://www.instagram.com/reel/DA7mNpQrStU/');
    await tester.pump(const Duration(milliseconds: 300));
    await tapText(tester, '장소 추출하기');

    await waitFor(tester, find.text('Instagram 링크 분석 완료'));
    // reel → 라쿠치나(저장됨)·한강 노을 포인트(미저장) → 저장 가능한 1곳 기본 선택
    await tapText(tester, '선택한 1곳 저장하기');
    await waitFor(tester, find.text('보관함에 저장'));
    await tapText(tester, '1개 보관함에 저장하기');
    await waitFor(tester, find.text('장소 상세'));
    await waitFor(tester, find.text('한강 노을 포인트'));
    expectNoErrors(tester);
  });

  testWidgets('F. 추출 실패: 비공개 게시물 → 다른 링크 입력하기', (tester) async {
    await signInExisting(tester);
    await tapTab(tester, '추출');
    await typeInto(tester, find.byType(TextField).first, 'https://www.instagram.com/p/private123/');
    await tester.pump(const Duration(milliseconds: 300));
    await tapText(tester, '장소 추출하기');
    await waitFor(tester, find.text('비공개 게시물이에요'));
    await tapText(tester, '다른 링크 입력하기');
    await waitFor(tester, find.text('인스타그램 링크'));
    expectNoErrors(tester);
  });

  testWidgets('G. 코스 만들기: 1/4 → 2/4 → 3/4(함께) → 4/4 → 다른 추천 → 완성 → 상세', (tester) async {
    await signInExisting(tester);
    await tapTab(tester, '코스');
    await waitFor(tester, find.text('내 코스'));
    await tapFinder(tester, find.byTooltip('코스 만들기'));

    // 1/4
    await waitFor(tester, find.text('어떤 여행을 만들까요?'));
    await typeInto(tester, find.byType(TextField).first, '가을 서울 카페 산책');
    await tester.pump(const Duration(milliseconds: 300));
    await tapText(tester, '날짜를 선택해주세요');
    await tapText(tester, '확인', scroll: false);
    await tapText(tester, '시간을 선택해주세요');
    await tapText(tester, '확인', scroll: false);
    await tapText(tester, '산책');
    await tapText(tester, '다음: 저장한 장소 선택');

    // 2/4
    await waitFor(tester, find.text('코스에 넣을 장소를 골라주세요'));
    await tapText(tester, '카페 온더뷰');
    await tapText(tester, '연남식당');
    await tapText(tester, '선택한 장소로 계속하기 (2)');

    // 3/4
    await waitFor(tester, find.text('이번 코스는 누구와 함께하나요?'));
    await tapText(tester, '함께 갈게요');
    await waitFor(tester, find.text('현재 3명'));
    await tapText(tester, '파티원 추가하기');
    await waitFor(tester, find.text('파티원 초대하기'));
    await tapText(tester, '초대 링크 복사');
    await expectSnack(tester, '초대 링크를 복사했어요.');
    await tapText(tester, '닫기', scroll: false);
    await tapText(tester, '다음: 파티 취향 AI 추천');

    // 4/4
    await waitFor(tester, find.text('추천 동선'), timeout: const Duration(seconds: 20));
    expect(find.textContaining('파티 취향 반영'), findsOneWidget);
    expect(find.textContaining('AI 추천 ·'), findsWidgets);
    await tapText(tester, '다른 추천');
    await waitFor(tester, find.byType(LinearProgressIndicator));
    await waitGone(tester, find.byType(LinearProgressIndicator), timeout: const Duration(seconds: 20));
    await tapText(tester, '이 코스로 완성하기');

    await waitFor(tester, find.text('코스가 완성됐어요!'));
    await tapText(tester, '코스 보기');
    await waitFor(tester, find.text('일정'));
    await waitFor(tester, find.text('가을 서울 카페 산책'));
    expectNoErrors(tester);
  });

  testWidgets('H. 코스 상세: 순서 편집 → 다른 추천 받기(루프 재진입) → 저장', (tester) async {
    await signInExisting(tester);
    await tapTab(tester, '코스');
    await tapText(tester, '서울 카페 투어');
    await waitFor(tester, find.text('일정'));
    await tapText(tester, '순서 편집');
    await waitFor(tester, find.text('완료'));
    await tapText(tester, '완료');
    await expectSnack(tester, '코스를 업데이트했어요.');

    await tapText(tester, '다른 추천 받기');
    await waitFor(tester, find.text('추천 동선'), timeout: const Duration(seconds: 20));
    await tapText(tester, '변경 내용 저장하기');
    await waitFor(tester, find.text('일정'));
    expectNoErrors(tester);
  });

  testWidgets('I. 마이: 취향 설정 변경 → 저장 → 로그아웃', (tester) async {
    await signInExisting(tester);
    await tapTab(tester, '마이');
    await waitFor(tester, find.text('취향 설정'));
    await tapText(tester, '취향 설정');
    await waitFor(tester, find.text('어떤 곳을 좋아하세요?'));
    await tapText(tester, '쇼핑');
    await waitFor(tester, find.text('8개 선택'));
    await tapText(tester, '취향 저장하기');
    await expectSnack(tester, '취향을 저장했어요.');

    await tapText(tester, '로그아웃');
    await tapText(tester, '로그아웃', index: 1, scroll: false);
    await waitFor(tester, find.text('Google로 계속하기'));
    expectNoErrors(tester);
  });

  testWidgets('J. 초대 링크(미로그인) → 로그인 → 초대 수락 → 참여', (tester) async {
    await launchApp(tester);
    // 초대 링크로 앱에 들어온 상황을 라우터로 흉내낸다 (App Links 설정 전)
    GoRouter.of(tester.element(find.text('Google로 계속하기'))).go('/invites/demo');
    await tester.pump(const Duration(milliseconds: 500));
    // 미로그인 → 토큰 보관 후 로그인 화면으로
    await tapText(tester, 'Google로 계속하기');
    await waitFor(tester, find.text('민지님이 코스에 초대했어요'));
    await tapText(tester, '코스에 참여하기');
    await waitFor(tester, find.text('모임 / 파티 코스'));
    expectNoErrors(tester);
  });
}

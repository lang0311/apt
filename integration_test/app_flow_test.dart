import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:apt/app/routes.dart';
import 'package:apt/features/auth/domain/auth_models.dart';
import 'package:apt/features/home/presentation/home_page.dart';

import 'helpers.dart';

/// 실제 기기/에뮬레이터에서 Mock 데이터로 주요 사용자 흐름을 끝까지 실행한다.
/// 실행: `flutter test integration_test -d emulator-5554`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('A. 신규 가입: 카카오 → 약관 → 프로필 → 가입 완료 → 홈', (tester) async {
    await launchApp(tester);
    await tapFinder(tester, find.byTooltip('카카오로 로그인'), scroll: false);

    await waitFor(tester, find.text('서비스 이용에 동의해 주세요'));
    final cta = find.widgetWithText(InkWell, '동의하고 계속하기');
    await tapText(tester, '전체 동의');
    await tapFinder(tester, cta);

    await waitFor(tester, find.text('어떻게 불러\n드릴까요?'));
    expect(find.text('여행하는 지상'), findsOneWidget); // 제안 닉네임
    await tapText(tester, '가입 완료');

    await waitFor(tester, find.textContaining('가입이 끝났어요'));
    await tapText(tester, '시작하기');
    await waitFor(tester, find.byType(HomePage));
    expectNoErrors(tester);
  });

  testWidgets('B. 계정 충돌 → 기존 계정과 연결 → 홈', (tester) async {
    await launchApp(tester);
    // Apple 버튼은 기본 숨김(FeatureFlags.appleAuthEnabled) → 충돌 응답을 받은 상황을 라우터로 흉내낸다
    expect(find.byTooltip('Apple로 로그인'), findsNothing);
    GoRouter.of(tester.element(find.byTooltip('Google로 로그인'))).push(
      AppRoutes.loginConflict,
      extra: const AccountConflict(maskedEmail: 'jis***@gmail.com', existingMethodLabel: '이메일로 가입한 계정', provider: SocialProvider.google),
    );
    await waitFor(tester, find.text('이미 가입된 이메일이에요'));
    await tapText(tester, '기존 계정과 연결하기');
    await waitFor(tester, find.byType(HomePage));
    expectNoErrors(tester);
  });

  testWidgets('C. 저장됨: 카테고리 필터 → 장소 상세 → 보관함 변경', (tester) async {
    await signInExisting(tester);
    await tapTab(tester, '저장됨');
    await waitFor(tester, find.text('보관함'));
    await tester.pump(const Duration(seconds: 1));

    // 기본 보기는 지역별 → 업종별로 바꾸면 필터가 업종으로
    await tapText(tester, '지역별', scroll: false);
    await tapText(tester, '업종별', scroll: false);
    // 필터 시트에서 맛집 → 고른 값만 칩으로
    await tapText(tester, '필터', scroll: false);
    await tapFinder(tester, find.text('맛집').last, scroll: false); // 뒤 목록의 묶음 제목이 아니라 시트의 항목
    await tapFinder(tester, find.textContaining('곳 보기'), scroll: false);
    await waitFor(tester, find.bySemanticsLabel('맛집 필터 해제'));
    await tapText(tester, '연남식당');

    await waitFor(tester, find.text('장소 정보'));
    // 담은 보관함 카드의 '변경'
    await tapText(tester, '변경');
    await waitFor(tester, find.text('보관함 변경하기'));
    await tapText(tester, '조용한 카페');
    await tapText(tester, '보관함 변경하기');
    await expectSnack(tester, '보관함을 변경했어요.');
    expectNoErrors(tester);
  });

  testWidgets('D. 보관함: 새 보관함 → 빈 보관함 → 저장한 장소에서 추가', (tester) async {
    await signInExisting(tester);
    await tapTab(tester, '저장됨');
    await tapText(tester, '보관함', scroll: false); // 저장됨 탭 [전체 | 보관함 | AI 추천]
    await tapText(tester, '새 보관함');
    await waitFor(tester, find.text('보관함 이름'));
    await typeInto(tester, find.byType(TextField).last, '서울 가을 산책');
    await tester.pump(const Duration(milliseconds: 300));
    await tapText(tester, '보관함 만들기');

    await waitFor(tester, find.text('아직 담은 장소가 없어요'));
    await tapText(tester, '저장한 장소에서 추가하기');
    await waitFor(tester, find.text('보관함에 장소 추가'));
    await tapFinder(tester, find.textContaining('목록 '), scroll: false);
    await tapText(tester, '카페 온더뷰');
    await tapText(tester, '보관함에 추가', scroll: false);
    await expectSnack(tester, '1곳을 보관함에 추가했어요.');
    await waitFor(tester, find.text('이 보관함으로 코스 만들기'));
    expectNoErrors(tester);
  });

  testWidgets('E. 추출: 링크 입력 → 찾은 장소 → 보관함 고르기 → 저장(결과에 남음) → 보기 → 장소 상세', (tester) async {
    await signInExisting(tester);
    await tapTab(tester, '장소 추가');
    await waitFor(tester, find.text('릴스에서 바로 저장하는 게 가장 빨라요'));
    await typeInto(tester, find.byType(TextField).first, 'https://www.instagram.com/reel/DA7mNpQrStU/');
    await tester.pump(const Duration(milliseconds: 300));
    await tapText(tester, '찾기');

    await waitFor(tester, find.text('2곳을 찾았어요'));
    // reel → 라쿠치나(저장됨)·한강 노을 포인트(미저장) → 저장 가능한 1곳 기본 선택
    await tapText(tester, '보관함 고르기 ›');
    await waitFor(tester, find.text('새 보관함'));
    await tapText(tester, '확인');
    await tapText(tester, '1곳 저장');
    // 저장 뒤에는 결과에 남고 스낵바 (07 D26 ①)
    await waitFor(tester, find.text('1곳을 저장했어요'));
    expect(find.text('완료'), findsOneWidget);
    await tapText(tester, '보기', scroll: false);
    await waitFor(tester, find.text('장소 정보'));
    await waitFor(tester, find.text('한강 노을 포인트'));
    expectNoErrors(tester);
  });

  testWidgets('F. 추출 실패: 비공개 게시물 → 다른 링크 넣기', (tester) async {
    await signInExisting(tester);
    await tapTab(tester, '장소 추가');
    await typeInto(tester, find.byType(TextField).first, 'https://www.instagram.com/p/private123/');
    await tester.pump(const Duration(milliseconds: 300));
    await tapText(tester, '찾기');
    await waitFor(tester, find.text('비공개 게시물이에요'));
    await tapText(tester, '다른 링크 넣기');
    await waitFor(tester, find.text('릴스에서 바로 저장하는 게 가장 빨라요'));
    expectNoErrors(tester);
  });

  testWidgets('G. 코스 만들기: 1/4 → 2/4(함께) → 3/4(지도·목록) → 4/4(추천 취소 → 다시) → 다시 추천 → 저장 → 상세', (tester) async {
    await signInExisting(tester);
    await tapTab(tester, '코스');
    await waitFor(tester, find.textContaining('내 코스', findRichText: true));
    await tapFinder(tester, find.byTooltip('코스 만들기'));

    // 1/4
    await waitFor(tester, find.text('어떤 코스를 만들까요?'));
    await typeInto(tester, find.byType(TextField).first, '가을 서울 카페 산책');
    await tester.pump(const Duration(milliseconds: 300));
    await tapText(tester, '내일'); // 날짜 칩. 출발 시간은 오전 11:00으로 채워진다
    expect(find.text('오전 11:00'), findsOneWidget);
    await tapText(tester, '다음');

    // 2/4
    await waitFor(tester, find.text('누구와 함께 가나요?'));
    await tapText(tester, '함께 가요');
    await waitFor(tester, find.text('어느 파티와 갈까요?'));
    // 새 파티: 초대하기를 누를 때 파티가 생긴다
    await tapText(tester, '새 파티 만들기');
    await waitFor(tester, find.text('파티원 1'));
    await tapText(tester, '초대하기');
    await waitFor(tester, find.text('파티원 초대'));
    await tapText(tester, '초대 링크 복사', scroll: false);
    await expectSnack(tester, '초대 링크를 복사했어요.');
    await tester.tapAt(const Offset(20, 120)); // 시트 바깥을 눌러 닫는다
    await tester.pump(const Duration(milliseconds: 500));
    // 기존 파티로 간다
    await tapText(tester, '나, 민지, 랑이');
    expect(find.text('파티원 1'), findsNothing);
    await tapText(tester, '다음');

    // 3/4 — 목록으로 바꿔 두 곳 고르기
    await tapFinder(tester, find.textContaining('목록 '), scroll: false);
    await tapText(tester, '카페 온더뷰');
    await tapText(tester, '연남식당');
    await waitFor(tester, find.text('고른 곳 2'));
    await tapFinder(tester, find.textContaining('곳 코스 추천받기'), scroll: false);

    // 4/4 기다리는 중 — 단계 표시(파티 코스는 파티원 취향 단계) → 추천 취소 → 3/4로, 고른 장소 유지
    await waitFor(tester, find.text('후보 장소 찾기'));
    expect(find.text('파티원 취향 맞추기'), findsOneWidget);
    await tapText(tester, '추천 취소', scroll: false);
    await expectSnack(tester, '추천을 취소했어요');
    await waitFor(tester, find.text('고른 곳 2'));
    await tapFinder(tester, find.textContaining('곳 코스 추천받기'), scroll: false);

    // 4/4
    await waitFor(tester, find.text('코스 저장'), timeout: const Duration(seconds: 20));
    expect(find.textContaining(RegExp(r'^일정 \d+곳$')), findsOneWidget);
    await tapText(tester, '다시 추천', scroll: false);
    // 결과 스낵바 '추천 장소 n곳을 바꿨어요' (일정 아래 안내 문구에도 '추천 장소'가 있어 끝까지 맞춘다)
    await waitFor(tester, find.textContaining(RegExp(r'추천 장소 \d+곳을 바꿨어요')), timeout: const Duration(seconds: 20));
    await waitGone(tester, find.byType(SnackBar), timeout: const Duration(seconds: 12));
    await tapText(tester, '코스 저장', scroll: false);

    // 완료 화면 없이 바로 상세, 파티 코스라 파티원에게 알릴지 묻는다
    await waitFor(tester, find.text('코스가 저장되었어요'));
    await waitFor(tester, find.text('민지, 랑이에게 알릴까요?'));
    await tapText(tester, '코스 링크 복사', scroll: false);
    await expectSnack(tester, '코스 링크를 복사했어요.');
    await tapText(tester, '나중에', scroll: false);
    await waitGone(tester, find.text('민지, 랑이에게 알릴까요?'));
    await waitFor(tester, find.text('가을 서울 카페 산책'));
    // 파티원 시트에서 다시 알릴 수 있다
    await tapText(tester, '나, 민지, 랑이');
    await waitFor(tester, find.text('코스 알리기'));
    expectNoErrors(tester);
  });

  testWidgets('H. 코스 상세 → 편집: 이번만 빼기 → 다시 추천 취소 → 다시 추천 → 저장', (tester) async {
    await signInExisting(tester);
    await tapTab(tester, '코스');
    await tapText(tester, '서울 카페 투어');
    await waitFor(tester, find.textContaining(RegExp(r'^일정 \d+곳$')));
    await tapText(tester, '편집');
    await waitFor(tester, find.text('코스 편집'));

    final removeButtons = find.byWidgetPredicate((w) => w is IconButton && (w.tooltip?.endsWith(' 빼기') ?? false));
    await tapFinder(tester, removeButtons, scroll: false);
    await waitFor(tester, find.textContaining('이번 코스에서 뺐어요'));
    await waitGone(tester, find.byType(SnackBar), timeout: const Duration(seconds: 8));

    // 다시 추천 중 취소 → 이전 일정 그대로
    await tapText(tester, '다시 추천', scroll: false);
    await waitFor(tester, find.textContaining('다시 고르고 있어요'));
    await tapText(tester, '취소', scroll: false);
    await expectSnack(tester, '추천을 취소했어요');
    expect(find.textContaining('다시 고르고 있어요'), findsNothing);
    await waitGone(tester, find.byType(SnackBar), timeout: const Duration(seconds: 8));

    await tapText(tester, '다시 추천', scroll: false);
    await waitFor(tester, find.textContaining(RegExp(r'추천 장소 \d+곳을 바꿨어요')), timeout: const Duration(seconds: 20));
    await waitGone(tester, find.byType(SnackBar), timeout: const Duration(seconds: 12));
    await tapText(tester, '저장', scroll: false);
    await expectSnack(tester, '코스를 저장했어요');
    await waitFor(tester, find.textContaining(RegExp(r'^일정 \d+곳$')));
    expectNoErrors(tester);
  });

  testWidgets('I. 마이: 내 취향 보기(저장한 장소 기준) → 뒤로 → 로그아웃', (tester) async {
    await signInExisting(tester);
    await tapTab(tester, '마이');
    await waitFor(tester, find.text('저장한 곳'));
    // v2(07 D64): 취향은 직접 고르지 않고 저장한 장소로 읽는다 — '수정' 대신 '보기'
    await tapText(tester, '보기');
    await waitFor(tester, find.textContaining('저장한 장소로 취향을 읽어요'));
    expect(find.text('취향 저장하기'), findsNothing);
    await tapFinder(tester, find.byTooltip('뒤로'), scroll: false);
    await waitFor(tester, find.text('저장한 곳'));

    await tapText(tester, '로그아웃');
    await tapText(tester, '로그아웃', index: 1, scroll: false);
    await waitFor(tester, find.byTooltip('Google로 로그인'));
    expectNoErrors(tester);
  });

  testWidgets('K. 아이디 가입: 회원가입 → 약관 → 계정 정보(중복 아이디 오류) → 가입 완료 → 홈', (tester) async {
    await launchApp(tester);
    await tapText(tester, '회원가입');

    await waitFor(tester, find.text('서비스 이용에 동의해 주세요'));
    await tapText(tester, '전체 동의');
    await tapFinder(tester, find.widgetWithText(InkWell, '동의하고 계속하기'));

    await waitFor(tester, find.text('계정을 만들어 주세요'));
    final fields = find.byType(TextField);
    await typeInto(tester, fields.at(0), 'taken'); // Mock: 이미 사용 중
    await typeInto(tester, fields.at(1), 'password1');
    await typeInto(tester, fields.at(2), '여행하는 지상');
    await tapText(tester, '가입하기');
    await waitFor(tester, find.text('이미 사용 중인 아이디예요.'));

    await typeInto(tester, fields.at(0), 'trip_jin');
    await tapText(tester, '가입하기');
    await waitFor(tester, find.textContaining('가입이 끝났어요'));
    await tapText(tester, '시작하기');
    await waitFor(tester, find.byType(HomePage));
    expectNoErrors(tester);
  });

  testWidgets('L. 아이디 로그인: 틀린 비밀번호 → 오류 → 로그인 → 홈', (tester) async {
    await launchApp(tester);
    final fields = find.byType(TextField);
    await typeInto(tester, fields.at(0), 'demo_user1');
    await typeInto(tester, fields.at(1), 'wrongpass');
    await tapText(tester, '로그인');
    await waitFor(tester, find.text('아이디 또는 비밀번호가 맞지 않아요.'));

    await typeInto(tester, fields.at(1), 'password1'); // Mock: password1만 성공
    await tapText(tester, '로그인');
    await waitFor(tester, find.byType(HomePage));
    expectNoErrors(tester);
  });

  testWidgets('M. 4/4 결과: 하단 사진 줄 장소 → 시트 → 장소 정보 보기 (셸 밖에서 장소 상세를 열어도 오류 없음)', (tester) async {
    await signInExisting(tester);
    await tapTab(tester, '코스');
    await waitFor(tester, find.textContaining('내 코스', findRichText: true));
    await tapFinder(tester, find.byTooltip('코스 만들기'));
    await waitFor(tester, find.text('어떤 코스를 만들까요?'));
    await typeInto(tester, find.byType(TextField).first, '장소 정보 확인');
    await tapText(tester, '내일');
    await tapText(tester, '다음');
    await waitFor(tester, find.text('누구와 함께 가나요?'));
    await tapText(tester, '다음');
    await tester.pump(const Duration(seconds: 2));
    await tapFinder(tester, find.textContaining('목록 '), scroll: false);
    await tapText(tester, '카페 온더뷰');
    await tapText(tester, '연남식당');
    await tapFinder(tester, find.textContaining('곳 코스 추천받기'), scroll: false);
    await waitFor(tester, find.text('코스 저장'), timeout: const Duration(seconds: 25));
    await tester.scrollUntilVisible(find.text('이 코스에 담긴 곳'), 300, scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.descendant(of: find.byType(ListView).last, matching: find.text('연남식당')).first);
    await waitFor(tester, find.text('장소 정보 보기'));
    await tapText(tester, '장소 정보 보기', scroll: false);
    await waitFor(tester, find.text('장소 정보'));
    expectNoErrors(tester);
  });
}

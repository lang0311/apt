import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/dev/mock/mock_fixtures.dart';
import 'package:apt/features/auth/domain/auth_models.dart';
import 'package:apt/features/auth/presentation/auth_controller.dart';
import 'package:apt/features/course/presentation/course_draft_controller.dart';
import 'package:apt/features/course/presentation/pages/add_places_page.dart';
import 'package:apt/features/course/presentation/pages/ai_recommendation_page.dart';
import 'package:apt/features/course/presentation/pages/companion_page.dart';
import 'package:apt/features/course/presentation/pages/course_done_page.dart';
import 'package:apt/features/course/presentation/pages/course_info_page.dart';
import 'package:apt/features/course/presentation/pages/place_selection_page.dart';
import 'package:apt/features/extraction/presentation/pages/extraction_result_page.dart';
import 'package:apt/features/party/presentation/invite_accept_page.dart';
import 'package:apt/features/saved/domain/saved_models.dart';
import 'package:apt/features/saved/presentation/pages/saved_map_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 위저드·추출·지도·초대 화면을 작은 기기(360x640)와 큰 기기(430x932)에서 렌더링한다.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const sizes = {'360x640': Size(360, 640), '430x932': Size(430, 932)};

  final screens = <String, Widget Function()>{
    '1/4 기본 정보': () => const CourseInfoPage(),
    '2/4 장소 선택': () => const PlaceSelectionPage(),
    '3/4 동행 설정': () => const CompanionPage(),
    '4/4 AI 추천': () => const AiRecommendationPage(),
    '장소 추가': () => const AddPlacesPage(args: AddPlacesArgs()),
    '코스 완성': () => const CourseDonePage(courseId: 'k1'),
    '추출 결과': () => const ExtractionResultPage(url: 'https://www.instagram.com/p/C3k9xYzAbcD/'),
    '추출 실패(비공개)': () => const ExtractionResultPage(url: 'https://www.instagram.com/p/private1/'),
    '카테고리 지도': () => const SavedMapPage(mode: SavedMapMode.category),
    '보관함 지도': () => const SavedMapPage(mode: SavedMapMode.collection, initialCollectionId: 'c1'),
    '초대 수락': () => const InviteAcceptPage(token: 'demo'),
    '초대 만료': () => const InviteAcceptPage(token: 'expired'),
  };

  for (final size in sizes.entries) {
    for (final screen in screens.entries) {
      testWidgets('${screen.key} @ ${size.key}', (tester) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final container = ProviderContainer(retry: (_, _) => null);
        addTearDown(container.dispose);
        // 위저드 진행 중 상태 + 로그인 상태
        container.read(courseDraftProvider.notifier)
          ..start(places: [MockFixtures.place('p1'), MockFixtures.place('p4')])
          ..update((d) => d.copyWith(name: '가을 서울 카페 산책', date: DateTime(2026, 10, 12), startTime: const TimeOfDay(hour: 11, minute: 0)));
        // Mock 지연은 실제 타이머라 fake async 밖에서 실행한다 (Google = 기존 회원 → 로그인 상태)
        await tester.runAsync(() => container.read(authControllerProvider.notifier).signInWithSocial(SocialProvider.google));
        expect(container.read(authControllerProvider).status, AuthStatus.authenticated);

        await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.light(), home: screen.value()),
        ));
        // Mock 지연(추출/추천 최대 2.6초)을 지나 결과 상태까지
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(seconds: 1));
        }

        final error = tester.takeException();
        if (error is FlutterError) debugPrint(error.toStringDeep());
        expect(error, isNull);

        // 남은 타이머(단계형 로딩 등)를 정리
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      });
    }
  }
}

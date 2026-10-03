import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/features/auth/presentation/pages/social_login_page.dart';
import 'package:apt/features/course/presentation/pages/course_detail_page.dart';
import 'package:apt/features/course/presentation/pages/courses_page.dart';
import 'package:apt/features/extraction/presentation/pages/link_input_page.dart';
import 'package:apt/features/home/presentation/home_page.dart';
import 'package:apt/features/my/presentation/my_page.dart';
import 'package:apt/features/place/presentation/place_detail_page.dart';
import 'package:apt/features/preference/presentation/preference_page.dart';
import 'package:apt/features/saved/presentation/pages/collection_detail_page.dart';
import 'package:apt/features/saved/presentation/pages/saved_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 주요 화면을 3가지 기기 크기에서 렌더링해 레이아웃 overflow가 없는지 확인한다 (docs/03 §1).
/// Mock Repository를 그대로 사용한다.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const sizes = {
    '360x640': Size(360, 640),
    '390x844': Size(390, 844),
    '430x932': Size(430, 932),
  };

  final screens = <String, Widget Function()>{
    '소셜 로그인': () => const SocialLoginPage(),
    '홈': () => const HomePage(),
    '저장됨': () => const SavedPage(),
    '보관함 상세': () => const CollectionDetailPage(collectionId: 'c1'),
    '장소 상세': () => const PlaceDetailPage(placeId: 'p1'),
    '링크 입력': () => const LinkInputPage(),
    '코스 목록': () => const CoursesPage(),
    '코스 상세': () => const CourseDetailPage(courseId: 'k1'),
    '마이': () => const MyPage(),
    '취향 설정': () => const PreferencePage(),
  };

  for (final size in sizes.entries) {
    for (final screen in screens.entries) {
      testWidgets('${screen.key} @ ${size.key}', (tester) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(ProviderScope(
          retry: (_, _) => null,
          child: MaterialApp(theme: AppTheme.light(), home: screen.value()),
        ));
        // Mock 지연(기본 600ms)을 지나 데이터 상태까지 렌더링
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        final error = tester.takeException();
        if (error is FlutterError) debugPrint(error.toStringDeep());
        expect(error, isNull);
      });
    }
  }
}

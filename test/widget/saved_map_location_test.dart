import 'package:apt/app/theme/app_theme.dart';
import 'package:apt/core/location/location_service.dart';
import 'package:apt/core/models/geo_point.dart';
import 'package:apt/features/saved/domain/saved_models.dart';
import 'package:apt/features/saved/presentation/pages/saved_map_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeLocationService implements LocationService {
  _FakeLocationService(this.result);
  final LocationResult result;
  int calls = 0;

  @override
  Future<LocationResult> current({bool request = true}) async {
    calls++;
    return result;
  }

  @override
  Future<void> openSettings(LocationStatus status) async {}
}

/// 저장 지도의 위치 권한 처리. 테스트에는 SDK가 없어서 미리보기 지도로 그려진다 (카메라 명령은 무시).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<_FakeLocationService> pumpMap(WidgetTester tester, LocationResult location, SavedMapMode mode) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _FakeLocationService(location);
    await tester.pumpWidget(ProviderScope(
      overrides: [locationServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: SavedMapPage(mode: mode, initialCollectionId: mode == SavedMapMode.collection ? 'c1' : null),
      ),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    return service;
  }

  // 남은 타이머(Mock 지연·debounce·스낵바)를 정리
  Future<void> disposeMap(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('지도에 들어오면 위치를 묻고, 허용하면 가까운 순으로 정렬한다', (tester) async {
    final service =
        await pumpMap(tester, const LocationResult(LocationStatus.granted, GeoPoint(37.5446, 127.0557)), SavedMapMode.collection);

    expect(service.calls, 1);
    expect(find.text('가까운 순 ▾'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeMap(tester);
  });

  testWidgets('위치를 거부해도 지도는 그대로 쓰고, 가까운 순 대신 최근 저장으로 보여준다', (tester) async {
    await pumpMap(tester, const LocationResult(LocationStatus.denied), SavedMapMode.collection);

    expect(find.text('최근 저장 ▾'), findsOneWidget);
    await tester.tap(find.text('최근 저장 ▾'));
    await tester.pumpAndSettle();
    // 위치가 없으면 정렬 시트에 '가까운 순'이 없다
    expect(find.text('가까운 순'), findsNothing);
    expect(find.text('평점 순'), findsOneWidget);
    await disposeMap(tester);
  });

  testWidgets('내 위치 버튼: 영구 거부면 설정 열기를 안내한다', (tester) async {
    await pumpMap(tester, const LocationResult(LocationStatus.deniedForever), SavedMapMode.category);

    await tester.tap(find.byTooltip('내 위치'));
    await tester.pump();
    expect(find.text('설정에서 위치 권한을 허용해주세요.'), findsOneWidget);
    expect(find.text('설정 열기'), findsOneWidget);
    await disposeMap(tester);
  });
}

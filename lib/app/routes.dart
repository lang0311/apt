/// 라우트 경로 (docs/05 요약 표의 제안 라우트)
abstract final class AppRoutes {
  static const splash = '/splash';

  static const login = '/login';
  static const loginConflict = '/login/conflict';
  static const loginError = '/login/error';
  static const loginEmail = '/login/email';
  static const signupTerms = '/signup/terms';
  static const signupProfile = '/signup/profile';

  /// 아이디 가입: 약관 다음 계정 정보 (07 D28)
  static const signupAccount = '/signup/account';
  static const signupDone = '/signup/done';

  static const home = '/home';

  static const extract = '/extract';

  /// 지도에서 검색하기 (하단 탭 없이 전체 화면, 07 D32)
  static const placeSearch = '/place-search';
  static String extractResult(String url) => Uri(path: '/extract/result', queryParameters: {'url': url}).toString();

  static const saved = '/saved';
  static String collection(String id) => '/saved/collections/$id';
  /// 저장 지도. [categoryKeys]는 고른 카테고리(여러 개), [aiOnly]면 추천받은 곳만 켜진 채로 연다 (07 D48)
  static String categoryMap({Set<String> categoryKeys = const {}, bool aiOnly = false}) => Uri(path: '/saved/map', queryParameters: {
        'mode': 'category',
        if (categoryKeys.isNotEmpty) 'key': categoryKeys.toList(),
        if (aiOnly) 'source': 'ai',
      }).toString();
  static String collectionMap({String? collectionId}) =>
      Uri(path: '/saved/map', queryParameters: {'mode': 'collection', 'id': ?collectionId}).toString();

  static String place(String id) => '/places/$id';

  static const courses = '/courses';
  /// 코스 목록의 '함께하는 코스' 탭
  static const coursesParty = '/courses?tab=party';
  static String course(String id, {bool justSaved = false}) => justSaved ? '/courses/$id?saved=1' : '/courses/$id';
  static String courseEdit(String id) => '/course-edit/$id';
  static const courseNewInfo = '/courses/new/info';
  static const courseNewPlaces = '/courses/new/places';
  static const courseNewCompanion = '/courses/new/companion';
  static const courseNewAi = '/courses/new/ai';

  /// 저장하지 않은 추천 이어 보기 (13번) — 4/4에 저장 안내 한 줄을 붙인다
  static const courseNewAiResumed = '$courseNewAi?resumed=1';
  static const pickPlaces = '/courses/pick-places';

  /// 코스 지도 크게 보기 (전체 화면, `extra`로 [CourseMapArgs]를 받는다)
  static const courseMap = '/course-map';

  static String invite(String token) => '/invites/$token';

  static const my = '/my';
  static const preferences = '/my/preferences';
  static const blockedPlaces = '/my/blocked-places';
  static const preferencesOnboarding = '/my/preferences?mode=onboarding';
}

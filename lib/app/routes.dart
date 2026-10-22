/// 라우트 경로 (docs/05 요약 표의 제안 라우트)
abstract final class AppRoutes {
  static const splash = '/splash';

  static const login = '/login';
  static const loginConflict = '/login/conflict';
  static const loginError = '/login/error';
  static const loginEmail = '/login/email';
  static const signupTerms = '/signup/terms';
  static const signupProfile = '/signup/profile';
  static const signupDone = '/signup/done';

  static const home = '/home';

  static const extract = '/extract';
  static String extractResult(String url, {bool fromShare = false}) =>
      Uri(path: '/extract/result', queryParameters: {'url': url, if (fromShare) 'from': 'share'}).toString();

  static const saved = '/saved';
  static String collection(String id) => '/saved/collections/$id';
  static String categoryMap({String? categoryKey}) =>
      Uri(path: '/saved/map', queryParameters: {'mode': 'category', 'key': ?categoryKey}).toString();
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
  static const pickPlaces = '/courses/pick-places';

  static String invite(String token) => '/invites/$token';

  static const my = '/my';
  static const preferences = '/my/preferences';
  static const blockedPlaces = '/my/blocked-places';
  static const preferencesOnboarding = '/my/preferences?mode=onboarding';
}

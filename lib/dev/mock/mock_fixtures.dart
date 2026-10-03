// 개발용 샘플 데이터. 프리뷰 SVG 문구를 재사용해 시안 대비 확인을 쉽게 한다 (docs/06 §6).
// 화면(Widget) 코드에서 직접 참조하지 않는다 — Mock Repository만 사용한다.

import 'package:flutter/material.dart';

import '../../core/models/geo_point.dart';
import '../../features/course/domain/course_models.dart';
import '../../features/place/domain/place.dart';
import '../../features/preference/domain/preference_models.dart';
import '../../features/saved/domain/saved_models.dart';

String _img(String seed) => 'https://picsum.photos/seed/apt-$seed/480/360';

abstract final class MockFixtures {
  static const categories = <String, String>{
    'restaurant': '맛집',
    'cafe': '카페',
    'tour': '관광',
    'culture': '문화',
    'stay': '숙소',
  };

  static final places = <Place>[
    Place(
      id: 'p1',
      name: '카페 온더뷰',
      address: '서울 성동구 성수이로 18길 12',
      areaLabel: '서울 성동구 성수동',
      categoryKey: 'cafe',
      categoryLabel: '카페',
      imageUrl: _img('ontheview'),
      rating: 4.7,
      keywords: const ['오션뷰', '감성 카페', '데이트'],
      location: const GeoPoint(37.5446, 127.0557),
      sourceUrl: 'https://www.instagram.com/p/C3k9xYzAbcD/',
      sourceHandle: '@seoul_daily',
    ),
    Place(
      id: 'p2',
      name: '코지 베이커리',
      address: '서울 성동구 연무장길 41',
      areaLabel: '서울 성동구 연무장길',
      categoryKey: 'cafe',
      categoryLabel: '베이커리',
      imageUrl: _img('cozybakery'),
      rating: 4.6,
      keywords: const ['디저트', '데이트'],
      location: const GeoPoint(37.5432, 127.0589),
      sourceUrl: 'https://www.instagram.com/p/C3k9xYzAbcD/',
      sourceHandle: '@seoul_daily',
    ),
    Place(
      id: 'p3',
      name: '연남식당',
      address: '서울 마포구 연남로 31',
      areaLabel: '서울 마포구 연남동',
      categoryKey: 'restaurant',
      categoryLabel: '한식',
      imageUrl: _img('yeonnam'),
      rating: 4.5,
      keywords: const ['한식', '데이트'],
      location: const GeoPoint(37.5413, 127.0532),
    ),
    Place(
      id: 'p4',
      name: '라쿠치나',
      address: '서울 용산구 이태원로 27',
      areaLabel: '서울 용산구 이태원동',
      categoryKey: 'restaurant',
      categoryLabel: '이탈리안',
      imageUrl: _img('lacucina'),
      rating: 4.4,
      keywords: const ['이탈리안', '맛집', '분위기 좋은'],
      location: const GeoPoint(37.5461, 127.0611),
      sourceUrl: 'https://www.instagram.com/reel/DA7mNpQrStU/',
      sourceHandle: '@food_seoul',
    ),
    Place(
      id: 'p5',
      name: '성수 정원',
      address: '서울 성동구 서울숲길 17',
      areaLabel: '서울 성동구 성수동',
      categoryKey: 'tour',
      categoryLabel: '공원',
      imageUrl: _img('garden'),
      rating: 4.6,
      keywords: const ['산책', '자연'],
      location: const GeoPoint(37.5472, 127.0574),
    ),
    Place(
      id: 'p6',
      name: '한강 노을 포인트',
      address: '서울 성동구 뚝섬로 273',
      areaLabel: '서울 성동구 뚝섬',
      categoryKey: 'tour',
      categoryLabel: '전망',
      imageUrl: _img('hangang'),
      rating: 4.8,
      keywords: const ['노을', '사진 명소'],
      location: const GeoPoint(37.5398, 127.0621),
    ),
    Place(
      id: 'p7',
      name: '청춘해변',
      address: '강원 강릉시 주문진읍 해안로 1',
      areaLabel: '강릉시 주문진읍',
      categoryKey: 'tour',
      categoryLabel: '해변',
      imageUrl: _img('beach'),
      rating: 4.7,
      keywords: const ['바다', '힐링'],
      location: const GeoPoint(37.8925, 128.8326),
    ),
    Place(
      id: 'p8',
      name: '산아래 커피',
      address: '경기 가평군 상면 수목원로 12',
      areaLabel: '경기 가평군 상면',
      categoryKey: 'cafe',
      categoryLabel: '카페',
      imageUrl: _img('mountaincoffee'),
      rating: 4.5,
      keywords: const ['자연', '뷰 맛집'],
      location: const GeoPoint(37.7542, 127.3531),
    ),
    Place(
      id: 'p9',
      name: '성수 아트 갤러리',
      address: '서울 성동구 아차산로 17',
      areaLabel: '서울 성동구 성수동',
      categoryKey: 'culture',
      categoryLabel: '전시',
      imageUrl: _img('gallery'),
      rating: 4.3,
      keywords: const ['전시', '실내'],
      location: const GeoPoint(37.5425, 127.0548),
    ),
    Place(
      id: 'p10',
      name: '스테이 성수',
      address: '서울 성동구 성수일로 8',
      areaLabel: '서울 성동구 성수동',
      categoryKey: 'stay',
      categoryLabel: '숙소',
      imageUrl: _img('stay'),
      rating: 4.6,
      keywords: const ['숙소', '감성'],
      location: const GeoPoint(37.5451, 127.0532),
    ),
  ];

  static Place place(String id) => places.firstWhere((p) => p.id == id);

  static final savedPlaceIds = <String>{'p1', 'p2', 'p3', 'p4', 'p5', 'p8', 'p9', 'p10'};

  static final collections = <PlaceCollection>[
    PlaceCollection(
      id: 'c1',
      name: '성수동 데이트',
      placeCount: 0,
      updatedAt: DateTime.now(),
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
    PlaceCollection(
      id: 'c2',
      name: '부산 바다 여행',
      placeCount: 0,
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    PlaceCollection(
      id: 'c3',
      name: '조용한 카페',
      placeCount: 0,
      updatedAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];

  static final collectionMembers = <String, List<String>>{
    'c1': ['p1', 'p2', 'p3', 'p4'],
    'c2': ['p8', 'p1'],
    'c3': ['p1', 'p2', 'p8'],
  };

  static final moods = const [
    MoodOption(key: 'emotional', label: '감성'),
    MoodOption(key: 'food', label: '맛집'),
    MoodOption(key: 'walk', label: '산책'),
    MoodOption(key: 'healing', label: '힐링'),
    MoodOption(key: 'photo', label: '사진 명소'),
  ];

  static final preferenceGroups = const [
    PreferenceGroup(key: 'type', label: '장소 유형', items: [
      PreferenceItem(key: 'cafe', label: '카페'),
      PreferenceItem(key: 'restaurant', label: '맛집'),
      PreferenceItem(key: 'culture', label: '전시·문화'),
      PreferenceItem(key: 'nature', label: '자연·산책'),
      PreferenceItem(key: 'shopping', label: '쇼핑'),
      PreferenceItem(key: 'stay', label: '숙소'),
    ]),
    PreferenceGroup(key: 'mood', label: '분위기', items: [
      PreferenceItem(key: 'emotional', label: '감성'),
      PreferenceItem(key: 'quiet', label: '조용한'),
      PreferenceItem(key: 'lively', label: '활기찬'),
      PreferenceItem(key: 'photo', label: '사진 명소'),
      PreferenceItem(key: 'healing', label: '힐링'),
      PreferenceItem(key: 'date', label: '데이트'),
    ]),
    PreferenceGroup(key: 'food', label: '음식', items: [
      PreferenceItem(key: 'korean', label: '한식'),
      PreferenceItem(key: 'japanese', label: '일식'),
      PreferenceItem(key: 'western', label: '양식'),
      PreferenceItem(key: 'dessert', label: '디저트'),
      PreferenceItem(key: 'bar', label: '술집'),
      PreferenceItem(key: 'vegan', label: '비건'),
    ]),
  ];

  static final selectedPreferenceKeys = <String>{
    'cafe', 'restaurant', 'nature', 'emotional', 'photo', 'healing', 'dessert',
  };

  /// AI 추천 후보 (Mock 서버의 추천 풀)
  static const aiCandidates = <(String placeId, String reason)>[
    ('p5', '산책 취향 보완'),
    ('p6', '남는 50분 활용'),
    ('p9', '요즘 인기 전시'),
    ('p10', '동선 끝 휴식'),
  ];

  static final suggestedCourses = [
    SuggestedCourse(id: 's1', title: '서울 감성 카페 투어', placeCount: 8, durationLabel: '반나절', imageUrl: _img('suggest1')),
    SuggestedCourse(id: 's2', title: '부산 바다 힐링 코스', placeCount: 6, durationLabel: '하루', imageUrl: _img('suggest2')),
  ];

  static List<CourseStop> stopsFor(List<(String, PlaceSource, String?)> spec, {TimeOfDay start = const TimeOfDay(hour: 11, minute: 0)}) {
    final out = <CourseStop>[];
    var minutes = start.hour * 60 + start.minute;
    const legs = [
      RouteLeg(mode: TransportMode.walk, minutes: 8),
      RouteLeg(mode: TransportMode.walk, minutes: 12),
      RouteLeg(mode: TransportMode.bus, minutes: 15),
      RouteLeg(mode: TransportMode.walk, minutes: 10),
    ];
    for (var i = 0; i < spec.length; i++) {
      final (id, source, reason) = spec[i];
      out.add(CourseStop(
        place: place(id),
        source: source,
        aiReason: reason,
        arrivalTime: TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60),
        nextLeg: i == spec.length - 1 ? null : legs[i % legs.length],
      ));
      minutes += 70;
    }
    return out;
  }
}

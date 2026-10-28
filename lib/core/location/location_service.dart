import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/geo_point.dart';

enum LocationStatus {
  granted,
  denied,

  /// 다시 묻지 않음 — 앱 설정에서 직접 허용해야 한다.
  deniedForever,

  /// 기기 위치 서비스(GPS)가 꺼져 있다.
  serviceOff,

  /// 플러그인 없음(테스트)·시간 초과 등으로 위치를 얻지 못했다.
  unavailable,
}

class LocationResult {
  const LocationResult(this.status, [this.point]);
  final LocationStatus status;
  final GeoPoint? point;
}

/// 기기 현재 위치. 지도 SDK 기본 추적기는 정확한 위치(FINE)만 확인해서 '대략적 위치'를 허용하면
/// 위치가 뜨지 않으므로, 권한·위치는 여기서 직접 받는다 (FINE/COARSE 모두 허용).
abstract interface class LocationService {
  /// [request]가 true면 권한이 없을 때 요청한다.
  Future<LocationResult> current({bool request = true});

  /// 영구 거부면 앱 설정, 위치 서비스 꺼짐이면 위치 설정을 연다.
  Future<void> openSettings(LocationStatus status);
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationResult> current({bool request = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return const LocationResult(LocationStatus.serviceOff);
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && request) permission = await Geolocator.requestPermission();
      switch (permission) {
        case LocationPermission.denied:
          return const LocationResult(LocationStatus.denied);
        case LocationPermission.deniedForever:
          return const LocationResult(LocationStatus.deniedForever);
        case LocationPermission.whileInUse || LocationPermission.always || LocationPermission.unableToDetermine:
          break;
      }
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)),
        );
      } on TimeoutException {
        // 실내·에뮬레이터 등 fix가 늦으면 마지막 위치라도 쓴다.
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) return const LocationResult(LocationStatus.unavailable);
      return LocationResult(LocationStatus.granted, GeoPoint(position.latitude, position.longitude));
    } catch (_) {
      return const LocationResult(LocationStatus.unavailable);
    }
  }

  @override
  Future<void> openSettings(LocationStatus status) async {
    try {
      if (status == LocationStatus.serviceOff) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    } catch (_) {}
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => GeolocatorLocationService());

/// 마지막으로 얻은 내 위치. null이면 아직 묻지 않았다.
/// 지도마다 다시 묻지 않도록 앱 수명 동안 유지한다.
final myLocationProvider = NotifierProvider<MyLocationNotifier, LocationResult?>(MyLocationNotifier.new);

class MyLocationNotifier extends Notifier<LocationResult?> {
  @override
  LocationResult? build() => null;

  Future<LocationResult> locate({bool request = true}) async {
    final result = await ref.read(locationServiceProvider).current(request: request);
    // 일시적으로 못 얻었으면(시간 초과 등) 직전 위치를 유지한다. 권한이 없어지면 지운다.
    final keepPrevious = result.status == LocationStatus.unavailable && state?.point != null;
    if (!keepPrevious) state = result;
    return result;
  }
}

import '../../place/domain/place.dart';
import 'home_models.dart';

abstract interface class HomeRepository {
  Future<HomeStats> fetchStats();

  /// "지금 뜨는 장소" (서버 트렌딩)
  Future<List<Place>> fetchTrendingPlaces();
}

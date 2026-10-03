import 'place.dart';

abstract interface class PlaceRepository {
  Future<PlaceDetail> fetchPlace(String placeId);
}

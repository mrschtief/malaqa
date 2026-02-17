import '../entities/location_point.dart';

abstract class LocationProvider {
  Future<LocationPoint?> getCurrentLocation();
}

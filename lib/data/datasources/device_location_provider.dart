import 'package:geolocator/geolocator.dart';

import '../../domain/entities/location_point.dart';
import '../../domain/interfaces/location_provider.dart';

class DeviceLocationProvider implements LocationProvider {
  @override
  Future<LocationPoint?> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final current = await Geolocator.getCurrentPosition();
    return LocationPoint(
      latitude: current.latitude,
      longitude: current.longitude,
    );
  }
}

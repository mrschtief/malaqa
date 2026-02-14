class LocationPoint {
  const LocationPoint({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  String toCanonicalString() {
    return '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
  }
}

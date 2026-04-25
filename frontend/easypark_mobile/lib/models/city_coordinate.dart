class CityCoordinate {
  final String city;
  final double latitude;
  final double longitude;

  CityCoordinate({
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  factory CityCoordinate.fromJson(Map<String, dynamic> json) {
    return CityCoordinate(
      city: (json['city'] as String?) ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}


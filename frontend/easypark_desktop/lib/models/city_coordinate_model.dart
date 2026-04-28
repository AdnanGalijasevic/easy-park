import 'package:json_annotation/json_annotation.dart';

part 'city_coordinate_model.g.dart';

@JsonSerializable()
class CityCoordinate {
  final String city;
  final double latitude;
  final double longitude;

  CityCoordinate({
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  factory CityCoordinate.fromJson(Map<String, dynamic> json) =>
      _$CityCoordinateFromJson(json);

  Map<String, dynamic> toJson() => _$CityCoordinateToJson(this);
}

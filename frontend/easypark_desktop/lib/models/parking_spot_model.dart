import 'package:json_annotation/json_annotation.dart';

part 'parking_spot_model.g.dart';

@JsonSerializable()
class ParkingSpot {
  final int id;
  final int parkingLocationId;
  final String parkingLocationName;
  final String spotNumber;
  final String spotType;
  final bool isActive;
  @JsonKey(defaultValue: false)
  final bool isOccupied;
  final DateTime createdAt;
  final DateTime? nextReservationStart;
  final DateTime? nextReservationEnd;

  ParkingSpot({
    required this.id,
    required this.parkingLocationId,
    required this.parkingLocationName,
    required this.spotNumber,
    required this.spotType,
    required this.isActive,
    required this.isOccupied,
    required this.createdAt,
    this.nextReservationStart,
    this.nextReservationEnd,
  });

  factory ParkingSpot.fromJson(Map<String, dynamic> json) =>
      _$ParkingSpotFromJson(json);

  Map<String, dynamic> toJson() => _$ParkingSpotToJson(this);
}

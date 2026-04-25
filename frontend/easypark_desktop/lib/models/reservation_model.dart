import 'package:json_annotation/json_annotation.dart';

part 'reservation_model.g.dart';

@JsonSerializable()
class Reservation {
  final int id;
  final int parkingSpotId;
  final int userId;
  final String? spotNumber;
  final String? spotType;
  final int? parkingLocationId;
  final String? parkingLocationName;
  final double totalPrice;
  final String status;
  final DateTime startTime;
  final DateTime endTime;

  Reservation({
    required this.id,
    required this.parkingSpotId,
    required this.userId,
    this.spotNumber,
    this.spotType,
    this.parkingLocationId,
    this.parkingLocationName,
    required this.totalPrice,
    required this.status,
    required this.startTime,
    required this.endTime,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) =>
      _$ReservationFromJson(json);

  Map<String, dynamic> toJson() => _$ReservationToJson(this);
}

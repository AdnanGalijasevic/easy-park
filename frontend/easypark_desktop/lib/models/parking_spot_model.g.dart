// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parking_spot_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ParkingSpot _$ParkingSpotFromJson(Map<String, dynamic> json) => ParkingSpot(
  id: (json['id'] as num).toInt(),
  parkingLocationId: (json['parkingLocationId'] as num).toInt(),
  parkingLocationName: json['parkingLocationName'] as String,
  spotNumber: json['spotNumber'] as String,
  spotType: json['spotType'] as String,
  isActive: json['isActive'] as bool,
  isOccupied: json['isOccupied'] as bool? ?? false,
  createdAt: DateTime.parse(json['createdAt'] as String),
  nextReservationStart: json['nextReservationStart'] == null
      ? null
      : DateTime.parse(json['nextReservationStart'] as String),
  nextReservationEnd: json['nextReservationEnd'] == null
      ? null
      : DateTime.parse(json['nextReservationEnd'] as String),
);

Map<String, dynamic> _$ParkingSpotToJson(ParkingSpot instance) =>
    <String, dynamic>{
      'id': instance.id,
      'parkingLocationId': instance.parkingLocationId,
      'parkingLocationName': instance.parkingLocationName,
      'spotNumber': instance.spotNumber,
      'spotType': instance.spotType,
      'isActive': instance.isActive,
      'isOccupied': instance.isOccupied,
      'createdAt': instance.createdAt.toIso8601String(),
      'nextReservationStart': instance.nextReservationStart?.toIso8601String(),
      'nextReservationEnd': instance.nextReservationEnd?.toIso8601String(),
    };

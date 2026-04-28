// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Reservation _$ReservationFromJson(Map<String, dynamic> json) => Reservation(
  id: (json['id'] as num).toInt(),
  parkingSpotId: (json['parkingSpotId'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  spotNumber: json['spotNumber'] as String?,
  spotType: json['spotType'] as String?,
  parkingLocationId: (json['parkingLocationId'] as num?)?.toInt(),
  parkingLocationName: json['parkingLocationName'] as String?,
  totalPrice: (json['totalPrice'] as num).toDouble(),
  status: json['status'] as String,
  startTime: DateTime.parse(json['startTime'] as String),
  endTime: DateTime.parse(json['endTime'] as String),
);

Map<String, dynamic> _$ReservationToJson(Reservation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'parkingSpotId': instance.parkingSpotId,
      'userId': instance.userId,
      'spotNumber': instance.spotNumber,
      'spotType': instance.spotType,
      'parkingLocationId': instance.parkingLocationId,
      'parkingLocationName': instance.parkingLocationName,
      'totalPrice': instance.totalPrice,
      'status': instance.status,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime.toIso8601String(),
    };

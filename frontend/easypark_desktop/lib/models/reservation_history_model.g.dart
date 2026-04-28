// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservation_history_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReservationHistory _$ReservationHistoryFromJson(Map<String, dynamic> json) =>
    ReservationHistory(
      id: (json['id'] as num).toInt(),
      reservationId: (json['reservationId'] as num).toInt(),
      userId: (json['userId'] as num?)?.toInt(),
      userFullName: json['userFullName'] as String?,
      oldStatus: json['oldStatus'] as String?,
      newStatus: json['newStatus'] as String?,
      changeReason: json['changeReason'] as String?,
      changedAt: DateTime.parse(json['changedAt'] as String),
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$ReservationHistoryToJson(ReservationHistory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'reservationId': instance.reservationId,
      'userId': instance.userId,
      'userFullName': instance.userFullName,
      'oldStatus': instance.oldStatus,
      'newStatus': instance.newStatus,
      'changeReason': instance.changeReason,
      'changedAt': instance.changedAt.toIso8601String(),
      'notes': instance.notes,
    };

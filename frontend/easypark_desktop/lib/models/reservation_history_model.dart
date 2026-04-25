import 'package:json_annotation/json_annotation.dart';

part 'reservation_history_model.g.dart';

@JsonSerializable()
class ReservationHistory {
  final int id;
  final int reservationId;
  final int? userId;
  final String? userFullName;
  final String? oldStatus;
  final String? newStatus;
  final String? changeReason;
  final DateTime changedAt;
  final String? notes;

  ReservationHistory({
    required this.id,
    required this.reservationId,
    this.userId,
    this.userFullName,
    this.oldStatus,
    this.newStatus,
    this.changeReason,
    required this.changedAt,
    this.notes,
  });

  factory ReservationHistory.fromJson(Map<String, dynamic> json) => _$ReservationHistoryFromJson(json);

  Map<String, dynamic> toJson() => _$ReservationHistoryToJson(this);
}


class Reservation {
  final int id;
  final int userId;
  final String userFullName;
  final int parkingSpotId;
  final String parkingSpotNumber;
  final String parkingLocationName;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime? actualEndTime;
  final String status;
  final double totalPrice;
  final String? qrCode;
  final bool cancellationAllowed;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Reservation({
    required this.id,
    required this.userId,
    required this.userFullName,
    required this.parkingSpotId,
    required this.parkingSpotNumber,
    required this.parkingLocationName,
    required this.startTime,
    required this.endTime,
    this.actualEndTime,
    required this.status,
    required this.totalPrice,
    this.qrCode,
    required this.cancellationAllowed,
    this.cancellationReason,
    required this.createdAt,
    this.updatedAt,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      userFullName: json['userFullName'] as String? ?? '',
      parkingSpotId: (json['parkingSpotId'] as num).toInt(),
      parkingSpotNumber: json['parkingSpotNumber'] as String? ?? '',
      parkingLocationName: json['parkingLocationName'] as String? ?? '',
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      actualEndTime: json['actualEndTime'] != null
          ? DateTime.parse(json['actualEndTime'] as String)
          : null,
      status: json['status'] as String? ?? 'Unknown',
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      qrCode: json['qrCode'] as String?,
      cancellationAllowed: json['cancellationAllowed'] as bool? ?? false,
      cancellationReason: json['cancellationReason'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userFullName': userFullName,
      'parkingSpotId': parkingSpotId,
      'parkingSpotNumber': parkingSpotNumber,
      'parkingLocationName': parkingLocationName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'actualEndTime': actualEndTime?.toIso8601String(),
      'status': status,
      'totalPrice': totalPrice,
      'qrCode': qrCode,
      'cancellationAllowed': cancellationAllowed,
      'cancellationReason': cancellationReason,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  bool get isActive => status == 'Active' || status == 'Pending';
  bool get isCompleted =>
      status == 'Completed' || status == 'Cancelled' || status == 'Expired';
}

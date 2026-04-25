class ParkingSpot {
  final int id;
  final int parkingLocationId;
  final String parkingLocationName;
  final String spotNumber;
  final String spotType;
  final bool isActive;
  final bool isOccupied;

  ParkingSpot({
    required this.id,
    required this.parkingLocationId,
    required this.parkingLocationName,
    required this.spotNumber,
    required this.spotType,
    required this.isActive,
    required this.isOccupied,
  });

  factory ParkingSpot.fromJson(Map<String, dynamic> json) {
    return ParkingSpot(
      id: json['id'] as int,
      parkingLocationId: json['parkingLocationId'] as int,
      parkingLocationName: json['parkingLocationName'] as String,
      spotNumber: json['spotNumber'] as String,
      spotType: json['spotType'] as String,
      isActive: json['isActive'] as bool,
      isOccupied: json['isOccupied'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parkingLocationId': parkingLocationId,
      'parkingLocationName': parkingLocationName,
      'spotNumber': spotNumber,
      'spotType': spotType,
      'isActive': isActive,
      'isOccupied': isOccupied,
    };
  }
}

class ParkingLocationNameModel {
  final int id;
  final String name;

  const ParkingLocationNameModel({required this.id, required this.name});

  factory ParkingLocationNameModel.fromJson(Map<String, dynamic> json) {
    return ParkingLocationNameModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
    );
  }
}

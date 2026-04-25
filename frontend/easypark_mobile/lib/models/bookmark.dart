class Bookmark {
  final int id;
  final int userId;
  final String userFullName;
  final int parkingLocationId;
  final String parkingLocationName;
  final DateTime createdAt;

  Bookmark({
    required this.id,
    required this.userId,
    required this.userFullName,
    required this.parkingLocationId,
    required this.parkingLocationName,
    required this.createdAt,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      userFullName: json['userFullName'] as String? ?? '',
      parkingLocationId: (json['parkingLocationId'] as num).toInt(),
      parkingLocationName: json['parkingLocationName'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userFullName': userFullName,
      'parkingLocationId': parkingLocationId,
      'parkingLocationName': parkingLocationName,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

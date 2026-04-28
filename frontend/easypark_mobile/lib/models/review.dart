class Review {
  final int id;
  final int userId;
  final String userFullName;
  final int parkingLocationId;
  final String parkingLocationName;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Review({
    required this.id,
    required this.userId,
    required this.userFullName,
    required this.parkingLocationId,
    required this.parkingLocationName,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  static DateTime _parseLocal(String s) {
    final hasTimezone =
        s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s);
    final normalized = hasTimezone ? s : '${s}Z';
    return DateTime.parse(normalized).toLocal();
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      userFullName: json['userFullName'] as String? ?? '',
      parkingLocationId: (json['parkingLocationId'] as num).toInt(),
      parkingLocationName: json['parkingLocationName'] as String? ?? '',
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: json['createdAt'] != null
          ? _parseLocal(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? _parseLocal(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userFullName': userFullName,
    'parkingLocationId': parkingLocationId,
    'parkingLocationName': parkingLocationName,
    'rating': rating,
    'comment': comment,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
}

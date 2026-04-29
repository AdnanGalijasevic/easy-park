import 'package:easypark_mobile/models/parking_spot.dart';

class ParkingLocation {
  final int id;
  final String name;
  final String address;
  final int cityId;
  final String city;
  final double latitude;
  final double longitude;
  final String? description;
  final int totalSpots;
  final double priceRegular;
  final double priceDisabled;
  final double priceElectric;
  final double priceCovered;
  final String? photo;
  final double averageRating;
  final int totalReviews;
  final bool hasDisabledSpots;
  final bool hasElectricCharging;
  final bool hasCoveredSpots;
  final bool is24Hours;
  final String? operatingHours;
  final List<ParkingSpot>? parkingSpots;
  final double? cbfScore;
  final String? cbfExplanation;

  final bool hasVideoSurveillance;
  final bool hasNightSurveillance;
  final bool hasRamp;
  final bool hasOnlinePayment;
  final bool hasSecurityGuard;
  final bool hasWifi;
  final bool hasRestroom;
  final bool hasAttendant;
  final String? parkingType;
  final double? maxVehicleHeight;

  ParkingLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.cityId,
    required this.city,
    required this.latitude,
    required this.longitude,
    this.description,
    required this.totalSpots,
    required this.priceRegular,
    this.priceDisabled = 0.0,
    this.priceElectric = 0.0,
    this.priceCovered = 0.0,
    this.photo,
    required this.averageRating,
    required this.totalReviews,
    required this.hasDisabledSpots,
    required this.hasElectricCharging,
    required this.hasCoveredSpots,
    this.is24Hours = true,
    this.operatingHours,
    this.parkingSpots,
    this.cbfScore,
    this.cbfExplanation,
    this.hasVideoSurveillance = false,
    this.hasNightSurveillance = false,
    this.hasRamp = false,
    this.hasOnlinePayment = false,
    this.hasSecurityGuard = false,
    this.hasWifi = false,
    this.hasRestroom = false,
    this.hasAttendant = false,
    this.parkingType,
    this.maxVehicleHeight,
  });

  factory ParkingLocation.fromJson(Map<String, dynamic> json) {
    return ParkingLocation(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      cityId: json['cityId'] as int? ?? 0,
      city: (json['cityName'] as String?) ?? (json['city'] as String? ?? ''),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      description: json['description'] as String?,
      totalSpots: json['totalSpots'] as int,
      priceRegular:
          (json['priceRegular'] as num?)?.toDouble() ??
          (json['pricePerHour'] as num?)?.toDouble() ??
          0.0,
      priceDisabled: (json['priceDisabled'] as num?)?.toDouble() ?? 0.0,
      priceElectric: (json['priceElectric'] as num?)?.toDouble() ?? 0.0,
      priceCovered: (json['priceCovered'] as num?)?.toDouble() ?? 0.0,
      photo: json['photo'] as String?,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: json['totalReviews'] as int? ?? 0,
      hasDisabledSpots: json['hasDisabledSpots'] as bool? ?? false,
      hasElectricCharging: json['hasElectricCharging'] as bool? ?? false,
      hasCoveredSpots: json['hasCoveredSpots'] as bool? ?? false,
      is24Hours: json['is24Hours'] as bool? ?? true,
      operatingHours: json['operatingHours'] as String?,
      parkingSpots: _parseSpots(json),
      cbfScore: (json['cbfScore'] as num?)?.toDouble(),
      cbfExplanation: json['cbfExplanation'] as String?,
      hasVideoSurveillance: json['hasVideoSurveillance'] as bool? ?? false,
      hasNightSurveillance: json['hasNightSurveillance'] as bool? ?? false,
      hasRamp: json['hasRamp'] as bool? ?? false,
      hasOnlinePayment: json['hasOnlinePayment'] as bool? ?? false,
      hasSecurityGuard: json['hasSecurityGuard'] as bool? ?? false,
      hasWifi: json['hasWifi'] as bool? ?? false,
      hasRestroom: json['hasRestroom'] as bool? ?? false,
      hasAttendant: json['hasAttendant'] as bool? ?? false,
      parkingType: json['parkingType'] as String?,
      maxVehicleHeight: (json['maxVehicleHeight'] as num?)?.toDouble(),
    );
  }

  static List<ParkingSpot>? _parseSpots(Map<String, dynamic> json) {
    try {
      final spots = json['parkingSpots'] as List<dynamic>?;
      if (spots == null) return null;
      return spots
          .map((e) => ParkingSpot.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'totalSpots': totalSpots,
      'priceRegular': priceRegular,
      'priceDisabled': priceDisabled,
      'priceElectric': priceElectric,
      'priceCovered': priceCovered,
      'photo': photo,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'hasDisabledSpots': hasDisabledSpots,
      'hasElectricCharging': hasElectricCharging,
      'hasCoveredSpots': hasCoveredSpots,
      'is24Hours': is24Hours,
      'operatingHours': operatingHours,
      'parkingSpots': parkingSpots?.map((e) => e.toJson()).toList(),
      'cbfScore': cbfScore,
      'cbfExplanation': cbfExplanation,
      'hasVideoSurveillance': hasVideoSurveillance,
      'hasNightSurveillance': hasNightSurveillance,
      'hasRamp': hasRamp,
      'hasOnlinePayment': hasOnlinePayment,
      'hasSecurityGuard': hasSecurityGuard,
      'hasWifi': hasWifi,
      'hasRestroom': hasRestroom,
      'hasAttendant': hasAttendant,
      'parkingType': parkingType,
      'maxVehicleHeight': maxVehicleHeight,
    };
  }
}

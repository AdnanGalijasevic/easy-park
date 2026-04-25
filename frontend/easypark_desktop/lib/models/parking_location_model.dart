import 'package:json_annotation/json_annotation.dart';
import 'package:easypark_desktop/models/parking_spot_model.dart';

part 'parking_location_model.g.dart';

@JsonSerializable()
class ParkingLocation {
  final int id;
  final String name;
  final String address;
  final int cityId;
  @JsonKey(name: 'cityName')
  final String city;
  final String? postalCode;
  final double latitude;
  final double longitude;
  final String? description;
  final int totalSpots;
  final double pricePerHour;
  final double? pricePerDay;
  final double priceRegular;
  final double priceDisabled;
  final double priceElectric;
  final double priceCovered;
  final String? photo; // Base64 encoded string
  final String createdByName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  final bool hasVideoSurveillance;
  final bool hasNightSurveillance;
  final bool hasDisabledSpots;
  final bool hasRamp;
  final bool is24Hours;
  final bool hasOnlinePayment;
  final bool hasElectricCharging;
  final bool hasCoveredSpots;
  final bool hasSecurityGuard;
  final double? maxVehicleHeight;
  final double averageRating;
  final int totalReviews;
  final double? distanceFromCenter;
  final String? parkingType;
  final String? operatingHours;
  final double? safetyRating;
  final double? cleanlinessRating;
  final double? accessibilityRating;
  final double? popularityScore;
  final DateTime? lastMaintenanceDate;
  final bool hasWifi;
  final bool hasRestroom;
  final bool hasAttendant;
  final String? paymentOptions;
  final List<ParkingSpot>? parkingSpots;

  ParkingLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.cityId,
    required this.city,
    this.postalCode,
    required this.latitude,
    required this.longitude,
    this.description,
    required this.totalSpots,
    required this.pricePerHour,
    this.pricePerDay,
    this.priceRegular = 0,
    this.priceDisabled = 0,
    this.priceElectric = 0,
    this.priceCovered = 0,
    this.photo,
    required this.createdByName,
    required this.createdAt,
    this.updatedAt,
    required this.isActive,
    required this.hasVideoSurveillance,
    required this.hasNightSurveillance,
    required this.hasDisabledSpots,
    required this.hasRamp,
    required this.is24Hours,
    required this.hasOnlinePayment,
    required this.hasElectricCharging,
    required this.hasCoveredSpots,
    required this.hasSecurityGuard,
    this.maxVehicleHeight,
    required this.averageRating,
    required this.totalReviews,
    this.distanceFromCenter,
    this.parkingType,
    this.operatingHours,
    this.safetyRating,
    this.cleanlinessRating,
    this.accessibilityRating,
    this.popularityScore,
    this.lastMaintenanceDate,
    required this.hasWifi,
    required this.hasRestroom,
    required this.hasAttendant,
    this.paymentOptions,
    this.parkingSpots,
  });

  factory ParkingLocation.fromJson(Map<String, dynamic> json) =>
      _$ParkingLocationFromJson(json);

  Map<String, dynamic> toJson() => _$ParkingLocationToJson(this);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'city_coordinate_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CityCoordinate _$CityCoordinateFromJson(Map<String, dynamic> json) =>
    CityCoordinate(
      city: json['city'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );

Map<String, dynamic> _$CityCoordinateToJson(CityCoordinate instance) =>
    <String, dynamic>{
      'city': instance.city,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };

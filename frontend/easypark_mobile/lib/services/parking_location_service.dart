import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:easypark_mobile/models/city_coordinate.dart';
import 'package:easypark_mobile/models/parking_location.dart';
import 'package:easypark_mobile/services/base_service.dart';
import 'package:easypark_mobile/utils/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:easypark_mobile/services/auth_service.dart';
import 'package:easypark_mobile/utils/client_type.dart';

class ParkingLocationService extends BaseService<ParkingLocation> {
  ParkingLocationService() : super("ParkingLocation");
  final _storage = const FlutterSecureStorage();

  @override
  Future<ParkingLocation> fromJson(Map<String, dynamic> json) async {
    return ParkingLocation.fromJson(json);
  }

  Future<List<ParkingLocation>> getRecommendations(int? cityId) async {
    String? accessToken = await _storage.read(key: 'accessToken');
    accessToken ??= AuthService.currentAccessToken;
    final clientType = resolveClientType();

    if (accessToken == null) {
      return []; // Return empty if not authenticated
    }

    var url = '${AppConstants.baseUrl}/ParkingLocation/recommendations';
    if (cityId != null) {
      url += '?cityId=$cityId';
    }
    
    final uri = Uri.parse(url);
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      'X-Client-Type': clientType,
    };

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body) as List<dynamic>;
      return data.map((json) => ParkingLocation.fromJson(json)).toList();
    } else {
      return []; // Return empty list on error
    }
  }

  Future<List<CityCoordinate>> getCityCoordinates() async {
    final uri = Uri.parse('${AppConstants.baseUrl}/ParkingLocation/cities');
    final headers = await getHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => CityCoordinate.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception('Failed to load city coordinates: ${response.statusCode}');
  }
}

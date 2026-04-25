import 'dart:convert';
import 'package:easypark_desktop/models/parking_location_model.dart';
import 'package:easypark_desktop/models/parking_location_name_model.dart';
import 'package:easypark_desktop/services/base_service.dart';
import 'package:http/http.dart' as http;

class ParkingLocationService extends BaseService<ParkingLocation> {
  ParkingLocationService() : super('ParkingLocation');

  @override
  ParkingLocation fromJson(Map<String, dynamic> data) => ParkingLocation.fromJson(data);

  Future<List<ParkingLocationNameModel>> getNames() async {
    final uri = Uri.parse('${BaseService.baseUrl}ParkingLocation/names');
    final response = await http.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load parking location names');
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => ParkingLocationNameModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

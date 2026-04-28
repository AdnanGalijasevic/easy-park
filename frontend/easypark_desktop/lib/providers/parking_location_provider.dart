import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:easypark_desktop/models/city_coordinate_model.dart';
import 'package:easypark_desktop/models/parking_location_model.dart';
import 'package:easypark_desktop/models/parking_location_name_model.dart';
import 'package:easypark_desktop/providers/base_provider.dart';
import 'package:easypark_desktop/services/parking_location_service.dart';

class ParkingLocationProvider extends BaseProvider<ParkingLocation> {
  final ParkingLocationService _service = ParkingLocationService();

  ParkingLocationProvider() : super('ParkingLocation');

  @override
  ParkingLocation fromJson(data) {
    return ParkingLocation.fromJson(data);
  }

  Future<List<CityCoordinate>> getCities() async {
    var url = '${BaseProvider.baseUrl}ParkingLocation/cities';
    var uri = Uri.parse(url);
    var response = await executeWithAuthRetry(
      (refreshedHeaders) => http.get(uri, headers: refreshedHeaders),
    );

    if (isValidResponse(response)) {
      var data = jsonDecode(response.body);
      return (data as List).map((x) => CityCoordinate.fromJson(x)).toList();
    } else {
      throw Exception('Failed to load cities');
    }
  }

  Future<List<ParkingLocationNameModel>> getNames() => _service.getNames();
}

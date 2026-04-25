import 'package:easypark_desktop/models/parking_location_model.dart';
import 'package:easypark_desktop/models/parking_location_name_model.dart';
import 'package:easypark_desktop/providers/base_provider.dart';
import 'package:easypark_desktop/services/parking_location_service.dart';

class ParkingLocationProvider extends BaseProvider<ParkingLocation> {
  final ParkingLocationService _service = ParkingLocationService();

  ParkingLocationProvider() : super('ParkingLocation');

  @override
  ParkingLocation fromJson(data) => ParkingLocation.fromJson(data);

  Future<List<ParkingLocationNameModel>> getNames() => _service.getNames();
}

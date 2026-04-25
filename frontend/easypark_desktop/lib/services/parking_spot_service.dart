import 'package:easypark_desktop/models/parking_spot_model.dart';
import 'package:easypark_desktop/services/base_service.dart';

class ParkingSpotService extends BaseService<ParkingSpot> {
  ParkingSpotService() : super('ParkingSpot');

  @override
  ParkingSpot fromJson(Map<String, dynamic> data) => ParkingSpot.fromJson(data);
}

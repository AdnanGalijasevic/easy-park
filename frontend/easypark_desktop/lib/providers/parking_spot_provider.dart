import 'package:easypark_desktop/models/parking_spot_model.dart';
import 'package:easypark_desktop/providers/base_provider.dart';

class ParkingSpotProvider extends BaseProvider<ParkingSpot> {
  ParkingSpotProvider() : super('ParkingSpot');

  @override
  ParkingSpot fromJson(data) {
    return ParkingSpot.fromJson(data);
  }
}

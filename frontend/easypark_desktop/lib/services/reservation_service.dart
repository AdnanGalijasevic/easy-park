import 'package:easypark_desktop/models/reservation_model.dart';
import 'package:easypark_desktop/services/base_service.dart';

class ReservationService extends BaseService<Reservation> {
  ReservationService() : super('Reservation');

  @override
  Reservation fromJson(Map<String, dynamic> data) => Reservation.fromJson(data);
}

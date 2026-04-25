import 'package:easypark_desktop/models/reservation_model.dart';
import 'package:easypark_desktop/providers/base_provider.dart';

class ReservationProvider extends BaseProvider<Reservation> {
  ReservationProvider() : super('Reservation');

  @override
  Reservation fromJson(data) {
    return Reservation.fromJson(data);
  }
}

import 'package:easypark_desktop/models/reservation_history_model.dart';
import 'package:easypark_desktop/providers/base_provider.dart';

class ReservationHistoryProvider extends BaseProvider<ReservationHistory> {
  ReservationHistoryProvider() : super('ReservationHistory');

  @override
  ReservationHistory fromJson(data) {
    return ReservationHistory.fromJson(data);
  }
}

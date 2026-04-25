import 'package:easypark_desktop/models/reservation_history_model.dart';
import 'package:easypark_desktop/services/base_service.dart';

class ReservationHistoryService extends BaseService<ReservationHistory> {
  ReservationHistoryService() : super('ReservationHistory');

  @override
  ReservationHistory fromJson(Map<String, dynamic> data) => ReservationHistory.fromJson(data);
}

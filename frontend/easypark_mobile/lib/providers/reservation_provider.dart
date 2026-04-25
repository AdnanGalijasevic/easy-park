import 'package:easypark_mobile/models/reservation.dart';
import 'package:easypark_mobile/models/spot_type_availability.dart';
import 'package:easypark_mobile/services/reservation_service.dart';
import 'package:easypark_mobile/providers/base_provider.dart';

class ReservationProvider extends BaseProvider<Reservation> {
  ReservationProvider() : super(ReservationService());

  final ReservationService _reservationService = ReservationService();
  bool _isBooking = false;
  String? _bookingError;
  List<Reservation> _myReservations = [];
  bool _isLoadingReservations = false;

  bool get isBooking => _isBooking;
  String? get bookingError => _bookingError;
  List<Reservation> get myReservations => _myReservations;
  bool get isLoadingReservations => _isLoadingReservations;

  Future<List<SpotTypeAvailability>> fetchAvailability({
    required int locationId,
    required DateTime from,
    required DateTime to,
  }) async {
    return _reservationService.fetchAvailability(
      locationId: locationId,
      from: from,
      to: to,
    );
  }

  Future<Reservation?> createReservation({
    required int parkingLocationId,
    required String spotType,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    _isBooking = true;
    _bookingError = null;
    notifyListeners();

    try {
      final reservation = await _reservationService.createReservation(
        parkingLocationId: parkingLocationId,
        spotType: spotType,
        startTime: startTime,
        endTime: endTime,
      );
      _isBooking = false;
      notifyListeners();
      return reservation;
    } catch (e) {
      _bookingError = e.toString();
      _isBooking = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> getMyReservations() async {
    _isLoadingReservations = true;
    notifyListeners();
    try {
      _myReservations = await _reservationService.getMyReservations();
    } catch (e) {
      _myReservations = [];
    } finally {
      _isLoadingReservations = false;
      notifyListeners();
    }
  }

  Future<void> cancelReservation(int id) async {
    await _reservationService.cancelReservation(id);
    await getMyReservations();
  }
}

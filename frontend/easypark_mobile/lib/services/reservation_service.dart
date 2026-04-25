import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:easypark_mobile/models/reservation.dart';
import 'package:easypark_mobile/models/spot_type_availability.dart';
import 'package:easypark_mobile/services/base_service.dart';
import 'package:easypark_mobile/utils/constants.dart';

class ReservationService extends BaseService<Reservation> {
  ReservationService() : super("Reservation");

  @override
  Future<Reservation> fromJson(Map<String, dynamic> json) async {
    return Reservation.fromJson(json);
  }

  /// Fetches busy/free availability windows per spot type for a location + day range.
  Future<List<SpotTypeAvailability>> fetchAvailability({
    required int locationId,
    required DateTime from,
    required DateTime to,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.baseUrl}/ParkingLocation/$locationId/availability'
      '?from=${from.toUtc().toIso8601String()}'
      '&to=${to.toUtc().toIso8601String()}',
    );
    final headers = await getHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => SpotTypeAvailability.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load availability: ${response.statusCode}');
    }
  }

  /// Creates a reservation.
  /// The backend auto-assigns the first conflict-free spot of [spotType].
  Future<Reservation> createReservation({
    required int parkingLocationId,
    required String spotType,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/Reservation');
    final headers = await getHeaders();

    final body = jsonEncode({
      'parkingLocationId': parkingLocationId,
      'spotType': spotType,
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
      'cancellationAllowed': true,
    });

    final response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Reservation.fromJson(jsonDecode(response.body));
    } else {
      String msg = 'Failed to create reservation (${response.statusCode})';
      if (response.body.isNotEmpty) {
        try {
          final err = jsonDecode(response.body);
          if (err is Map<String, dynamic>) {
            if (err['errors'] != null && err['errors'] is Map) {
              final Map<dynamic, dynamic> errors =
                  err['errors'] as Map<dynamic, dynamic>;

              dynamic firstError;
              if (errors.containsKey('userError')) {
                firstError = errors['userError'];
              } else if (errors.isNotEmpty) {
                firstError = errors.values.first;
              }

              if (firstError is List && firstError.isNotEmpty) {
                msg = firstError.first.toString();
              } else if (firstError != null) {
                msg = firstError.toString();
              }
            } else if (err['userError'] != null) {
              msg = err['userError'].toString();
            } else if (err['message'] != null) {
              msg = err['message'].toString();
            }
          }
        } catch (_) {
          // Keep fallback message below.
        }

        if (msg.startsWith('Failed to create reservation')) {
          msg = '$msg: ${response.body}';
        }
      }
      throw Exception(msg);
    }
  }

  Future<List<Reservation>> getMyReservations({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;

    final queryString = params.isNotEmpty
        ? '?${Uri(queryParameters: params.map((k, v) => MapEntry(k, v.toString()))).query}'
        : '';

    final uri = Uri.parse('${AppConstants.baseUrl}/Reservation$queryString');
    final headers = await getHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<dynamic> list;
      if (data is Map && data.containsKey('resultList')) {
        list = data['resultList'] as List<dynamic>;
      } else if (data is Map && data.containsKey('result')) {
        list = data['result'] as List<dynamic>;
      } else if (data is List) {
        list = data;
      } else {
        return [];
      }
      return list
          .map((e) => Reservation.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load reservations: ${response.statusCode}');
    }
  }

  Future<void> cancelReservation(int id) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/Reservation/$id/cancel');
    final headers = await getHeaders();
    final response = await http.put(uri, headers: headers);

    if (response.statusCode != 200 && response.statusCode != 204) {
      final err = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final msg =
          err['userError'] ?? err['message'] ?? 'Failed to cancel reservation';
      throw Exception(msg);
    }
  }
}

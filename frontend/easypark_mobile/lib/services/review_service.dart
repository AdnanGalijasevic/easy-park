import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:easypark_mobile/models/review.dart';
import 'package:easypark_mobile/services/base_service.dart';
import 'package:easypark_mobile/utils/constants.dart';

class ReviewService extends BaseService<Review> {
  ReviewService() : super("Review");

  @override
  Future<Review> fromJson(Map<String, dynamic> json) async {
    return Review.fromJson(json);
  }

  Future<List<Review>> getForLocation(int parkingLocationId) async {
    final uri = Uri.parse(
      '${AppConstants.baseUrl}/Review?parkingLocationId=$parkingLocationId',
    );
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
          .map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load reviews: ${response.statusCode}');
    }
  }

  Future<Review> submitReview({
    required int parkingLocationId,
    required int rating,
    String? comment,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/Review');
    final headers = await getHeaders();
    final body = jsonEncode({
      'parkingLocationId': parkingLocationId,
      'rating': rating,
      'comment': comment,
    });

    final response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Review.fromJson(jsonDecode(response.body));
    } else {
      final err = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};
      final msg =
          err['userError'] ?? err['message'] ?? 'Failed to submit review';
      throw Exception(msg);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:easypark_mobile/models/review.dart';
import 'package:easypark_mobile/services/review_service.dart';

class ReviewProvider with ChangeNotifier {
  final ReviewService _service = ReviewService();

  final Map<int, List<Review>> _reviewsByLocation = {};
  final Map<int, bool> _isLoadingByLocation = {};
  bool _isSubmitting = false;

  bool get isSubmitting => _isSubmitting;

  List<Review> reviewsForLocation(int parkingLocationId) =>
      _reviewsByLocation[parkingLocationId] ?? [];

  bool isLoadingForLocation(int parkingLocationId) =>
      _isLoadingByLocation[parkingLocationId] ?? false;

  Future<void> loadReviews(int parkingLocationId) async {
    _isLoadingByLocation[parkingLocationId] = true;
    notifyListeners();
    try {
      _reviewsByLocation[parkingLocationId] = await _service.getForLocation(
        parkingLocationId,
      );
    } catch (_) {
      _reviewsByLocation[parkingLocationId] = [];
    } finally {
      _isLoadingByLocation[parkingLocationId] = false;
      notifyListeners();
    }
  }

  Future<void> submitReview({
    required int parkingLocationId,
    required int rating,
    String? comment,
  }) async {
    _isSubmitting = true;
    notifyListeners();
    try {
      final review = await _service.submitReview(
        parkingLocationId: parkingLocationId,
        rating: rating,
        comment: comment,
      );
      _reviewsByLocation[parkingLocationId] = [
        review,
        ...(_reviewsByLocation[parkingLocationId] ?? []),
      ];
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}

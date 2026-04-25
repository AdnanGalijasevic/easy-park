import 'package:easypark_desktop/models/review_model.dart';
import 'package:easypark_desktop/services/base_service.dart';

class ReviewService extends BaseService<Review> {
  ReviewService() : super('Review');

  @override
  Review fromJson(Map<String, dynamic> data) => Review.fromJson(data);
}

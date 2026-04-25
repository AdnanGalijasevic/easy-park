import 'package:easypark_desktop/models/review_model.dart';
import 'package:easypark_desktop/providers/base_provider.dart';

class ReviewProvider extends BaseProvider<Review> {
  ReviewProvider() : super('Review');

  @override
  Review fromJson(data) {
    return Review.fromJson(data);
  }
}

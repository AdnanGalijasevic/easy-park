import 'package:flutter/material.dart';
import 'package:easypark_desktop/models/parking_location_name_model.dart';
import 'package:easypark_desktop/models/review_model.dart';
import 'package:easypark_desktop/providers/parking_location_provider.dart';
import 'package:easypark_desktop/providers/review_provider.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';
import 'package:easypark_desktop/utils/error_message.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final ReviewProvider _reviewProvider = ReviewProvider();
  final ParkingLocationProvider _parkingLocationProvider =
      ParkingLocationProvider();
  List<Review> _reviews = [];
  List<ParkingLocationNameModel> _parkingLocations = [];
  bool _isLoading = true;
  int? _ratingFilter;
  int? _parkingLocationFilter;

  @override
  void initState() {
    super.initState();
    _loadParkingLocationNames();
    _loadReviews();
  }

  Future<void> _loadParkingLocationNames() async {
    try {
      final names = await _parkingLocationProvider.getNames();
      if (!mounted) return;
      setState(() => _parkingLocations = names);
    } catch (_) {
    }
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    try {
      final filter = <String, dynamic>{};
      if (_ratingFilter != null) filter['rating'] = _ratingFilter;
      if (_parkingLocationFilter != null) {
        filter['parkingLocationId'] = _parkingLocationFilter;
      }
      final result = await _reviewProvider.get(filter: filter);
      if (mounted) {
        setState(() {
          _reviews = result.result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load reviews: ${normalizeErrorMessage(e)}'),
            backgroundColor: EasyParkColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteReview(int id) async {
    try {
      await _reviewProvider.delete(id);
      await _loadReviews();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review deleted successfully.'),
            backgroundColor: EasyParkColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete review: ${normalizeErrorMessage(e)}'),
            backgroundColor: EasyParkColors.error,
          ),
        );
      }
    }
  }

  void _confirmDelete(Review review) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Review'),
        content: Text(
          'Delete review by ${review.userFullName} for ${review.parkingLocationName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteReview(review.id);
            },
            child: const Text('Delete', style: TextStyle(color: EasyParkColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildStars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star : Icons.star_border,
          size: 16,
          color: EasyParkColors.ratingStar,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews'),
        actions: [
          Container(
            width: 220,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: EasyParkColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: _parkingLocationFilter,
                hint: const Text(
                  'All Locations',
                  style: TextStyle(color: EasyParkColors.onAccent),
                ),
                isExpanded: true,
                dropdownColor: EasyParkColors.surfaceElevated,
                iconEnabledColor: EasyParkColors.onAccent,
                style: const TextStyle(color: EasyParkColors.onAccent),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text(
                      'All Locations',
                      style: TextStyle(color: EasyParkColors.onAccent),
                    ),
                  ),
                  ..._parkingLocations.map(
                    (p) => DropdownMenuItem<int?>(
                      value: p.id,
                      child: Text(
                        p.name,
                        style: const TextStyle(color: EasyParkColors.onAccent),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() => _parkingLocationFilter = val);
                  _loadReviews();
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: EasyParkColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: _ratingFilter,
                hint: const Text(
                  'All Ratings',
                  style: TextStyle(color: EasyParkColors.onAccent),
                ),
                dropdownColor: EasyParkColors.surfaceElevated,
                iconEnabledColor: EasyParkColors.onAccent,
                style: const TextStyle(color: EasyParkColors.onAccent),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text(
                      'All Ratings',
                      style: TextStyle(color: EasyParkColors.onAccent),
                    ),
                  ),
                  ...List.generate(
                    5,
                    (i) => DropdownMenuItem<int?>(
                      value: i + 1,
                      child: Row(
                        children: [
                          Text(
                            '${i + 1} ',
                            style: const TextStyle(color: EasyParkColors.onAccent),
                          ),
                          const Icon(Icons.star, size: 14, color: EasyParkColors.ratingStar),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() => _ratingFilter = val);
                  _loadReviews();
                },
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReviews),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 64,
                    color: EasyParkColors.muted,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No reviews found',
                    style: TextStyle(color: EasyParkColors.muted, fontSize: 18),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        showCheckboxColumn: false,
                        columns: const [
                          DataColumn(label: Text('User')),
                          DataColumn(label: Text('Parking Location')),
                          DataColumn(label: Text('Rating')),
                          DataColumn(label: Text('Comment')),
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _reviews.map((review) {
                          return DataRow(
                            cells: [
                              DataCell(Text(review.userFullName)),
                              DataCell(Text(review.parkingLocationName)),
                              DataCell(_buildStars(review.rating)),
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 300,
                                  ),
                                  child: Text(
                                    review.comment ?? '—',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${review.createdAt.day}.${review.createdAt.month}.${review.createdAt.year}',
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: EasyParkColors.error,
                                  ),
                                  onPressed: () => _confirmDelete(review),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

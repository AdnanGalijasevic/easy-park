import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:easypark_mobile/models/parking_location.dart';
import 'package:easypark_mobile/models/reservation.dart';
import 'package:easypark_mobile/providers/bookmark_provider.dart';
import 'package:easypark_mobile/providers/parking_location_provider.dart';
import 'package:easypark_mobile/providers/reservation_provider.dart';
import 'package:easypark_mobile/widgets/reservation_dialog.dart';
import 'package:easypark_mobile/theme/easy_park_colors.dart';

class LocationCard extends StatelessWidget {
  final ParkingLocation location;

  /// Called on first tap — should focus/zoom the map to this location.
  final void Function(ParkingLocation location)? onFirstTap;

  /// Highlights this card when it is the top recommendation for the user.
  final bool isOptimalRecommendation;

  const LocationCard({
    super.key,
    required this.location,
    this.onFirstTap,
    this.isOptimalRecommendation = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ParkingLocationProvider>(context);
    final isSelected = provider.selectedLocation?.id == location.id;

    BorderSide borderSide;
    if (isSelected) {
      borderSide = const BorderSide(color: EasyParkColors.info, width: 2);
    } else if (isOptimalRecommendation) {
      borderSide = const BorderSide(color: EasyParkColors.highlightBorder, width: 3);
    } else {
      borderSide = BorderSide.none;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: borderSide,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (!isSelected) {
            // First tap: select the location and focus the map
            provider.selectLocation(location);
            onFirstTap?.call(location);
          } else {
            // Second tap (already selected): open reservation dialog
            _showReservationDialog(context);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      location.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Tap hint icon when selected
                  if (isSelected)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.touch_app,
                        color: EasyParkColors.info,
                        size: 18,
                      ),
                    ),
                  _buildAvailabilityBadge(),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: EasyParkColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location.address,
                      style: const TextStyle(color: EasyParkColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star, color: EasyParkColors.highlightBorder, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${location.averageRating.toStringAsFixed(1)} (${location.totalReviews})',
                    style: const TextStyle(color: EasyParkColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.attach_money,
                        color: EasyParkColors.accent,
                        size: 20,
                      ),
                      Text(
                        '${location.priceRegular} Coins/hr',
                        style: const TextStyle(
                          color: EasyParkColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Consumer<BookmarkProvider>(
                    builder: (context, bookmarkProvider, _) {
                      final isBookmarked = bookmarkProvider.isBookmarked(
                        location.id,
                      );
                      return IconButton(
                        icon: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: isBookmarked ? EasyParkColors.info : EasyParkColors.disabled,
                        ),
                        tooltip: isBookmarked
                            ? 'Remove bookmark'
                            : 'Bookmark this location',
                        onPressed: () async {
                          try {
                            await bookmarkProvider.toggleBookmark(location.id);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    ),
                                  ),
                                  backgroundColor: EasyParkColors.error,
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
              // Tap hint text when selected
              if (isSelected)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Tap again to reserve',
                    style: TextStyle(
                      fontSize: 11,
                      color: EasyParkColors.info,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityBadge() {
    final availableSpots =
        location.parkingSpots
            ?.where((spot) => spot.isActive && !spot.isOccupied)
            .length ??
        0;
    final totalSpots = location.totalSpots;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: availableSpots > 0 ? EasyParkColors.successContainer : EasyParkColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$availableSpots/$totalSpots',
        style: TextStyle(
          color: availableSpots > 0 ? EasyParkColors.successOnContainer : EasyParkColors.errorOnContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _showReservationDialog(BuildContext context) async {
    final result = await showDialog(
      context: context,
      // Use a slightly translucent barrier so the map is still visible
      // but fully blocked from interaction via barrierDismissible + GestureDetector in dialog.
      barrierColor: EasyParkColors.scrim,
      barrierDismissible: true,
      builder: (context) => ReservationDialog(location: location),
    );

    if (result != null && result is Reservation && context.mounted) {
      _showSuccessBottomSheet(context, result);
    }
  }

  void _showSuccessBottomSheet(BuildContext context, Reservation reservation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: EasyParkColors.transparent,
      builder: (ctx) => _buildSuccessBottomSheet(ctx, reservation),
    );
  }

  Widget _buildSuccessBottomSheet(
    BuildContext context,
    Reservation reservation,
  ) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: EasyParkColors.inverseSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: EasyParkColors.success, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Reservation Successful!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (reservation.qrCode != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: QrImageView(
                    data: reservation.qrCode!,
                    version: QrVersions.auto,
                    size: 150.0,
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final lat = location.latitude;
                    final lng = location.longitude;
                    final url = Uri.parse(
                      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
                    );
                    if (!await launchUrl(url)) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open map'),
                            backgroundColor: EasyParkColors.error,
                          ),
                        );
                      }
                    } else {
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: EasyParkColors.accent,
                    foregroundColor: EasyParkColors.onAccent,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    try {
                      await Provider.of<ReservationProvider>(
                        context,
                        listen: false,
                      ).cancelReservation(reservation.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reservation Cancelled'),
                            backgroundColor: EasyParkColors.muted,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: EasyParkColors.error,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.cancel, color: EasyParkColors.error),
                  label: const Text(
                    'Cancel Reservation',
                    style: TextStyle(color: EasyParkColors.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

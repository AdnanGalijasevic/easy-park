import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easypark_desktop/models/parking_spot_model.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';

class ParkingSpotListItem extends StatelessWidget {
  final ParkingSpot spot;
  final VoidCallback? onDelete;
  final Function(bool)? onToggleActive;
  final VoidCallback? onTap;

  const ParkingSpotListItem({
    super.key,
    required this.spot,
    this.onDelete,
    this.onToggleActive,
    this.onTap,
  });

  IconData _getSpotIcon(String type) {
    switch (type.toLowerCase()) {
      case 'electric':
        return Icons.ev_station;
      case 'disabled':
        return Icons.accessible;
      case 'covered':
        return Icons.roofing;
      default:
        return Icons.local_parking;
    }
  }

  String _formatSpotName(String spotNumber) {
    var parts = spotNumber.split('-');
    if (parts.length >= 3) {
      return '${parts[0]} - ${parts.last}';
    }
    return spotNumber;
  }

  @override
  Widget build(BuildContext context) {
    bool hasReservation = spot.nextReservationStart != null;
    String reservationText = '';
    if (hasReservation) {
      final DateFormat formatter = DateFormat('dd/MM/yy HH:mm');
      reservationText =
          'Next Reservation: ${formatter.format(spot.nextReservationStart!.toLocal())} - ${formatter.format(spot.nextReservationEnd!.toLocal())}';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Icon(
          _getSpotIcon(spot.spotType),
          color: spot.isActive ? EasyParkColors.info : EasyParkColors.muted,
          size: 32,
        ),
        title: Text(
          _formatSpotName(spot.spotNumber),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: EasyParkColors.textOnLightPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  spot.spotType,
                  style: const TextStyle(color: EasyParkColors.textOnLightPrimary),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: spot.isOccupied
                        ? EasyParkColors.errorContainer
                        : EasyParkColors.successContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    spot.isOccupied ? 'Occupied' : 'Free',
                    style: TextStyle(
                      color: spot.isOccupied ? EasyParkColors.error : EasyParkColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (hasReservation) ...[
              const SizedBox(height: 4),
              Text(
                reservationText,
                style: const TextStyle(
                  color: EasyParkColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onToggleActive != null)
              Tooltip(
                message: spot.isActive ? 'Deactivate' : 'Activate',
                child: Switch(
                  value: spot.isActive,
                  onChanged: onToggleActive,
                  activeThumbColor: EasyParkColors.success,
                ),
              ),
            if (onDelete != null) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: 'Delete Spot',
                child: IconButton(
                  icon: const Icon(Icons.delete, color: EasyParkColors.error),
                  onPressed: onDelete,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

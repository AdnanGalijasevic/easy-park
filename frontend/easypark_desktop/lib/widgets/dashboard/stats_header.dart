import 'package:flutter/material.dart';
import 'package:easypark_desktop/models/parking_spot_model.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';

class DashboardStatsHeader extends StatelessWidget {
  final List<ParkingSpot> spots;

  const DashboardStatsHeader({super.key, required this.spots});

  @override
  Widget build(BuildContext context) {
    final activeSpots = spots.where((s) => s.isActive).toList();
    final total = activeSpots.length;
    final occupied = activeSpots.where((s) => s.isOccupied).length;
    final free = total - occupied;

    final byType = <String, _TypeStats>{};
    for (final type in ['Regular', 'Disabled', 'Electric', 'Covered']) {
      final typeSpots = activeSpots.where((s) => s.spotType == type).toList();
      byType[type] = _TypeStats(
        total: typeSpots.length,
        occupied: typeSpots.where((s) => s.isOccupied).length,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStatCard(
              'Total Active',
              '$total',
              Icons.local_parking,
              EasyParkColors.info,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'Occupied',
              '$occupied',
              Icons.car_rental,
              EasyParkColors.error,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'Free',
              '$free',
              Icons.check_circle_outline,
              EasyParkColors.success,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildTypeCard(
              'Regular',
              byType['Regular']!,
              EasyParkColors.chartSecondary,
              Icons.local_parking,
            ),
            const SizedBox(width: 12),
            _buildTypeCard(
              'Disabled',
              byType['Disabled']!,
              EasyParkColors.info,
              Icons.accessible,
            ),
            const SizedBox(width: 12),
            _buildTypeCard(
              'Electric',
              byType['Electric']!,
              EasyParkColors.success,
              Icons.electric_car,
            ),
            const SizedBox(width: 12),
            _buildTypeCard(
              'Covered',
              byType['Covered']!,
              EasyParkColors.accent,
              Icons.roofing,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: const TextStyle(color: EasyParkColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCard(
    String type,
    _TypeStats stats,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 6),
              Text(
                '${stats.occupied}/${stats.total}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                type,
                style: const TextStyle(color: EasyParkColors.muted, fontSize: 11),
              ),
              const Text(
                'occupied',
                style: TextStyle(color: EasyParkColors.muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeStats {
  final int total;
  final int occupied;
  const _TypeStats({required this.total, required this.occupied});
}

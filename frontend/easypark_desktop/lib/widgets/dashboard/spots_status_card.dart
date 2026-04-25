import 'package:flutter/material.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';
import 'package:easypark_desktop/models/parking_spot_model.dart';
import 'package:easypark_desktop/widgets/parking_spot_list_item.dart';

class SpotsStatusCard extends StatelessWidget {
  final List<ParkingSpot> spots;
  final Future<void> Function(ParkingSpot spot) onToggleOccupied;
  final Future<void> Function(ParkingSpot spot) onToggleActive;
  final Future<void> Function(int id) onDelete;

  const SpotsStatusCard({
    super.key,
    required this.spots,
    required this.onToggleOccupied,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spots Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap a spot to toggle Occupied. Use the switch to toggle Active.',
              style: TextStyle(
                color: EasyParkColors.muted,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            spots.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No spots created for this location.'),
                    ),
                  )
                : DefaultTabController(
                    length: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: EasyParkColors.borderLight),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const TabBar(
                            labelColor: EasyParkColors.accent,
                            unselectedLabelColor: EasyParkColors.muted,
                            indicatorColor: EasyParkColors.accent,
                            tabs: [
                              Tab(text: 'All'),
                              Tab(text: 'Regular'),
                              Tab(text: 'Disabled'),
                              Tab(text: 'Electric'),
                              Tab(text: 'Covered'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 420,
                          child: TabBarView(
                            children: [
                              _buildSpotsList(context, spots),
                              _buildSpotsList(
                                context,
                                spots
                                    .where((s) => s.spotType == 'Regular')
                                    .toList(),
                              ),
                              _buildSpotsList(
                                context,
                                spots
                                    .where((s) => s.spotType == 'Disabled')
                                    .toList(),
                              ),
                              _buildSpotsList(
                                context,
                                spots
                                    .where((s) => s.spotType == 'Electric')
                                    .toList(),
                              ),
                              _buildSpotsList(
                                context,
                                spots
                                    .where((s) => s.spotType == 'Covered')
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpotsList(BuildContext context, List<ParkingSpot> filtered) {
    if (filtered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('No spots found for this category.'),
        ),
      );
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final spot = filtered[index];
        return ParkingSpotListItem(
          spot: spot,
          onTap: () => onToggleOccupied(spot),
          onToggleActive: (_) => onToggleActive(spot),
          onDelete: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Spot'),
              content: const Text('Are you sure you want to delete this spot?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onDelete(spot.id);
                  },
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: EasyParkColors.error),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

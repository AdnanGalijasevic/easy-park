import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easypark_mobile/models/reservation.dart';
import 'package:easypark_mobile/providers/reservation_provider.dart';
import 'package:easypark_mobile/theme/easy_park_colors.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await Provider.of<ReservationProvider>(
      context,
      listen: false,
    ).getMyReservations();
  }

  Future<void> _cancel(Reservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Reservation'),
        content: Text(
          'Cancel your reservation at ${reservation.parkingLocationName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: EasyParkColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await Provider.of<ReservationProvider>(
          context,
          listen: false,
        ).cancelReservation(reservation.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reservation cancelled'),
              backgroundColor: EasyParkColors.accent,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: EasyParkColors.error,
            ),
          );
        }
      }
    }
  }

  void _showQrCode(Reservation reservation) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('QR Code — ${reservation.parkingLocationName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: EasyParkColors.borderLight),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                reservation.qrCode ?? 'No QR Code',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Show this code at the parking entrance',
              style: TextStyle(color: EasyParkColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Past'),
          ],
        ),
        Expanded(
          child: Consumer<ReservationProvider>(
            builder: (context, provider, _) {
              if (provider.isLoadingReservations) {
                return const Center(child: CircularProgressIndicator());
              }

              final active = provider.myReservations
                  .where((r) => r.isActive)
                  .toList();
              final past = provider.myReservations
                  .where((r) => r.isCompleted)
                  .toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildList(
                    reservations: active,
                    emptyMessage: 'No active reservations',
                    emptyIcon: Icons.event_available,
                    onRefresh: _load,
                    isActive: true,
                  ),
                  _buildList(
                    reservations: past,
                    emptyMessage: 'No past reservations',
                    emptyIcon: Icons.history,
                    onRefresh: _load,
                    isActive: false,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildList({
    required List<Reservation> reservations,
    required String emptyMessage,
    required IconData emptyIcon,
    required Future<void> Function() onRefresh,
    required bool isActive,
  }) {
    if (reservations.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            SizedBox(
              height: 300,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(emptyIcon, size: 64, color: EasyParkColors.onBackgroundMuted),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    style: const TextStyle(color: EasyParkColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: reservations.length,
        itemBuilder: (context, index) {
          final r = reservations[index];
          return _ReservationCard(
            reservation: r,
            isActive: isActive,
            onCancel: () => _cancel(r),
            onShowQr: () => _showQrCode(r),
          );
        },
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final bool isActive;
  final VoidCallback onCancel;
  final VoidCallback onShowQr;

  const _ReservationCard({
    required this.reservation,
    required this.isActive,
    required this.onCancel,
    required this.onShowQr,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return EasyParkColors.success;
      case 'Pending':
        return EasyParkColors.info;
      case 'Completed':
        return EasyParkColors.muted;
      case 'Cancelled':
        return EasyParkColors.error;
      case 'Expired':
        return EasyParkColors.accent;
      default:
        return EasyParkColors.muted;
    }
  }

  String _formatDateTime(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(dt.day)}.${pad(dt.month)}.${dt.year} ${pad(dt.hour)}:${pad(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: EasyParkColors.info.withValues(alpha: 0.5), width: 1)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    reservation.parkingLocationName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(reservation.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    reservation.status,
                    style: TextStyle(
                      color: _statusColor(reservation.status),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Spot info
            Row(
              children: [
                const Icon(Icons.local_parking, size: 16, color: EasyParkColors.muted),
                const SizedBox(width: 4),
                Text(
                  'Spot ${reservation.parkingSpotNumber}',
                  style: const TextStyle(color: EasyParkColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Time range
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: EasyParkColors.muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${_formatDateTime(reservation.startTime)} → ${_formatDateTime(reservation.endTime)}',
                    style: const TextStyle(color: EasyParkColors.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Price row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${reservation.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: EasyParkColors.success,
                  ),
                ),
                if (isActive)
                  Row(
                    children: [
                      if (reservation.qrCode != null) ...[
                        OutlinedButton.icon(
                          onPressed: onShowQr,
                          icon: const Icon(Icons.qr_code, size: 16),
                          label: const Text('QR'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (reservation.cancellationAllowed)
                        ElevatedButton.icon(
                          onPressed: onCancel,
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('Cancel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EasyParkColors.error,
                            foregroundColor: EasyParkColors.onAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

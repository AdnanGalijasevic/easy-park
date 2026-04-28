import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:easypark_desktop/models/parking_location_model.dart';
import 'package:easypark_desktop/models/parking_spot_model.dart';
import 'package:easypark_desktop/models/reservation_model.dart';
import 'package:easypark_desktop/models/review_model.dart';
import 'package:easypark_desktop/providers/parking_spot_provider.dart';
import 'package:easypark_desktop/providers/reservation_provider.dart';
import 'package:easypark_desktop/providers/review_provider.dart';
import 'package:easypark_desktop/screens/master_screen.dart';
import 'package:easypark_desktop/screens/parking_locations_screen.dart';
import 'package:easypark_desktop/screens/parking_location_wizard.dart';
import 'package:easypark_desktop/widgets/dashboard/stats_header.dart';
import 'package:easypark_desktop/widgets/dashboard/occupancy_chart.dart';
import 'package:easypark_desktop/widgets/dashboard/revenue_chart.dart';
import 'package:easypark_desktop/widgets/dashboard/reviews_list.dart';
import 'package:easypark_desktop/widgets/dashboard/spots_status_card.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';
import 'package:easypark_desktop/utils/error_message.dart';

class ParkingDashboardScreen extends StatefulWidget {
  final ParkingLocation location;

  const ParkingDashboardScreen({super.key, required this.location});

  @override
  State<ParkingDashboardScreen> createState() => _ParkingDashboardScreenState();
}

class _ParkingDashboardScreenState extends State<ParkingDashboardScreen> {
  final ParkingSpotProvider _spotProvider = ParkingSpotProvider();
  final ReviewProvider _reviewProvider = ReviewProvider();
  final ReservationProvider _reservationProvider = ReservationProvider();

  List<ParkingSpot> _spots = [];
  bool _isLoadingSpots = true;

  List<Review> _reviews = [];
  bool _isLoadingReviews = true;

  List<Reservation> _reservations = [];
  bool _isLoadingReservations = true;

  bool _isIncludedInReportMetrics(String status) {
    return status != 'Cancelled';
  }

  @override
  void initState() {
    super.initState();
    _loadSpots();
    _loadReviews();
    _loadReservations();
  }

  Future<void> _loadSpots() async {
    try {
      final result = await _spotProvider.get(
        filter: {'parkingLocationId': widget.location.id},
        pageSize: 1000,
      );
      if (mounted) {
        setState(() {
          _spots = result.result;
          _isLoadingSpots = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSpots = false);
        _showError(
          'Could not load parking spots for this location: ${normalizeErrorMessage(e)}',
        );
      }
    }
  }

  Future<void> _loadReviews() async {
    try {
      final result = await _reviewProvider.get(
        filter: {'parkingLocationId': widget.location.id},
        pageSize: 1000,
      );
      if (mounted) {
        setState(() {
          _reviews = result.result;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReviews = false);
        _showError(
          'Could not load location reviews: ${normalizeErrorMessage(e)}',
        );
      }
    }
  }

  Future<void> _loadReservations() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final result = await _reservationProvider.get(
        filter: {
          'parkingLocationId': widget.location.id,
          'startTimeFrom': thirtyDaysAgo.toIso8601String(),
        },
        pageSize: 5000,
      );
      if (mounted) {
        setState(() {
          _reservations = result.result;
          _isLoadingReservations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReservations = false);
        _showError(
          'Could not load recent reservations: ${normalizeErrorMessage(e)}',
        );
      }
    }
  }

  void _refreshAll() {
    setState(() {
      _isLoadingSpots = true;
      _isLoadingReviews = true;
      _isLoadingReservations = true;
    });
    _loadSpots();
    _loadReviews();
    _loadReservations();
  }

  List<_MonthlyMetric> _buildMonthlyMetrics() {
    final now = DateTime.now();
    final metrics = <_MonthlyMetric>[];

    for (int monthOffset = 5; monthOffset >= 0; monthOffset--) {
      final monthDate = DateTime(now.year, now.month - monthOffset, 1);
      final nextMonth = DateTime(monthDate.year, monthDate.month + 1, 1);
      final monthReservations = _reservations
          .where(
            (r) =>
                !r.startTime.isBefore(monthDate) &&
                r.startTime.isBefore(nextMonth),
          )
          .toList();
      final completedRevenue = monthReservations
          .where((r) => _isIncludedInReportMetrics(r.status))
          .fold<double>(0, (sum, r) => sum + r.totalPrice);

      final totalHours = monthReservations.fold<double>(
        0,
        (sum, r) =>
            sum +
            r.endTime.difference(r.startTime).inMinutes.clamp(0, 24 * 60) /
                60.0,
      );
      final monthCapacityHours = _spots.isEmpty
          ? 1.0
          : (_spots.length *
                    DateUtils.getDaysInMonth(monthDate.year, monthDate.month) *
                    24)
                .toDouble();
      final occupancyPercent = (totalHours / monthCapacityHours) * 100;

      metrics.add(
        _MonthlyMetric(
          monthLabel: '${monthDate.month}.${monthDate.year}',
          revenue: completedRevenue,
          occupancyPercent: occupancyPercent.clamp(0, 100),
        ),
      );
    }

    return metrics;
  }

  Future<void> _exportPdfReport() async {
    if (_isLoadingReservations || _isLoadingSpots) {
      _showError('Wait for dashboard data to finish loading, then try again.');
      return;
    }

    final metrics = _buildMonthlyMetrics();
    final maxRevenue = metrics.isEmpty
        ? 1.0
        : metrics
              .map((m) => m.revenue)
              .reduce((a, b) => a > b ? a : b)
              .clamp(1, double.infinity);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'EasyPark Dashboard Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Parking: ${widget.location.name}'),
          pw.Text('Period: posljednjih 6 mjeseci'),
          pw.SizedBox(height: 18),
          pw.Text(
            'Monthly Revenue',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...metrics.map(
            (m) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                children: [
                  pw.SizedBox(width: 70, child: pw.Text(m.monthLabel)),
                  pw.Expanded(
                    child: pw.Container(
                      height: 10,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue100,
                      ),
                      child: pw.Align(
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Container(
                          width:
                              260 *
                              (m.revenue / maxRevenue).clamp(0, 1).toDouble(),
                          color: PdfColors.blue600,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text('\$${m.revenue.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Monthly Occupancy (%)',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...metrics.map(
            (m) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                children: [
                  pw.SizedBox(width: 70, child: pw.Text(m.monthLabel)),
                  pw.Expanded(
                    child: pw.Container(
                      height: 10,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.green100,
                      ),
                      child: pw.Align(
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Container(
                          width:
                              260 *
                              (m.occupancyPercent / 100).clamp(0, 1).toDouble(),
                          color: PdfColors.green600,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text('${m.occupancyPercent.toStringAsFixed(1)}%'),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Month', 'Revenue', 'Occupancy'],
            data: metrics
                .map(
                  (m) => [
                    m.monthLabel,
                    '\$${m.revenue.toStringAsFixed(2)}',
                    '${m.occupancyPercent.toStringAsFixed(1)}%',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  Future<void> _toggleOccupied(ParkingSpot spot) async {
    try {
      await _spotProvider.update(spot.id, {
        'parkingLocationId': spot.parkingLocationId,
        'spotNumber': spot.spotNumber,
        'spotType': spot.spotType,
        'isActive': spot.isActive,
        'isOccupied': !spot.isOccupied,
      });
      await _loadSpots();
    } catch (e) {
      if (mounted) {
        _showError(
          'Could not update spot occupancy status: ${normalizeErrorMessage(e)}',
        );
      }
    }
  }

  Future<void> _toggleSpotActive(ParkingSpot spot) async {
    try {
      await _spotProvider.update(spot.id, {
        'parkingLocationId': spot.parkingLocationId,
        'spotNumber': spot.spotNumber,
        'spotType': spot.spotType,
        'isActive': !spot.isActive,
        'isOccupied': spot.isOccupied,
      });
      await _loadSpots();
    } catch (e) {
      if (mounted) {
        _showError(
          'Could not update whether the spot is active: ${normalizeErrorMessage(e)}',
        );
      }
    }
  }

  Future<void> _deleteSpot(int id) async {
    try {
      await _spotProvider.delete(id);
      await _loadSpots();
      if (mounted) _showSuccess('Parking spot removed successfully.');
    } catch (e) {
      if (mounted) {
        _showError('Could not delete parking spot: ${normalizeErrorMessage(e)}');
      }
    }
  }

  Future<void> _deleteReview(int id) async {
    try {
      await _reviewProvider.delete(id);
      await _loadReviews();
      if (mounted) _showSuccess('Review removed successfully.');
    } catch (e) {
      if (mounted) {
        _showError('Could not delete review: ${normalizeErrorMessage(e)}');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: EasyParkColors.error),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: EasyParkColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canExportPdf = !(_isLoadingReservations || _isLoadingSpots);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.location.name} Dashboard'),
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'Back to parking locations',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => masterScreenKey.currentState?.navigateTo(
              const ParkingLocationsScreen(),
            ),
          ),
          actions: [
            Tooltip(
              message: canExportPdf
                  ? 'Export PDF report'
                  : 'Wait for dashboard data to finish loading.',
              child: IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'Export PDF report',
                onPressed: canExportPdf ? _exportPdfReport : null,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit location',
              onPressed: () => masterScreenKey.currentState?.navigateTo(
                ParkingLocationWizardScreen(location: widget.location),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _refreshAll,
            ),
          ],
          bottom: const TabBar(
            labelColor: EasyParkColors.onBackground,
            unselectedLabelColor: EasyParkColors.onBackgroundMuted,
            indicatorColor: EasyParkColors.accent,
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'Reviews'),
            ],
          ),
        ),
        body: TabBarView(children: [_buildDashboardTab(), _buildReviewsTab()]),
      ),
    );
  }

  Widget _buildDashboardTab() {
    if (_isLoadingSpots) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardStatsHeader(spots: _spots),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _isLoadingReservations
                    ? const SizedBox(
                        height: 320,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : OccupancyChart(reservations: _reservations),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _isLoadingReservations
                    ? const SizedBox(
                        height: 320,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : RevenueChart(reservations: _reservations),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SpotsStatusCard(
            spots: _spots,
            onToggleOccupied: _toggleOccupied,
            onToggleActive: _toggleSpotActive,
            onDelete: _deleteSpot,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_isLoadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ReviewsList(reviews: _reviews, onDelete: _deleteReview),
    );
  }
}

class _MonthlyMetric {
  final String monthLabel;
  final double revenue;
  final double occupancyPercent;

  const _MonthlyMetric({
    required this.monthLabel,
    required this.revenue,
    required this.occupancyPercent,
  });
}

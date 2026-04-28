import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easypark_desktop/app_colors.dart';
import 'package:easypark_desktop/models/reservation_model.dart';
import 'package:easypark_desktop/models/parking_location_name_model.dart';
import 'package:easypark_desktop/providers/reservation_history_provider.dart';
import 'package:easypark_desktop/providers/parking_location_provider.dart';
import 'package:easypark_desktop/providers/reservation_provider.dart';
import 'package:easypark_desktop/models/reservation_history_model.dart';
import 'package:easypark_desktop/widgets/pagination_controls.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';
import 'package:easypark_desktop/utils/error_message.dart';

class ReservationHistoryScreen extends StatefulWidget {
  const ReservationHistoryScreen({super.key});

  @override
  ReservationHistoryScreenState createState() =>
      ReservationHistoryScreenState();
}

class ReservationHistoryScreenState extends State<ReservationHistoryScreen> {
  final ReservationHistoryProvider _provider = ReservationHistoryProvider();
  final ReservationProvider _reservationProvider = ReservationProvider();
  final ParkingLocationProvider _parkingLocationProvider =
      ParkingLocationProvider();
  List<ReservationHistory> _history = [];
  List<ParkingLocationNameModel> _parkingLocations = [];
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isLoading = true;
  int? _parkingLocationIdFilter;
  DateTime? _fromDate;
  DateTime? _toDate;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: EasyParkColors.error, content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentPage = 0;
    _loadParkingLocationNames();
    _loadHistory();
  }

  Future<void> _loadParkingLocationNames() async {
    try {
      final names = await _parkingLocationProvider.getNames();
      if (!mounted) return;
      setState(() => _parkingLocations = names);
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final filter = <String, dynamic>{};
      if (_parkingLocationIdFilter != null) {
        filter['parkingLocationId'] = _parkingLocationIdFilter;
      }
      if (_fromDate != null) {
        filter['changedFrom'] = _fromDate!.toIso8601String();
      }
      if (_toDate != null) {
        filter['changedTo'] = _toDate!
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1))
            .toIso8601String();
      }

      var searchResult = await _provider.get(
        page: _currentPage,
        pageSize: 20,
        filter: filter,
      );

      setState(() {
        _history = searchResult.result;
        _isLoading = false;
        _totalPages = (searchResult.count / 20).ceil();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError(
        'Failed to load reservation history: ${normalizeErrorMessage(e)}',
      );
    }
  }

  void _goToPreviousPage() {
    setState(() {
      _currentPage--;
    });
    _loadHistory();
  }

  void _goToNextPage() {
    setState(() {
      _currentPage++;
    });
    _loadHistory();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? _fromDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;

    final nextFrom = isFrom ? picked : _fromDate;
    final nextTo = isFrom ? _toDate : picked;
    if (nextFrom != null && nextTo != null && nextFrom.isAfter(nextTo)) {
      _showError('Invalid range: "From" date must be before "To" date.');
      return;
    }

    setState(() {
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
      _currentPage = 0;
    });
    _loadHistory();
  }

  void _clearFilters() {
    setState(() {
      _parkingLocationIdFilter = null;
      _fromDate = null;
      _toDate = null;
      _currentPage = 0;
    });
    _loadHistory();
  }

  String _formatDateTime(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.'
        '${value.month.toString().padLeft(2, '0')}.'
        '${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String _idHiddenByPolicyLabel() {
    return 'Not shown (hidden by admin UI policy)';
  }

  String _formatDuration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    if (diff.inMinutes <= 0) return '0m';
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours == 0) return '${diff.inMinutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: EasyParkColors.textSecondary,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _openHistoryDetails(ReservationHistory entry) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reservation History Details'),
        content: SizedBox(
          width: 520,
          child: FutureBuilder<Reservation>(
            future: _reservationProvider.getById(entry.reservationId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final reservation = snapshot.data;
              final detailsLoadFailed = snapshot.hasError;
              final errorText = detailsLoadFailed
                  ? normalizeErrorMessage(snapshot.error!)
                  : null;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow('History reference', _idHiddenByPolicyLabel()),
                    _detailRow(
                      'Reservation reference',
                      _idHiddenByPolicyLabel(),
                    ),
                    _detailRow('Changed at', _formatDateTime(entry.changedAt)),
                    _detailRow('Changed by', entry.userFullName ?? 'Unknown'),
                    _detailRow('Previous status', entry.oldStatus ?? 'N/A'),
                    _detailRow('New status', entry.newStatus ?? 'N/A'),
                    if (reservation != null) ...[
                      const Divider(height: 20),
                      const Text(
                        'Reservation Snapshot',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _detailRow(
                        'Location',
                        reservation.parkingLocationName ?? 'Not available',
                      ),
                      _detailRow(
                        'Spot',
                        reservation.spotNumber == null
                            ? 'Not available'
                            : '${reservation.spotNumber} (${reservation.spotType ?? 'Standard'})',
                      ),
                      _detailRow(
                        'Start time',
                        _formatDateTime(reservation.startTime),
                      ),
                      _detailRow(
                        'End time',
                        _formatDateTime(reservation.endTime),
                      ),
                      _detailRow(
                        'Duration',
                        _formatDuration(
                          reservation.startTime,
                          reservation.endTime,
                        ),
                      ),
                      _detailRow(
                        'Total price',
                        '\$${reservation.totalPrice.toStringAsFixed(2)}',
                      ),
                      _detailRow('Current status', reservation.status),
                    ],
                    if (detailsLoadFailed) ...[
                      const Divider(height: 20),
                      const Text(
                        'Additional reservation details unavailable.',
                        style: TextStyle(
                          color: EasyParkColors.accent,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      if (errorText != null && errorText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            errorText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: EasyParkColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                    const Divider(height: 20),
                    _detailRow('Reason', entry.changeReason ?? 'Not provided'),
                    _detailRow('Notes', entry.notes ?? 'Not provided'),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: EasyParkColors.transparent,
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Text(
              'Orders & Reservation History',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: EasyParkColors.onBackground,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                Container(
                  constraints: const BoxConstraints(minHeight: 42),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: EasyParkColors.info.withValues(alpha: 0.1),
                    border: Border.all(
                      color: EasyParkColors.info.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: EasyParkColors.info),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Desktop supports order oversight and status history. Customer order creation happens in client apps.',
                          style: TextStyle(
                            color: EasyParkColors.info,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 240,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: EasyParkColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _parkingLocationIdFilter,
                      isExpanded: true,
                      hint: const Text(
                        'All Parking Locations',
                        style: TextStyle(color: EasyParkColors.onAccent),
                      ),
                      dropdownColor: EasyParkColors.surfaceElevated,
                      iconEnabledColor: EasyParkColors.onAccent,
                      style: const TextStyle(color: EasyParkColors.onAccent),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'All Parking Locations',
                            style: TextStyle(color: EasyParkColors.onAccent),
                          ),
                        ),
                        ..._parkingLocations.map(
                          (p) => DropdownMenuItem<int?>(
                            value: p.id,
                            child: Text(
                              p.name,
                              style: const TextStyle(
                                color: EasyParkColors.onAccent,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _parkingLocationIdFilter = val;
                          _currentPage = 0;
                        });
                        _loadHistory();
                      },
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickDate(isFrom: true),
                  icon: const Icon(Icons.calendar_today),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EasyParkColors.accent,
                    foregroundColor: EasyParkColors.onAccent,
                  ),
                  label: Text(
                    _fromDate == null
                        ? 'From'
                        : '${_fromDate!.day}.${_fromDate!.month}.${_fromDate!.year}',
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickDate(isFrom: false),
                  icon: const Icon(Icons.calendar_today),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EasyParkColors.accent,
                    foregroundColor: EasyParkColors.onAccent,
                  ),
                  label: Text(
                    _toDate == null
                        ? 'To'
                        : '${_toDate!.day}.${_toDate!.month}.${_toDate!.year}',
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear filters'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _isLoading
                ? const Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                  )
                : Expanded(
                    child: _history.isEmpty
                        ? const Center(child: Text('No history found.'))
                        : ListView.builder(
                            itemCount: _history.length,
                            itemBuilder: (context, index) {
                              final entry = _history[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _openHistoryDetails(entry),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0,
                                      vertical: 8.0,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.history,
                                          size: 32,
                                          color: AppColors.primaryGreen,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'History entry',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (entry.oldStatus != null ||
                                                  entry.newStatus != null)
                                                Text(
                                                  '${entry.oldStatus ?? "N/A"} -> ${entry.newStatus ?? "N/A"}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: EasyParkColors
                                                        .textSecondary,
                                                  ),
                                                ),
                                              if (entry.changeReason != null)
                                                Text(
                                                  'Reason: ${entry.changeReason}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: EasyParkColors.muted,
                                                  ),
                                                ),
                                              if (entry.userFullName != null)
                                                Text(
                                                  'By: ${entry.userFullName}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: EasyParkColors.muted,
                                                  ),
                                                ),
                                              Text(
                                                _formatDateTime(
                                                  entry.changedAt,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: EasyParkColors
                                                      .onBackgroundMuted,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'Click row for details',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: EasyParkColors.info,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
            const SizedBox(height: 12),
            PaginationControls(
              currentPage: _currentPage,
              totalPages: _totalPages,
              onPrevious: _goToPreviousPage,
              onNext: _goToNextPage,
            ),
          ],
        ),
      ),
    );
  }
}

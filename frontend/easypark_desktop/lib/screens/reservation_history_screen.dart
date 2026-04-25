import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easypark_desktop/app_colors.dart';
import 'package:easypark_desktop/models/parking_location_name_model.dart';
import 'package:easypark_desktop/providers/reservation_history_provider.dart';
import 'package:easypark_desktop/providers/parking_location_provider.dart';
import 'package:easypark_desktop/models/reservation_history_model.dart';
import 'package:easypark_desktop/widgets/pagination_controls.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';

class ReservationHistoryScreen extends StatefulWidget {
  const ReservationHistoryScreen({super.key});

  @override
  ReservationHistoryScreenState createState() =>
      ReservationHistoryScreenState();
}

class ReservationHistoryScreenState extends State<ReservationHistoryScreen> {
  final ReservationHistoryProvider _provider = ReservationHistoryProvider();
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
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Ok'),
              ),
            ],
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: EasyParkColors.transparent,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Text(
              'Reservation History',
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
                              style: const TextStyle(color: EasyParkColors.onAccent),
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
                                            Text(
                                              'Reservation #${entry.reservationId}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (entry.oldStatus != null ||
                                                entry.newStatus != null)
                                              Text(
                                                '${entry.oldStatus ?? "N/A"} → ${entry.newStatus ?? "N/A"}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: EasyParkColors.textSecondary,
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
                                              entry.changedAt
                                                  .toString()
                                                  .substring(0, 19),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: EasyParkColors.onBackgroundMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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

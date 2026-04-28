import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easypark_mobile/models/parking_location.dart';
import 'package:easypark_mobile/models/review.dart';
import 'package:easypark_mobile/models/spot_type_availability.dart';
import 'package:easypark_mobile/providers/reservation_provider.dart';
import 'package:easypark_mobile/providers/review_provider.dart';
import 'package:easypark_mobile/theme/easy_park_colors.dart';
import 'package:easypark_mobile/utils/app_feedback.dart';

/// Tabbed dialog with "Reserve" and "Reviews" tabs for a parking location.
class ReservationDialog extends StatefulWidget {
  final ParkingLocation location;

  const ReservationDialog({super.key, required this.location});

  @override
  State<ReservationDialog> createState() => _ReservationDialogState();
}

class _ReservationDialogState extends State<ReservationDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<ReviewProvider>(
          context,
          listen: false,
        ).loadReviews(widget.location.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                decoration: const BoxDecoration(
                  color: EasyParkColors.accent,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.location.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: EasyParkColors.onAccent,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: EasyParkColors.onAccent,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    TabBar(
                      controller: _tabController,
                      labelColor: EasyParkColors.onAccent,
                      unselectedLabelColor: EasyParkColors.onAccentMuted,
                      indicatorColor: EasyParkColors.onAccent,
                      tabs: const [
                        Tab(text: 'Reserve'),
                        Tab(text: 'Reviews'),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ReserveTab(location: widget.location),
                    _ReviewsTab(location: widget.location),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReserveTab extends StatefulWidget {
  final ParkingLocation location;
  const _ReserveTab({required this.location});

  @override
  State<_ReserveTab> createState() => _ReserveTabState();
}

const _spotTypesMeta = [
  _SpotMeta('Regular', Icons.local_parking),
  _SpotMeta('Disabled', Icons.accessible),
  _SpotMeta('Electric', Icons.electric_car),
  _SpotMeta('Covered', Icons.garage),
];

class _SpotMeta {
  final String type;
  final IconData icon;
  const _SpotMeta(this.type, this.icon);
}

class _ReserveTabState extends State<_ReserveTab> {
  String? _selectedType;
  late DateTime _startTime;
  late DateTime _endTime;
  bool _loadingAvailability = false;
  List<SpotTypeAvailability> _availability = [];
  String? _availError;
  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '').trim();

  @override
  void initState() {
    super.initState();
    _startTime = _roundUp(DateTime.now());
    _endTime = _startTime.add(const Duration(hours: 1));
    _loadAvailability();
  }

  static DateTime _roundUp(DateTime dt) {
    if (dt.minute == 0) return DateTime(dt.year, dt.month, dt.day, dt.hour);
    if (dt.minute <= 30) {
      return DateTime(dt.year, dt.month, dt.day, dt.hour, 30);
    }
    return DateTime(dt.year, dt.month, dt.day, dt.hour + 1, 0);
  }

  Future<void> _loadAvailability() async {
    setState(() {
      _loadingAvailability = true;
      _availError = null;
    });
    try {
      final provider = Provider.of<ReservationProvider>(context, listen: false);
      final from = DateTime.now().toUtc();
      final to = from.add(const Duration(days: 3));
      final result = await provider.fetchAvailability(
        locationId: widget.location.id,
        from: from,
        to: to,
      );
      if (mounted) setState(() => _availability = result);
    } catch (e) {
      if (mounted) {
        setState(
          () => _availError = 'Could not load availability. ${_cleanError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAvailability = false);
    }
  }

  double _priceForType(String? type) {
    switch (type) {
      case 'Disabled':
        return widget.location.priceDisabled > 0
            ? widget.location.priceDisabled
            : widget.location.priceRegular;
      case 'Electric':
        return widget.location.priceElectric > 0
            ? widget.location.priceElectric
            : widget.location.priceRegular;
      case 'Covered':
        return widget.location.priceCovered > 0
            ? widget.location.priceCovered
            : widget.location.priceRegular;
      default:
        return widget.location.priceRegular;
    }
  }

  SpotTypeAvailability? _availForType(String type) {
    try {
      return _availability.firstWhere((a) => a.spotType == type);
    } catch (_) {
      return null;
    }
  }

  String? _operatingHoursBlockReason() {
    if (widget.location.is24Hours) return null;
    final operating = widget.location.operatingHours?.trim();
    if (operating == null || operating.isEmpty) return null;

    final parts = operating.split('-');
    if (parts.length != 2) return null;

    TimeOfDay? parse(String raw) {
      final chunks = raw.trim().split(':');
      if (chunks.length != 2) return null;
      final h = int.tryParse(chunks[0]);
      final m = int.tryParse(chunks[1]);
      if (h == null || m == null) return null;
      if (h < 0 || h > 23 || m < 0 || m > 59) return null;
      return TimeOfDay(hour: h, minute: m);
    }

    final open = parse(parts[0]);
    final close = parse(parts[1]);
    if (open == null || close == null) return null;

    int asMinutes(DateTime dt) => dt.hour * 60 + dt.minute;
    int todMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

    final start = asMinutes(_startTime);
    final end = asMinutes(_endTime);
    final openM = todMinutes(open);
    final closeM = todMinutes(close);

    bool within(int value) {
      if (openM == closeM) return true;
      if (openM < closeM) {
        return value >= openM && value <= closeM;
      }
      return value >= openM || value <= closeM;
    }

    if (!within(start) || !within(end)) {
      return 'Selected window must be within operating hours ($operating).';
    }

    return null;
  }

  /// True if the selected type has at least 1 free spot for the chosen window.
  bool get _canReserveNow {
    if (_selectedType == null) return false;
    final avail = _availForType(_selectedType!);
    if (avail == null) return true; // no info yet — let backend decide
    return !avail.busySlots.any(
      (s) => s.start.isBefore(_endTime) && s.end.isAfter(_startTime),
    );
  }

  Future<void> _pickDateTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    int min = time.minute;
    int roundedMin = min < 15 ? 0 : (min < 45 ? 30 : 0);
    int roundedHour = min >= 45 ? time.hour + 1 : time.hour;
    var selected = DateTime(
      date.year,
      date.month,
      date.day,
      roundedHour,
      roundedMin,
    );

    if (selected.isBefore(DateTime.now())) selected = _roundUp(DateTime.now());

    setState(() {
      if (isStart) {
        _startTime = selected;
        if (!_endTime.isAfter(_startTime)) {
          _endTime = _startTime.add(const Duration(minutes: 30));
        }
        if (_endTime.difference(_startTime).inMinutes > 24 * 60) {
          _endTime = _startTime.add(const Duration(hours: 24));
        }
      } else {
        _endTime = selected;
        if (!_endTime.isAfter(_startTime)) {
          _startTime = _endTime.subtract(const Duration(minutes: 30));
        }
        if (_endTime.difference(_startTime).inMinutes > 24 * 60) {
          _startTime = _endTime.subtract(const Duration(hours: 24));
        }
      }
    });
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final reservationProvider = Provider.of<ReservationProvider>(context);
    final durationMins = _endTime.difference(_startTime).inMinutes;
    final hours = durationMins / 60.0;
    final pricePerHour = _priceForType(_selectedType);
    final totalCost = pricePerHour * hours;
    final operatingHoursBlockReason = _operatingHoursBlockReason();
    final reserveDisabledReason = reservationProvider.isBooking
        ? 'Reservation is being created...'
        : _selectedType == null
        ? 'Choose a spot type to continue.'
        : operatingHoursBlockReason ??
              (!_canReserveNow
                  ? 'Selected time overlaps with fully booked periods. Pick a different window.'
                  : null);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.location.address,
                  style: const TextStyle(color: EasyParkColors.textSecondary),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Select Spot Type',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.4,
                  children: _spotTypesMeta.map((meta) {
                    final avail = _availForType(meta.type);
                    final total =
                        avail?.totalSpots ??
                        (widget.location.parkingSpots
                                ?.where(
                                  (s) => s.spotType == meta.type && s.isActive,
                                )
                                .length ??
                            0);
                    final isSelected = _selectedType == meta.type;
                    final hasSpots = total > 0;
                    final price = _priceForType(meta.type);
                    final unavailableReason = hasSpots
                        ? null
                        : 'No active ${meta.type.toLowerCase()} spots are currently available at this location.';

                    final busyInWindow =
                        avail?.busySlots
                            .where(
                              (s) =>
                                  s.start.isBefore(_endTime) &&
                                  s.end.isAfter(_startTime),
                            )
                            .length ??
                        0;

                    return _SpotTypeButton(
                      label: meta.type,
                      icon: meta.icon,
                      total: total,
                      price: price,
                      busyInWindow: busyInWindow,
                      isSelected: isSelected,
                      unavailableReason: unavailableReason,
                      onTap: hasSpots
                          ? () => setState(() => _selectedType = meta.type)
                          : null,
                    );
                  }).toList(),
                ),

                if (_selectedType != null) ...[
                  const SizedBox(height: 16),
                  _AvailabilitySection(
                    availability: _availForType(_selectedType!),
                    isLoading: _loadingAvailability,
                    error: _availError,
                    startTime: _startTime,
                    endTime: _endTime,
                    onRefresh: _loadAvailability,
                  ),
                ],

                const SizedBox(height: 16),

                const Text(
                  'Time (Max 24h, 30m steps)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDateTime(true),
                        child: _TimeBox(
                          label: 'Start',
                          value: _fmt(_startTime),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDateTime(false),
                        child: _TimeBox(label: 'End', value: _fmt(_endTime)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EasyParkColors.infoContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Cost',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_selectedType != null)
                            Text(
                              '${pricePerHour.toStringAsFixed(2)} coins/hr',
                              style: const TextStyle(
                                fontSize: 11,
                                color: EasyParkColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        _selectedType != null
                            ? '${totalCost.toStringAsFixed(2)} Coins'
                            : '— Coins',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: EasyParkColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: reserveDisabledReason != null
                      ? null
                      : () async {
                          final result = await reservationProvider
                              .createReservation(
                                parkingLocationId: widget.location.id,
                                spotType: _selectedType!,
                                startTime: _startTime,
                                endTime: _endTime,
                              );
                          if (!context.mounted) return;
                          if (result != null) {
                            Navigator.pop(context, result);
                          } else if (reservationProvider.bookingError != null) {
                            AppFeedback.error(
                              reservationProvider.bookingError!.replaceFirst(
                                'Exception: ',
                                '',
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: _canReserveNow && _selectedType != null
                        ? EasyParkColors.accent
                        : EasyParkColors.disabled,
                  ),
                  child: reservationProvider.isBooking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              EasyParkColors.onAccent,
                            ),
                          ),
                        )
                      : Text(
                          _selectedType == null
                              ? 'Select a Spot Type'
                              : !_canReserveNow
                              ? 'No spots available at this time'
                              : 'Reserve $_selectedType Spot',
                          style: const TextStyle(
                            fontSize: 15,
                            color: EasyParkColors.onAccent,
                          ),
                        ),
                ),
                if (reserveDisabledReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      reserveDisabledReason,
                      style: const TextStyle(
                        fontSize: 12,
                        color: EasyParkColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AvailabilitySection extends StatelessWidget {
  final SpotTypeAvailability? availability;
  final bool isLoading;
  final String? error;
  final DateTime startTime;
  final DateTime endTime;
  final VoidCallback onRefresh;

  const _AvailabilitySection({
    required this.availability,
    required this.isLoading,
    required this.error,
    required this.startTime,
    required this.endTime,
    required this.onRefresh,
  });

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: EasyParkColors.dividerLight),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: EasyParkColors.surfaceWash,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.black,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Availability (next 3 days)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (isLoading)
                  const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  InkWell(
                    onTap: onRefresh,
                    child: const Icon(
                      Icons.refresh,
                      size: 16,
                      color: EasyParkColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                error!,
                style: const TextStyle(
                  color: EasyParkColors.accent,
                  fontSize: 12,
                ),
              ),
            )
          else if (isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: Text(
                  'Loading availability...',
                  style: TextStyle(color: EasyParkColors.muted, fontSize: 12),
                ),
              ),
            )
          else if (availability == null || availability!.busySlots.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: EasyParkColors.success,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Fully available! No blocked slots in the next 3 days.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: EasyParkColors.successOnContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _LegendDot(
                        color: EasyParkColors.errorLight,
                        label: 'All spots busy',
                      ),
                      const SizedBox(width: 12),
                      const _LegendDot(
                        color: EasyParkColors.successLight,
                        label: 'Available',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SelectedWindowInfo(
                    startTime: startTime,
                    endTime: endTime,
                    busySlots: availability!.busySlots,
                    fmtTime: _fmtTime,
                    fmtDate: _fmtDate,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Fully booked periods:',
                    style: const TextStyle(
                      fontSize: 11,
                      color: EasyParkColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...availability!.busySlots.map((slot) {
                    final overlaps =
                        slot.start.isBefore(endTime) &&
                        slot.end.isAfter(startTime);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: overlaps
                            ? EasyParkColors.errorContainer
                            : EasyParkColors.surfaceWash,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: overlaps
                              ? EasyParkColors.errorLight
                              : EasyParkColors.borderLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            overlaps ? Icons.warning_amber : Icons.block,
                            size: 14,
                            color: overlaps
                                ? EasyParkColors.error
                                : EasyParkColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_fmtDate(slot.start.toLocal())}  '
                            '${_fmtTime(slot.start.toLocal())} – '
                            '${_fmtTime(slot.end.toLocal())}',
                            style: TextStyle(
                              fontSize: 12,
                              color: overlaps
                                  ? EasyParkColors.errorOnContainer
                                  : EasyParkColors.textOnLightSecondary,
                              fontWeight: overlaps
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          if (overlaps) ...[
                            const Spacer(),
                            const Text(
                              '⚠ Conflicts',
                              style: TextStyle(
                                fontSize: 10,
                                color: EasyParkColors.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectedWindowInfo extends StatelessWidget {
  final DateTime startTime;
  final DateTime endTime;
  final List<TimeSlot> busySlots;
  final String Function(DateTime) fmtTime;
  final String Function(DateTime) fmtDate;

  const _SelectedWindowInfo({
    required this.startTime,
    required this.endTime,
    required this.busySlots,
    required this.fmtTime,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    final conflicts = busySlots
        .where((s) => s.start.isBefore(endTime) && s.end.isAfter(startTime))
        .toList();

    final ok = conflicts.isEmpty;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: ok
            ? EasyParkColors.successContainer
            : EasyParkColors.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ok ? EasyParkColors.successLight : EasyParkColors.errorLight,
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: ok ? EasyParkColors.success : EasyParkColors.error,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              ok
                  ? 'Your window (${fmtTime(startTime)}–${fmtTime(endTime)}) is free!'
                  : 'Your window conflicts with ${conflicts.length} blocked period(s).',
              style: TextStyle(
                fontSize: 11,
                color: ok
                    ? EasyParkColors.successOnContainer
                    : EasyParkColors.errorOnContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: EasyParkColors.muted),
        ),
      ],
    );
  }
}

class _SpotTypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final int total;
  final double price;
  final int busyInWindow;
  final bool isSelected;
  final String? unavailableReason;
  final VoidCallback? onTap;

  const _SpotTypeButton({
    required this.label,
    required this.icon,
    required this.total,
    required this.price,
    required this.busyInWindow,
    required this.isSelected,
    this.unavailableReason,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    final bg = isDisabled
        ? EasyParkColors.surfaceWash
        : isSelected
        ? EasyParkColors.accent
        : EasyParkColors.inverseSurface;
    final fgColor = isDisabled
        ? EasyParkColors.disabled
        : isSelected
        ? EasyParkColors.onAccent
        : EasyParkColors.textOnLightPrimary;
    final borderColor = isSelected
        ? EasyParkColors.accent
        : EasyParkColors.borderLight;

    return Tooltip(
      message: isDisabled
          ? (unavailableReason ?? 'This spot type is currently unavailable.')
          : 'Tap to select $label spot type.',
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: EasyParkColors.accent.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Icon(icon, color: fgColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: fgColor,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      isDisabled ? 'None' : '$total spots',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDisabled
                            ? EasyParkColors.disabled
                            : isSelected
                            ? EasyParkColors.onAccentMuted
                            : EasyParkColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${price.toStringAsFixed(0)}c/h',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? EasyParkColors.onAccentMuted
                          : EasyParkColors.textSecondary,
                    ),
                  ),
                  if (!isDisabled && busyInWindow > 0)
                    Text(
                      'busy',
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? EasyParkColors.highlightBorder
                            : EasyParkColors.accent,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String label;
  final String value;
  const _TimeBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: EasyParkColors.borderLight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: EasyParkColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ReviewsTab extends StatefulWidget {
  final ParkingLocation location;
  const _ReviewsTab({required this.location});

  @override
  State<_ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<_ReviewsTab> {
  int _rating = 0;
  final _commentController = TextEditingController();
  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '').trim();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReviewProvider>(
      builder: (context, reviewProvider, _) {
        final reviews = reviewProvider.reviewsForLocation(widget.location.id);
        final isLoading = reviewProvider.isLoadingForLocation(
          widget.location.id,
        );

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: EasyParkColors.surface,
                border: Border(
                  bottom: BorderSide(color: EasyParkColors.outline),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Leave a Review',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: EasyParkColors.onBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) {
                      final v = i + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = v),
                        child: Icon(
                          v <= _rating ? Icons.star : Icons.star_border,
                          color: EasyParkColors.highlightBorder,
                          size: 30,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    style: const TextStyle(color: EasyParkColors.onBackground),
                    decoration: const InputDecoration(
                      hintText: 'Share your experience... (optional)',
                      hintStyle: TextStyle(
                        color: EasyParkColors.onBackgroundMuted,
                      ),
                      filled: true,
                      fillColor: EasyParkColors.surfaceElevated,
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: EasyParkColors.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: EasyParkColors.accent),
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.all(10),
                    ),
                    maxLines: 2,
                    maxLength: 300,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _rating == 0 || reviewProvider.isSubmitting
                          ? null
                          : () async {
                              try {
                                await reviewProvider.submitReview(
                                  parkingLocationId: widget.location.id,
                                  rating: _rating,
                                  comment:
                                      _commentController.text.trim().isEmpty
                                      ? null
                                      : _commentController.text.trim(),
                                );
                                setState(() {
                                  _rating = 0;
                                  _commentController.clear();
                                });
                                if (context.mounted) {
                                  AppFeedback.success('Review submitted!');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  AppFeedback.error(_cleanError(e));
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EasyParkColors.accent,
                        disabledBackgroundColor: EasyParkColors.disabled,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: reviewProvider.isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: EasyParkColors.onAccent,
                              ),
                            )
                          : const Text(
                              'Submit Review',
                              style: TextStyle(color: EasyParkColors.onAccent),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: EasyParkColors.background,
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : reviews.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.rate_review_outlined,
                              size: 48,
                              color: EasyParkColors.onBackgroundMuted,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No reviews yet — be the first!',
                              style: TextStyle(
                                color: EasyParkColors.onBackgroundMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: reviews.length,
                        separatorBuilder: (context, _) =>
                            const Divider(color: EasyParkColors.outline),
                        itemBuilder: (_, i) => _ReviewItem(review: reviews[i]),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final Review review;
  const _ReviewItem({required this.review});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.person_outline,
              size: 16,
              color: EasyParkColors.muted,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                review.userFullName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: EasyParkColors.onBackground,
                ),
              ),
            ),
            Text(
              '${review.createdAt.day}.${review.createdAt.month}.${review.createdAt.year}',
              style: const TextStyle(
                fontSize: 11,
                color: EasyParkColors.onBackgroundMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(
            5,
            (si) => Icon(
              si < review.rating ? Icons.star : Icons.star_border,
              color: EasyParkColors.highlightBorder,
              size: 16,
            ),
          ),
        ),
        if (review.comment != null && review.comment!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            review.comment!,
            style: const TextStyle(
              color: EasyParkColors.onBackground,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

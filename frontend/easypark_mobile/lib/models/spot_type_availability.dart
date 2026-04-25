class TimeSlot {
  final DateTime start;
  final DateTime end;
  final int availableSpots;

  TimeSlot({
    required this.start,
    required this.end,
    required this.availableSpots,
  });

  bool get isBusy => availableSpots == 0;

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      start: DateTime.parse(json['start'] as String).toLocal(),
      end: DateTime.parse(json['end'] as String).toLocal(),
      availableSpots: json['availableSpots'] as int? ?? 0,
    );
  }
}

class SpotTypeAvailability {
  final String spotType;
  final int totalSpots;
  final List<TimeSlot> busySlots;
  final List<TimeSlot> freeSlots;

  SpotTypeAvailability({
    required this.spotType,
    required this.totalSpots,
    required this.busySlots,
    required this.freeSlots,
  });

  factory SpotTypeAvailability.fromJson(Map<String, dynamic> json) {
    return SpotTypeAvailability(
      spotType: json['spotType'] as String,
      totalSpots: json['totalSpots'] as int,
      busySlots: (json['busySlots'] as List<dynamic>? ?? [])
          .map((e) => TimeSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      freeSlots: (json['freeSlots'] as List<dynamic>? ?? [])
          .map((e) => TimeSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Returns true if at least one free slot exists after [from].
  bool hasAvailabilityAfter(DateTime from) {
    return freeSlots.any((s) => s.end.isAfter(from));
  }
}

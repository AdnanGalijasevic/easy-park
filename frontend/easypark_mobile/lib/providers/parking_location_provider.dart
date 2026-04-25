import 'package:easypark_mobile/models/city_coordinate.dart';
import 'package:easypark_mobile/models/parking_location.dart';
import 'package:easypark_mobile/providers/base_provider.dart';
import 'package:easypark_mobile/services/parking_location_service.dart';

class ParkingLocationProvider extends BaseProvider<ParkingLocation> {
  ParkingLocationProvider() : super(ParkingLocationService());

  ParkingLocation? _selectedLocation;
  ParkingLocation? get selectedLocation => _selectedLocation;

  List<ParkingLocation> _recommendedLocations = [];
  List<ParkingLocation> get recommendedLocations => _recommendedLocations;
  Map<String, CityCoordinate> _cityCoordinates = {};
  Map<String, CityCoordinate> get cityCoordinates => _cityCoordinates;

  bool _sortByRecommendation = false;
  bool get sortByRecommendation => _sortByRecommendation;

  Future<void> toggleSortByRecommendation(int? cityId) async {
    _sortByRecommendation = !_sortByRecommendation;
    if (_sortByRecommendation) {
      await loadRecommendations(cityId);
    } else {
      notifyListeners();
    }
  }

  /// Sorted items — applies recommendation sort when enabled.
  List<ParkingLocation> get sortedItems {
    if (!_sortByRecommendation) return items;
    
    // User requested to ONLY see the 3 recommended locations when filter is active
    return _recommendedLocations;
  }

  void selectLocation(ParkingLocation? location) {
    _selectedLocation = location;
    notifyListeners();
  }

  Future<void> loadRecommendations(int? cityId) async {
    try {
      final service = ParkingLocationService();
      _recommendedLocations = await service.getRecommendations(cityId);
      notifyListeners();
    } catch (e) {
      _recommendedLocations = [];
    }
  }

  Future<void> loadCityCoordinates() async {
    try {
      final service = ParkingLocationService();
      final list = await service.getCityCoordinates();
      _cityCoordinates = {for (final city in list) city.city: city};
      notifyListeners();
    } catch (_) {
      _cityCoordinates = {};
    }
  }

  double getRecommendationScore(int locationId) {
    try {
      final rec = _recommendedLocations.firstWhere((l) => l.id == locationId);
      return rec.cbfScore ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  /// Returns a human-readable explanation of why a location is recommended.
  String getRecommendationExplanation(ParkingLocation location) {
    try {
      final rec = _recommendedLocations.firstWhere((l) => l.id == location.id);
      if (rec.cbfExplanation != null && rec.cbfExplanation!.isNotEmpty) {
        return rec.cbfExplanation!;
      }
    } catch (_) {}

    return 'No personal history yet — based on location average rating.';
  }

  /// Best match for the current user (highest CBF score), or null if no useful signal.
  int? get optimalRecommendationLocationId {
    if (_recommendedLocations.isEmpty) return null;
    return _recommendedLocations.first.id;
  }
}

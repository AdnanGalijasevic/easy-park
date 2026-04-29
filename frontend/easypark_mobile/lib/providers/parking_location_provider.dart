import 'package:easypark_mobile/models/city_coordinate.dart';
import 'package:easypark_mobile/models/parking_location.dart';
import 'package:easypark_mobile/providers/base_provider.dart';
import 'package:easypark_mobile/services/parking_location_service.dart';

/// API query keys for [ParkingLocationProvider.locationSearch] (PascalCase for ASP.NET query binding).
abstract final class ParkingLocationSearchKeys {
  static const hasVideoSurveillance = 'HasVideoSurveillance';
  static const hasNightSurveillance = 'HasNightSurveillance';
  static const hasSecurityGuard = 'HasSecurityGuard';
  static const hasRamp = 'HasRamp';
  static const hasWifi = 'HasWifi';
  static const hasRestroom = 'HasRestroom';
  static const hasDisabledSpots = 'HasDisabledSpots';
  static const is24Hours = 'Is24Hours';
  static const hasElectricCharging = 'HasElectricCharging';
  static const hasCoveredSpots = 'HasCoveredSpots';
}

class ParkingLocationProvider extends BaseProvider<ParkingLocation> {
  ParkingLocationProvider() : super(ParkingLocationService());

  /// Home map city dropdown — lives in provider so it survives tab switches (Home dispose).
  String _homeMapCity = 'Mostar';
  String get homeMapCity => _homeMapCity;

  /// Active list filters: when a key is present, API gets `Key=true` (must match).
  final Set<String> _locationFilterKeys = {};
  Set<String> get locationFilterKeys => Set.unmodifiable(_locationFilterKeys);
  int get activeLocationFilterCount => _locationFilterKeys.length;

  void setHomeMapCity(String city) {
    if (_homeMapCity == city) return;
    _homeMapCity = city;
    notifyListeners();
  }

  /// `City` plus any `Has*` / `Is*` filters (online payment & attendant excluded from UI).
  Map<String, dynamic> buildLocationSearch() {
    final m = <String, dynamic>{'City': _homeMapCity};
    for (final k in _locationFilterKeys) {
      m[k] = true;
    }
    return m;
  }

  Future<void> reloadParkingLocations() =>
      loadData(search: buildLocationSearch());

  Future<void> setLocationFilter(String apiKey, bool require) async {
    if (require) {
      _locationFilterKeys.add(apiKey);
    } else {
      _locationFilterKeys.remove(apiKey);
    }
    notifyListeners();
    await loadData(search: buildLocationSearch());
  }

  Future<void> clearLocationFilters() async {
    if (_locationFilterKeys.isEmpty) return;
    _locationFilterKeys.clear();
    notifyListeners();
    await loadData(search: buildLocationSearch());
  }

  bool hasLocationFilter(String apiKey) => _locationFilterKeys.contains(apiKey);

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
    
    return _recommendedLocations;
  }

  void selectLocation(ParkingLocation? location) {
    _selectedLocation = location;
    if (location != null) {
      _homeMapCity = location.city;
    }
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

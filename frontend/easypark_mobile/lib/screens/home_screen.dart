import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:easypark_mobile/providers/parking_location_provider.dart';
import 'package:easypark_mobile/providers/shell_navigation_provider.dart';
import 'package:easypark_mobile/models/parking_location.dart';
import 'package:easypark_mobile/widgets/location_card.dart';
import 'package:easypark_mobile/theme/easy_park_colors.dart';
import 'package:easypark_mobile/utils/app_feedback.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  bool _isLocatingUser = false;
  LatLng? _userLocation;
  String? _lastAutoCenteredCity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final parking = context.read<ParkingLocationProvider>();
      parking.loadData(search: {'City': parking.homeMapCity});
      parking.loadCityCoordinates();
      parking.loadRecommendations(null);
    });
  }

  static final LatLng _defaultMapCenter = LatLng(43.9159, 17.6791);

  Map<String, LatLng> _buildCityCenters(
    List<ParkingLocation> locations,
    ParkingLocationProvider provider,
  ) {
    final centers = <String, LatLng>{};
    provider.cityCoordinates.forEach((city, coord) {
      centers[city] = LatLng(coord.latitude, coord.longitude);
    });
    final grouped = <String, List<ParkingLocation>>{};
    for (final loc in locations) {
      grouped.putIfAbsent(loc.city, () => []).add(loc);
    }

    grouped.forEach((city, cityLocations) {
      final avgLat =
          cityLocations.map((e) => e.latitude).reduce((a, b) => a + b) /
          cityLocations.length;
      final avgLng =
          cityLocations.map((e) => e.longitude).reduce((a, b) => a + b) /
          cityLocations.length;
      centers.putIfAbsent(city, () => LatLng(avgLat, avgLng));
    });

    return centers;
  }

  String _normalizeCity(String city) {
    return city
        .trim()
        .toLowerCase()
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('š', 's')
        .replaceAll('ž', 'z')
        .replaceAll('đ', 'd')
        .replaceAll('’', "'")
        .replaceAll('‑', '-');
  }

  void _onCityChanged(
    String? newCity,
    Map<String, LatLng> cityCenters,
    ParkingLocationProvider provider,
  ) {
    if (newCity == null) return;
    provider.setHomeMapCity(newCity);
    provider.selectLocation(null);
    provider.loadData(search: {'City': newCity});
    final target = cityCenters[newCity];
    if (target == null) return;
    _lastAutoCenteredCity = newCity;
    _mapController.move(target, 14.0);
  }

  void _syncMapCenterForSelectedCity(
    String selectedCity,
    Map<String, LatLng> cityCenters,
  ) {
    final target = cityCenters[selectedCity];
    if (target == null) return;
    if (_lastAutoCenteredCity == selectedCity) return;
    _lastAutoCenteredCity = selectedCity;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(target, 14.0);
    });
  }

  void _animateCameraTo(ParkingLocation location) {
    _mapController.move(LatLng(location.latitude, location.longitude), 17.0);
  }

  void _focusMapOnLocation(ParkingLocation location) {
    _animateCameraTo(location);
  }

  Future<void> _moveToCurrentLocation() async {
    if (_isLocatingUser) return;
    setState(() => _isLocatingUser = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppFeedback.info('Enable location services to center map on your position.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        AppFeedback.info('Location permission is required to use this action.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final userPoint = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() => _userLocation = userPoint);
      }
      _mapController.move(userPoint, 16.0);
    } catch (e) {
      AppFeedback.error('Could not fetch current location.');
    } finally {
      if (mounted) {
        setState(() => _isLocatingUser = false);
      }
    }
  }

  void _tryApplyShellFocus() {
    if (!mounted) return;
    final shell = context.read<ShellNavigationProvider>();
    final parking = context.read<ParkingLocationProvider>();
    final id = shell.pendingParkingLocationIdToFocus;
    if (id == null) return;
    if (parking.isLoading) return;

    ParkingLocation? loc;
    for (final l in parking.items) {
      if (l.id == id) {
        loc = l;
        break;
      }
    }
    if (loc == null) {
      if (parking.items.isEmpty) {
        return;
      }
      shell.clearPendingMapFocus();
      AppFeedback.info(
        'This parking location is no longer available on the map.',
      );
      return;
    }

    shell.clearPendingMapFocus();

    final selected = loc;
    parking.selectLocation(selected);

    _animateCameraTo(selected);
  }

  List<Marker> _createMarkers(
    List<ParkingLocation> locations,
    ParkingLocationProvider provider,
  ) {
    final markers = <Marker>[];

    final optimalId = provider.optimalRecommendationLocationId;

    for (final loc in locations) {
      final score = provider.getRecommendationScore(loc.id);

      Color markerColor;
      if (score > 0.7) {
        markerColor = EasyParkColors.success;
      } else if (score > 0.4) {
        markerColor = EasyParkColors.accent;
      } else if (score > 0) {
        markerColor = EasyParkColors.highlightBorder;
      } else {
        markerColor = EasyParkColors.info;
      }

      final isOptimal = optimalId != null && optimalId == loc.id;

      markers.add(
        Marker(
          key: ValueKey('parking_marker_${loc.id}'),
          point: LatLng(loc.latitude, loc.longitude),
          width: 112,
          height: 68,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => provider.selectLocation(loc),
            child: _buildMarkerChip(
              label: loc.priceRegular.toString(),
              color: markerColor,
              isOptimal: isOptimal,
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildMarkerChip({
    required String label,
    required Color color,
    required bool isOptimal,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: isOptimal
                ? Border.all(
                    color: EasyParkColors.mapMarkerOptimalBorder,
                    width: 2,
                  )
                : null,
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: EasyParkColors.onAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        Icon(
          Icons.arrow_drop_down,
          size: 22,
          color: color,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellNavigationProvider>();
    final provider = context.watch<ParkingLocationProvider>();
    final cityCenters = _buildCityCenters(provider.items, provider);
    final cityNames = cityCenters.keys.toList()..sort();
    final mapCity = provider.homeMapCity;
    final effectiveSelectedCity = cityNames.contains(mapCity)
        ? mapCity
        : (cityNames.isNotEmpty ? cityNames.first : mapCity);
    _syncMapCenterForSelectedCity(effectiveSelectedCity, cityCenters);

    if (shell.pendingParkingLocationIdToFocus != null && !provider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryApplyShellFocus());
    }

    return Scaffold(
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: EasyParkColors.accent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: DropdownButton<String>(
            value: cityNames.contains(effectiveSelectedCity)
                ? effectiveSelectedCity
                : null,
            hint: const Text(
              'Select city',
              style: TextStyle(color: EasyParkColors.onAccent),
            ),
            dropdownColor: EasyParkColors.inverseSurface,
            borderRadius: BorderRadius.circular(12),
            underline: const SizedBox.shrink(),
            icon: const Icon(
              Icons.arrow_drop_down,
              color: EasyParkColors.onAccent,
            ),
            style: const TextStyle(
              color: EasyParkColors.textOnLightPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            selectedItemBuilder: (context) => cityNames
                .map(
                  (city) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      city,
                      style: const TextStyle(
                        color: EasyParkColors.onAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (city) => _onCityChanged(city, cityCenters, provider),
            items: cityNames
                .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                .toList(),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                provider.loadData(search: {'City': effectiveSelectedCity}),
          ),
          Tooltip(
            message: provider.sortByRecommendation
                ? 'Currently sorted by your CBF recommendations. Tap to reset.'
                : 'Sort by Content-Based Filtering recommendations for you.',
            child: IconButton(
              icon: Icon(
                Icons.recommend,
                color: provider.sortByRecommendation
                    ? EasyParkColors.success
                    : null,
              ),
              onPressed: () {
                final cityId = provider.items.isNotEmpty ? provider.items.first.cityId : null;
                provider.toggleSortByRecommendation(cityId);
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter:
                              cityCenters[effectiveSelectedCity] ??
                              _defaultMapCenter,
                          initialZoom: 14.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.easypark_mobile',
                          ),
                          MarkerLayer(
                            markers: [
                              ..._createMarkers(provider.items, provider),
                              if (_userLocation != null)
                                Marker(
                                  key: const ValueKey('user_location_marker'),
                                  point: _userLocation!,
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: EasyParkColors.info,
                                      border: Border.all(
                                        color: EasyParkColors.onAccent,
                                        width: 3,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x40000000),
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: FloatingActionButton.small(
                          heroTag: 'home_map_locate_me_btn',
                          onPressed: _moveToCurrentLocation,
                          backgroundColor: EasyParkColors.onAccent,
                          foregroundColor: EasyParkColors.surface,
                          child: _isLocatingUser
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.my_location),
                        ),
                      ),
                    ],
                  ),
          ),
          Expanded(
            flex: 6,
            child: _buildLocationsList(provider, effectiveSelectedCity),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationsList(
    ParkingLocationProvider provider,
    String selectedCity,
  ) {
    List<ParkingLocation> displayLocations;

    if (provider.selectedLocation != null) {
      displayLocations = [provider.selectedLocation!];
    } else {
      displayLocations = provider.sortedItems
          .where(
            (loc) => _normalizeCity(loc.city) == _normalizeCity(selectedCity),
          )
          .toList();

      if (displayLocations.isEmpty && provider.items.isNotEmpty) {
        displayLocations = provider.items;
      }
    }

    if (displayLocations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: EasyParkColors.onBackgroundMuted),
            const SizedBox(height: 16),
            Text(
              'No parking locations in $selectedCity',
              style: TextStyle(color: EasyParkColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: EasyParkColors.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                provider.selectedLocation != null
                    ? 'Selected Location'
                    : provider.sortByRecommendation
                        ? 'Recommended for You'
                        : 'Parking in $selectedCity',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  if (provider.sortByRecommendation)
                    Tooltip(
                      message: 'Content-Based Filtering (CBF) ranks locations by matching your past reservation history — amenities, spot type, and price similarity.',
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: EasyParkColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: EasyParkColors.success, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.auto_awesome, size: 12, color: EasyParkColors.success),
                            SizedBox(width: 4),
                            Text(
                              'CBF',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: EasyParkColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (provider.selectedLocation != null)
                    TextButton(
                      onPressed: () => provider.selectLocation(null),
                      child: const Text('Show All'),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: displayLocations.length,
            itemBuilder: (context, index) {
              final loc = displayLocations[index];
              final optimalId = provider.optimalRecommendationLocationId;
              final score = provider.getRecommendationScore(loc.id);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (provider.sortByRecommendation && score > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        provider.getRecommendationExplanation(loc),
                        style: TextStyle(
                          fontSize: 11,
                          color: EasyParkColors.success.withValues(alpha: 0.85),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  LocationCard(
                    location: loc,
                    onFirstTap: _focusMapOnLocation,
                    isOptimalRecommendation: optimalId != null && optimalId == loc.id,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

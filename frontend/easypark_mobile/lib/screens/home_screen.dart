import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:easypark_mobile/providers/parking_location_provider.dart';
import 'package:easypark_mobile/providers/shell_navigation_provider.dart';
import 'package:easypark_mobile/services/marker_service.dart';
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
  GoogleMapController? _mapController;
  ParkingLocation? _pendingLocForMap;

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

  static const LatLng _defaultMapCenter = LatLng(43.9159, 17.6791);

  final MarkerService _markerService = MarkerService();

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
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 14.0));
  }

  void _animateCameraTo(ParkingLocation location) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(location.latitude, location.longitude),
        17.0,
      ),
    );
  }

  void _focusMapOnLocation(ParkingLocation location) {
    _animateCameraTo(location);
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

    if (_mapController != null) {
      _animateCameraTo(selected);
    } else {
      _pendingLocForMap = selected;
    }
  }

  Future<Set<Marker>> _createMarkers(
    List<ParkingLocation> locations,
    ParkingLocationProvider provider,
  ) async {
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

      final icon = await _markerService.createCustomMarkerBitmap(
        loc.priceRegular.toString(),
        markerColor,
        isOptimal: isOptimal,
      );

      markers.add(
        Marker(
          markerId: MarkerId(loc.id.toString()),
          position: LatLng(loc.latitude, loc.longitude),
          icon: icon,
          anchor: const Offset(0.5, 1.0),
          onTap: () => provider.selectLocation(loc),
        ),
      );
    }

    return markers.toSet();
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
                : FutureBuilder<Set<Marker>>(
                    future: _createMarkers(provider.items, provider),
                    builder: (context, snapshot) {
                      return GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target:
                              cityCenters[effectiveSelectedCity] ??
                              _defaultMapCenter,
                          zoom: 14.0,
                        ),
                        onMapCreated: (c) {
                          _mapController = c;
                          if (_pendingLocForMap != null) {
                            final loc = _pendingLocForMap!;
                            _pendingLocForMap = null;
                            _animateCameraTo(loc);
                          }
                        },
                        markers: snapshot.data ?? {},
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: false,
                      );
                    },
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

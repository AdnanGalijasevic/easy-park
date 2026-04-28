import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:easypark_desktop/models/city_coordinate_model.dart';
import 'package:easypark_desktop/models/parking_location_model.dart';
import 'package:easypark_desktop/providers/parking_location_provider.dart';
import 'package:easypark_desktop/screens/master_screen.dart';
import 'package:easypark_desktop/screens/parking_location_wizard.dart';
import 'package:easypark_desktop/screens/parking_dashboard_screen.dart';
import 'package:easypark_desktop/app_colors.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';
import 'package:easypark_desktop/utils/error_message.dart';

class ParkingLocationsScreen extends StatefulWidget {
  const ParkingLocationsScreen({super.key});

  @override
  State<ParkingLocationsScreen> createState() => _ParkingLocationsScreenState();
}

class _ParkingLocationsScreenState extends State<ParkingLocationsScreen> {
  late ParkingLocationProvider _parkingLocationProvider;

  List<ParkingLocation> _locations = [];
  List<CityCoordinate> _cities = [];
  bool _isLoading = true;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _parkingLocationProvider = ParkingLocationProvider();
    _loadCities();
    _loadLocations();
  }

  Future<void> _loadCities() async {
    try {
      var cities = await _parkingLocationProvider.getCities();
      if (mounted) {
        setState(() {
          _cities = cities;
        });
      }
    } catch (e) {
      debugPrint('Error loading cities: $e');
    }
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoading = true);
    try {
      var result = await _parkingLocationProvider.get(
        filter: _selectedCity != null ? {'city': _selectedCity} : null,
      );
      if (mounted) {
        setState(() {
          _locations = result.result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load parking locations: ${normalizeErrorMessage(e)}',
            ),
          ),
        );
      }
    }
  }

  void _navigateToWizard([ParkingLocation? location]) {
    masterScreenKey.currentState?.navigateTo(
      ParkingLocationWizardScreen(location: location),
    );
  }

  void _navigateToDashboard(ParkingLocation location) {
    masterScreenKey.currentState?.navigateTo(
      ParkingDashboardScreen(location: location),
    );
  }

  Future<void> _confirmDeleteLocation(ParkingLocation location) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete parking location'),
        content: Text(
          'Are you sure you want to delete "${location.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: EasyParkColors.error,
              foregroundColor: EasyParkColors.onAccent,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await _parkingLocationProvider.delete(location.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${location.name}"')),
      );
      _loadLocations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete "${location.name}": ${normalizeErrorMessage(e)}',
          ),
        ),
      );
    }
  }

  Widget _buildPhotoThumb(ParkingLocation loc) {
    if (loc.photo == null || loc.photo!.isEmpty) {
      return const Icon(Icons.image_not_supported, color: EasyParkColors.muted);
    }
    try {
      final bytes = base64Decode(loc.photo!);
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          bytes,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
        ),
      );
    } catch (_) {
      return const Icon(Icons.broken_image, color: EasyParkColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking Locations'),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: EasyParkColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCity,
                hint: const Text(
                  'Filter by City',
                  style: TextStyle(color: EasyParkColors.onAccent),
                ),
                dropdownColor: EasyParkColors.surfaceElevated,
                iconEnabledColor: EasyParkColors.onAccent,
                style: const TextStyle(color: EasyParkColors.onAccent),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'All Cities',
                      style: TextStyle(color: EasyParkColors.onAccent),
                    ),
                  ),
                  ..._cities.map((city) {
                    return DropdownMenuItem(
                      value: city.city,
                      child: Text(
                        city.city,
                        style: const TextStyle(color: EasyParkColors.onAccent),
                      ),
                    );
                  }),
                ],
                onChanged: (val) {
                  setState(() => _selectedCity = val);
                  _loadLocations();
                },
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryYellow,
              foregroundColor: EasyParkColors.onInverseSurface,
            ),
            onPressed: () => _navigateToWizard(),
            icon: const Icon(Icons.add),
            label: const Text('Add New Location'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _locations.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_parking_outlined,
                    size: 72,
                    color: EasyParkColors.onBackgroundMuted,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No parking locations found',
                    style: TextStyle(fontSize: 18, color: EasyParkColors.textSecondary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Click "Add New Location" to get started.',
                    style: TextStyle(color: EasyParkColors.onBackgroundMuted),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        showCheckboxColumn: false,
                        columns: const [
                          DataColumn(label: Text('Photo')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('City')),
                          DataColumn(label: Text('Address')),
                          DataColumn(label: Text('Spots')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _locations.map((loc) {
                          return DataRow(
                            onSelectChanged: (_) => _navigateToDashboard(loc),
                            cells: [
                              DataCell(_buildPhotoThumb(loc)),
                              DataCell(Text(loc.name)),
                              DataCell(Text(loc.city)),
                              DataCell(Text(loc.address)),
                              DataCell(Text('${loc.totalSpots}')),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: loc.isActive
                                        ? EasyParkColors.success.withValues(alpha: 0.2)
                                        : EasyParkColors.error.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    loc.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: loc.isActive
                                          ? EasyParkColors.success
                                          : EasyParkColors.error,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: EasyParkColors.info,
                                      ),
                                      onPressed: () => _navigateToWizard(loc),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.assessment,
                                        color: EasyParkColors.chartTertiary,
                                      ),
                                      onPressed: () =>
                                          _navigateToDashboard(loc),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: EasyParkColors.error,
                                      ),
                                      onPressed: () => _confirmDeleteLocation(loc),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

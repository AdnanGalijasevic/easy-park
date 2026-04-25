import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easypark_desktop/app_colors.dart';
import 'package:easypark_desktop/providers/parking_spot_provider.dart';
import 'package:easypark_desktop/providers/parking_location_provider.dart';
import 'package:easypark_desktop/models/parking_spot_model.dart';
import 'package:easypark_desktop/models/parking_location_model.dart';
import 'package:easypark_desktop/screens/master_screen.dart';
import 'package:easypark_desktop/widgets/pagination_controls.dart';
import 'package:easypark_desktop/widgets/bulk_spot_creator.dart';
import 'package:easypark_desktop/widgets/parking_spot_editor.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';

class ParkingSpotsScreen extends StatefulWidget {
  const ParkingSpotsScreen({super.key});

  @override
  ParkingSpotsScreenState createState() => ParkingSpotsScreenState();
}

class ParkingSpotsScreenState extends State<ParkingSpotsScreen> {
  final ParkingSpotProvider _spotProvider = ParkingSpotProvider();
  final ParkingLocationProvider _locationProvider = ParkingLocationProvider();
  final TextEditingController _ftsController = TextEditingController();
  List<ParkingSpot> _spots = [];
  List<ParkingLocation> _locations = [];
  int? _selectedLocationId;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isLoading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _currentPage = 0;
    _loadLocations();
    _loadSpots();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ftsController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      var searchResult = await _locationProvider.get(page: 0, pageSize: 1000);
      setState(() {
        _locations = searchResult.result;
      });
    } catch (e) {
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

  Future<void> _loadSpots() async {
    setState(() {
      _isLoading = true;
    });

    try {
      var filter = {
        if (_ftsController.text.isNotEmpty) 'FTS': _ftsController.text,
        if (_selectedLocationId != null)
          'ParkingLocationId': _selectedLocationId,
      };

      var searchResult = await _spotProvider.get(
        filter: filter,
        page: _currentPage,
        pageSize: 10,
      );

      setState(() {
        _spots = searchResult.result;
        _isLoading = false;
        _totalPages = (searchResult.count / 10).ceil();
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
      _loadSpots();
    });
  }

  void _goToNextPage() {
    setState(() {
      _currentPage++;
      _loadSpots();
    });
  }

  Future<void> _addBulkSpots(int parkingLocationId) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => BulkSpotCreator(
        parkingLocationId: parkingLocationId,
        onSpotsCreated: (spotType, count) async {
          try {
            for (int i = 1; i <= count; i++) {
              final spot = {
                'parkingLocationId': parkingLocationId,
                'spotNumber': '$spotType-$i',
                'spotType': spotType,
                'isActive': true,
              };
              await _spotProvider.insert(spot);
            }

            if (!mounted) return;
            setState(() {
              _currentPage = 0;
              _isLoading = true;
            });
            await _loadSpots();

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$count parking spots added successfully'),
              ),
            );
          } catch (e) {
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Error'),
                content: Text(e.toString()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Ok'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _addNewSpot() async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return ParkingSpotEditor(
          onSave: (spotData) async {
            try {
              await _spotProvider.insert(spotData);
              if (!mounted) return;
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              setState(() {
                _currentPage = 0;
                _isLoading = true;
              });
              await _loadSpots();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Parking spot added successfully'),
                ),
              );
            } catch (e) {
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Error'),
                  content: Text(e.toString()),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Ok'),
                    ),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<void> _editSpot(ParkingSpot spot) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return ParkingSpotEditor(
          spot: spot,
          onSave: (spotData) async {
            try {
              await _spotProvider.update(spot.id, spotData);
              if (!mounted) return;
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              await _loadSpots();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Parking spot updated successfully'),
                ),
              );
            } catch (e) {
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Error'),
                  content: Text(e.toString()),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Ok'),
                    ),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<void> _deleteSpot(ParkingSpot spot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to delete this parking spot?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _spotProvider.delete(spot.id);
        await _loadSpots();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parking spot deleted successfully')),
        );
      } catch (e) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Ok'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: EasyParkColors.transparent,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: const BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: EasyParkColors.onAccent),
                onPressed: () => masterScreenKey.currentState?.navigateTo(
                  const ParkingSpotsScreen(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Parking Spots',
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
            Row(
              children: [
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _selectedLocationId,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Location',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: AppColors.primaryGray,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All Locations'),
                      ),
                      ..._locations.map((location) {
                        return DropdownMenuItem(
                          value: location.id,
                          child: Text(location.name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedLocationId = value;
                        _currentPage = 0;
                      });
                      _loadSpots();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 200,
                  child: TextFormField(
                    controller: _ftsController,
                    decoration: InputDecoration(
                      labelText: null,
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search, size: 16),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      filled: true,
                      fillColor: AppColors.primaryGray,
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        _loadSpots();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: _addNewSpot,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryYellow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text(
                      'ADD NEW',
                      style: TextStyle(color: EasyParkColors.onInverseSurface),
                    ),
                  ),
                ),
                if (_selectedLocationId != null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      onPressed: () => _addBulkSpots(_selectedLocationId!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'ADD MULTIPLE',
                        style: TextStyle(color: EasyParkColors.onAccent),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
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
                    child: _spots.isEmpty
                        ? const Center(child: Text('No parking spots found.'))
                        : ListView.builder(
                            itemCount: _spots.length,
                            itemBuilder: (context, index) {
                              final spot = _spots[index];
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
                                      Icon(
                                        _getSpotIcon(spot.spotType),
                                        size: 32,
                                        color: _getSpotColor(spot.spotType),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              spot.spotNumber,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              '${spot.parkingLocationName} • ${spot.spotType}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: EasyParkColors.textSecondary,
                                              ),
                                            ),
                                            Text(
                                              spot.isActive
                                                  ? 'Active'
                                                  : 'Inactive',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: spot.isActive
                                                    ? EasyParkColors.success
                                                    : EasyParkColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: EasyParkColors.info,
                                        ),
                                        onPressed: () => _editSpot(spot),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: EasyParkColors.error,
                                        ),
                                        onPressed: () => _deleteSpot(spot),
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

  IconData _getSpotIcon(String spotType) {
    switch (spotType) {
      case 'Disabled':
        return Icons.accessible;
      case 'Electric':
        return Icons.electric_car;
      case 'Covered':
        return Icons.roofing;
      default:
        return Icons.local_parking;
    }
  }

  Color _getSpotColor(String spotType) {
    switch (spotType) {
      case 'Disabled':
        return EasyParkColors.info;
      case 'Electric':
        return EasyParkColors.success;
      case 'Covered':
        return EasyParkColors.accent;
      default:
        return EasyParkColors.accent;
    }
  }
}

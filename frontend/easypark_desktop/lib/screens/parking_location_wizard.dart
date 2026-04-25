import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:easypark_desktop/app_colors.dart';
import 'package:easypark_desktop/models/parking_location_model.dart';
import 'package:easypark_desktop/models/parking_spot_model.dart';
import 'package:easypark_desktop/providers/parking_location_provider.dart';
import 'package:easypark_desktop/providers/parking_spot_provider.dart';
import 'package:easypark_desktop/screens/master_screen.dart';
import 'package:easypark_desktop/screens/parking_locations_screen.dart';
import 'package:easypark_desktop/utils/constants.dart';
import 'package:easypark_desktop/widgets/map_picker.dart';
import 'package:easypark_desktop/widgets/parking_spot_list_item.dart';
import 'package:easypark_desktop/widgets/photo_picker.dart';
import 'package:easypark_desktop/widgets/bulk_spot_creator.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';

class ParkingLocationWizardScreen extends StatefulWidget {
  final ParkingLocation? location;

  const ParkingLocationWizardScreen({super.key, this.location});

  @override
  State<ParkingLocationWizardScreen> createState() =>
      _ParkingLocationWizardScreenState();
}

class _ParkingLocationWizardScreenState
    extends State<ParkingLocationWizardScreen> {
  final ParkingLocationProvider _locationProvider = ParkingLocationProvider();
  final ParkingSpotProvider _spotProvider = ParkingSpotProvider();

  int _currentStep = 0;
  bool _isLoading = false;
  final _formKeyDetails = GlobalKey<FormState>();
  final _formKeyPricing = GlobalKey<FormState>();

  // Step 1: Info & Location
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Replaced controller with selected city string from dropdown
  String? _selectedCity = 'Mostar'; // Default to Mostar
  int? _selectedCityId;

  double _latitude = 43.3438; // Default (Mostar)
  double _longitude = 17.8078;
  List<int>? _selectedPhoto;

  // Step 2: Amenities & Pricing
  bool _hasVideoSurveillance = false;
  bool _hasNightSurveillance = false;
  bool _hasOnlinePayment = false;
  bool _is24Hours = true;
  bool _hasWifi = false;
  bool _hasRestroom = false;
  bool _hasAttendant = false;
  bool _hasSecurityGuard = false;
  bool _hasRamp = false;

  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;

  final TextEditingController _priceRegularController = TextEditingController();
  final TextEditingController _priceDisabledController =
      TextEditingController();
  final TextEditingController _priceElectricController =
      TextEditingController();
  final TextEditingController _priceCoveredController = TextEditingController();

  // Step 3: Spots Management
  int? _createdLocationId; // Set after initial save
  List<ParkingSpot> _spots = [];

  @override
  void initState() {
    super.initState();
    if (widget.location != null) {
      _populateData(widget.location!);
      _createdLocationId = widget.location!.id;
      _loadSpots();
    }
  }

  Future<void> _loadSpots() async {
    if (_createdLocationId == null) return;
    try {
      var result = await _spotProvider.get(
        filter: {'parkingLocationId': _createdLocationId},
      );
      setState(() {
        _spots = result.result;
        _spots.sort((a, b) {
          if (a.nextReservationStart == null &&
              b.nextReservationStart == null) {
            return a.spotNumber.compareTo(b.spotNumber);
          }
          if (a.nextReservationStart == null) return 1;
          if (b.nextReservationStart == null) return -1;
          return a.nextReservationStart!.compareTo(b.nextReservationStart!);
        });
      });
    } catch (e) {
      debugPrint('Error loading spots: $e');
    }
  }

  Future<void> _fetchAddressFromMap(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'EasyParkDesktop/1.0'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['address'] != null) {
          final addressObj = data['address'];
          final road =
              addressObj['road'] ??
              addressObj['pedestrian'] ??
              addressObj['path'] ??
              addressObj['suburb'] ??
              '';
          final houseNumber = addressObj['house_number'] ?? '';
          final city =
              addressObj['city'] ??
              addressObj['town'] ??
              addressObj['village'] ??
              '';

          String newAddress = '$road $houseNumber'.trim();
          if (newAddress.isEmpty) {
            newAddress =
                data['display_name']?.split(',').first ?? 'Unknown Street';
          }

          setState(() {
            _addressController.text = newAddress;
            if (city.isNotEmpty && citiesBiH.contains(city)) {
              _selectedCity = city;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    }
  }

  void _populateData(ParkingLocation loc) {
    _nameController.text = loc.name;
    _descriptionController.text = loc.description ?? '';
    _addressController.text = loc.address;

    // Set selected city. If legacy city not in list, fallback or keep (Dropdown might error if Value not in items)
    if (citiesBiH.contains(loc.city)) {
      _selectedCity = loc.city;
    } else {
      // If city is not in list, we can't show it in Dropdown unless we add it or use a text field.
      // For now, we'll try to default to something or just set it if it happens to be valid.
      // A better approach for legacy data is adding it to list dynamically or alerting.
      // Assuming data is clean or we accept non-matching will reset to Default/Null
      _selectedCity = null;
    }
    _selectedCityId = loc.cityId;

    _latitude = loc.latitude;
    _longitude = loc.longitude;

    if (loc.photo != null) {
      try {
        _selectedPhoto = base64Decode(loc.photo!);
      } catch (_) {}
    }

    _priceRegularController.text = loc.priceRegular.toString();
    _priceDisabledController.text = loc.priceDisabled.toString();
    _priceElectricController.text = loc.priceElectric.toString();
    _priceCoveredController.text = loc.priceCovered.toString();

    _hasVideoSurveillance = loc.hasVideoSurveillance;
    _hasNightSurveillance = loc.hasNightSurveillance;
    _hasOnlinePayment = loc.hasOnlinePayment;
    _is24Hours = loc.is24Hours;
    _hasWifi = loc.hasWifi;
    _hasRestroom = loc.hasRestroom;
    _hasAttendant = loc.hasAttendant;
    _hasSecurityGuard = loc.hasSecurityGuard;
    _hasRamp = loc.hasRamp;
  }

  Future<void> _submitLocation() async {
    if (!_formKeyDetails.currentState!.validate() ||
        !_formKeyPricing.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check all fields in previous steps'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    int? resolvedCityId = _selectedCityId;
    if (resolvedCityId == null && _selectedCity != null) {
      try {
        final cityLookup = await _locationProvider.get(
          filter: {'city': _selectedCity},
          page: 0,
          pageSize: 1,
        );
        if (cityLookup.result.isNotEmpty) {
          resolvedCityId = cityLookup.result.first.cityId;
        }
      } catch (_) {
        // Keep null and let backend validation report clear message.
      }
    }

    final locationData = {
      'name': _nameController.text,
      'description': _descriptionController.text,
      'address': _addressController.text,
      'cityId': resolvedCityId,
      'latitude': _latitude,
      'longitude': _longitude,
      // "totalSpots": 0, // Removed based on backend change
      'pricePerHour':
          double.tryParse(_priceRegularController.text) ??
          0, // Fallback base price
      'priceRegular': double.tryParse(_priceRegularController.text) ?? 0,
      'priceDisabled': double.tryParse(_priceDisabledController.text) ?? 0,
      'priceElectric': double.tryParse(_priceElectricController.text) ?? 0,
      'priceCovered': double.tryParse(_priceCoveredController.text) ?? 0,
      'photo': _selectedPhoto != null ? base64Encode(_selectedPhoto!) : null,

      'hasVideoSurveillance': _hasVideoSurveillance,
      'hasNightSurveillance': _hasNightSurveillance,
      'hasOnlinePayment': _hasOnlinePayment,
      'is24Hours': _is24Hours,
      'hasWifi': _hasWifi,
      'hasRestroom': _hasRestroom,
      'hasAttendant': _hasAttendant,
      'hasSecurityGuard': _hasSecurityGuard,
      'hasRamp': _hasRamp,
      'isActive': true,
      'createdByName': 'Admin',
    };

    try {
      if (_createdLocationId == null) {
        // Create new
        var result = await _locationProvider.insert(locationData);
        _createdLocationId = result.id;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location saved! You can now add spots.'),
            ),
          );
        }
      } else {
        // Update existing
        await _locationProvider.update(_createdLocationId!, locationData);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Location updated!')));
        }
      }

      // Always reload spots when entering Step 3 / updating
      _loadSpots();

      // Move to next step (Spots) if not there
      if (_currentStep < 2) {
        setState(() => _currentStep++);
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addBulkSpots(String spotType, int count) async {
    if (_createdLocationId == null) return;

    setState(() => _isLoading = true);
    try {
      for (int i = 1; i <= count; i++) {
        final spot = {
          'parkingLocationId': _createdLocationId,
          'spotNumber': '$spotType-${DateTime.now().millisecondsSinceEpoch}-$i',
          'spotType': spotType,
          'isActive': true,
        };
        await _spotProvider.insert(spot);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count $spotType spots added!')),
      );
      _loadSpots();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.location == null
              ? 'New Parking Location'
              : 'Edit Parking Location',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => masterScreenKey.currentState?.navigateTo(
            const ParkingLocationsScreen(),
          ),
        ),
      ),
      body: Stack(
        children: [
          Stepper(
            type: StepperType.horizontal,
            currentStep: _currentStep,
            onStepTapped: (index) {
              if (_createdLocationId != null || index < _currentStep) {
                setState(() => _currentStep = index);
              }
            },
            onStepContinue: () {
              if (_currentStep < 2) {
                if (_currentStep == 1) {
                  _submitLocation();
                } else {
                  setState(() => _currentStep++);
                }
              } else {
                masterScreenKey.currentState?.navigateTo(
                  const ParkingLocationsScreen(),
                );
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep--);
              }
            },
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: EasyParkColors.onAccent,
                      ),
                      child: Text(
                        _currentStep == 2
                            ? 'FINISH'
                            : (_currentStep == 1 ? 'SAVE & NEXT' : 'NEXT'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_currentStep > 0)
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('BACK'),
                      ),
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('Info & Location'),
                isActive: _currentStep >= 0,
                state: _currentStep > 0
                    ? StepState.complete
                    : StepState.editing,
                content: _buildInfoStep(),
              ),
              Step(
                title: const Text('Amenities & Pricing'),
                isActive: _currentStep >= 1,
                state: _currentStep > 1
                    ? StepState.complete
                    : StepState.editing,
                content: _buildAmenitiesStep(),
              ),
              Step(
                title: const Text('Spots'),
                isActive: _currentStep >= 2,
                content: _buildSpotsStep(),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: EasyParkColors.scrim,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoStep() {
    return Form(
      key: _formKeyDetails,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left col: Fields
          Expanded(
            flex: 1,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Parking Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCity,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                  ),
                  items: citiesBiH.map((city) {
                    return DropdownMenuItem(value: city, child: Text(city));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCity = val),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Address (Auto-selected from Map)',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  validator: (v) =>
                      v!.isEmpty ? 'Select a location on the map' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                PhotoPicker(
                  initialPhoto: _selectedPhoto,
                  onPhotoSelected: (bytes) =>
                      setState(() => _selectedPhoto = bytes),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Right col: Map
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Location on Map (doubleclick to set location):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                MapPicker(
                  initialLatitude: _latitude,
                  initialLongitude: _longitude,
                  onLocationSelected: (lat, lng) {
                    setState(() {
                      _latitude = lat;
                      _longitude = lng;
                    });
                    _fetchAddressFromMap(lat, lng);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenitiesStep() {
    return Form(
      key: _formKeyPricing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operating Hours',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  var t = await showTimePicker(
                    context: context,
                    initialTime:
                        _openTime ?? const TimeOfDay(hour: 6, minute: 0),
                  );
                  if (t != null) setState(() => _openTime = t);
                },
                child: Text(
                  _openTime == null
                      ? 'Set Open Time'
                      : 'Open: ${_openTime!.format(context)}',
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () async {
                  var t = await showTimePicker(
                    context: context,
                    initialTime:
                        _closeTime ?? const TimeOfDay(hour: 22, minute: 0),
                  );
                  if (t != null) setState(() => _closeTime = t);
                },
                child: Text(
                  _closeTime == null
                      ? 'Set Close Time'
                      : 'Close: ${_closeTime!.format(context)}',
                ),
              ),
              const SizedBox(width: 16),
              Checkbox(
                value: _is24Hours,
                onChanged: (v) => setState(() => _is24Hours = v!),
              ),
              const Text('Open 24 Hours'),
            ],
          ),
          const Divider(height: 32),

          const Text(
            'Pricing (per hour)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPriceInput(_priceRegularController, 'Regular'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPriceInput(_priceDisabledController, 'Disabled'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPriceInput(_priceElectricController, 'Electric'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPriceInput(_priceCoveredController, 'Covered'),
              ),
            ],
          ),
          const Divider(height: 32),

          const Text(
            'Amenities & Features',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              _buildSwitch(
                'Video Surv.',
                _hasVideoSurveillance,
                (v) => _hasVideoSurveillance = v,
              ),
              _buildSwitch(
                'Night Surv.',
                _hasNightSurveillance,
                (v) => _hasNightSurveillance = v,
              ),
              _buildSwitch(
                'Security Guard',
                _hasSecurityGuard,
                (v) => _hasSecurityGuard = v,
              ),
              _buildSwitch('Ramp', _hasRamp, (v) => _hasRamp = v),
              _buildSwitch(
                'Online Payment',
                _hasOnlinePayment,
                (v) => _hasOnlinePayment = v,
              ),
              _buildSwitch('WiFi', _hasWifi, (v) => _hasWifi = v),
              _buildSwitch('Restroom', _hasRestroom, (v) => _hasRestroom = v),
              _buildSwitch(
                'Attendant',
                _hasAttendant,
                (v) => _hasAttendant = v,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(String label, bool value, Function(bool) onChanged) {
    return SizedBox(
      width: 200,
      child: Row(
        children: [
          Switch(value: value, onChanged: (v) => setState(() => onChanged(v))),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildPriceInput(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: '$label Price',
        border: const OutlineInputBorder(),
        prefixText: '\$',
      ),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }

  Future<void> _deleteSpot(int id) async {
    try {
      await _spotProvider.delete(id);
      _loadSpots();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spot deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting spot: $e')),
      );
    }
  }

  Future<void> _toggleSpotActive(ParkingSpot spot) async {
    try {
      final updatedSpot = {
        'parkingLocationId': spot.parkingLocationId,
        'spotNumber': spot.spotNumber,
        'spotType': spot.spotType,
        'isActive': !spot.isActive,
        'isOccupied': spot.isOccupied,
      };
      await _spotProvider.update(spot.id, updatedSpot);
      _loadSpots();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating spot: $e')),
      );
    }
  }

  Widget _buildSpotsStep() {
    if (_createdLocationId == null) {
      return const Center(
        child: Text('Please save the location first to manage spots.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bulk Add Spots',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        BulkSpotCreator(
          parkingLocationId: _createdLocationId!,
          onSpotsCreated: (type, count) => _addBulkSpots(type, count),
        ),
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Existing Spots',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadSpots,
              tooltip: 'Refresh Spots',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _spots.isEmpty
            ? const Center(child: Text('No spots added yet.'))
            : DefaultTabController(
                length: 5,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 650),
                  decoration: BoxDecoration(
                    border: Border.all(color: EasyParkColors.borderLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const TabBar(
                        labelColor: EasyParkColors.onInverseSurface,
                        unselectedLabelColor: EasyParkColors.muted,
                        indicatorColor: EasyParkColors.accent,
                        tabs: [
                          Tab(text: 'All'),
                          Tab(text: 'Regular'),
                          Tab(text: 'Disabled'),
                          Tab(text: 'Electric'),
                          Tab(text: 'Covered'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildSpotsList(_spots),
                            _buildSpotsList(
                              _spots
                                  .where((s) => s.spotType == 'Regular')
                                  .toList(),
                            ),
                            _buildSpotsList(
                              _spots
                                  .where((s) => s.spotType == 'Disabled')
                                  .toList(),
                            ),
                            _buildSpotsList(
                              _spots
                                  .where((s) => s.spotType == 'Electric')
                                  .toList(),
                            ),
                            _buildSpotsList(
                              _spots
                                  .where((s) => s.spotType == 'Covered')
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildSpotsList(List<ParkingSpot> spots) {
    if (spots.isEmpty) {
      return const Center(child: Text('No spots found for this category.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: spots.length,
      itemBuilder: (context, index) {
        final spot = spots[index];
        return ParkingSpotListItem(
          spot: spot,
          onToggleActive: (val) => _toggleSpotActive(spot),
          onDelete: () => showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Spot'),
              content: const Text('Are you sure you want to delete this spot?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteSpot(spot.id);
                  },
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: EasyParkColors.error),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

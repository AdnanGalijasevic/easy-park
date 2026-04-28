import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:easypark_desktop/app_colors.dart';
import 'package:easypark_desktop/models/city_coordinate_model.dart';
import 'package:easypark_desktop/models/parking_location_model.dart';
import 'package:easypark_desktop/models/parking_spot_model.dart';
import 'package:easypark_desktop/providers/parking_location_provider.dart';
import 'package:easypark_desktop/providers/parking_spot_provider.dart';
import 'package:easypark_desktop/screens/master_screen.dart';
import 'package:easypark_desktop/screens/parking_locations_screen.dart';
import 'package:easypark_desktop/widgets/map_picker.dart';
import 'package:easypark_desktop/widgets/parking_spot_list_item.dart';
import 'package:easypark_desktop/widgets/photo_picker.dart';
import 'package:easypark_desktop/widgets/bulk_spot_creator.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';
import 'package:easypark_desktop/utils/error_message.dart';

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
  List<CityCoordinate> _cities = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  String? _selectedCity = 'Mostar';
  int? _selectedCityId;

  double _latitude = 43.3438;
  double _longitude = 17.8078;
  List<int>? _selectedPhoto;

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

  int? _createdLocationId;
  List<ParkingSpot> _spots = [];

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: EasyParkColors.error, content: Text(message)),
    );
  }

  double _parsePriceOrFallback(
    TextEditingController controller, {
    required double fallback,
  }) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return fallback;
    return double.tryParse(raw) ?? fallback;
  }

  @override
  void initState() {
    super.initState();
    _loadCities();
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

  Future<void> _loadCities() async {
    try {
      var cities = await _locationProvider.getCities();
      if (mounted) {
        setState(() {
          _cities = cities;
          _syncSelectedCityForEdit();
        });
      }
    } catch (e) {
      debugPrint('Error loading cities: $e');
    }
  }

  void _syncSelectedCityForEdit() {
    final location = widget.location;
    if (location == null || _cities.isEmpty) return;

    final byId = _cities.where((c) => c.city == location.city).toList();
    if (byId.isNotEmpty) {
      _selectedCity = byId.first.city;
      _selectedCityId = location.cityId;
      return;
    }

    final normalizedLocationCity = location.city.trim().toLowerCase();
    final byName = _cities.where(
      (c) => c.city.trim().toLowerCase() == normalizedLocationCity,
    );
    if (byName.isNotEmpty) {
      _selectedCity = byName.first.city;
      _selectedCityId = location.cityId;
      return;
    }

    _selectedCity = null;
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

          if (mounted) {
            setState(() {
              _addressController.text = newAddress;
              if (city.isNotEmpty && _cities.any((c) => c.city == city)) {
                _selectedCity = city;
              }
            });
          }
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

    if (_cities.any((c) => c.city == loc.city)) {
      _selectedCity = loc.city;
    } else {
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

    final operating = loc.operatingHours?.trim();
    if (operating != null && operating.contains('-')) {
      final parts = operating.split('-');
      if (parts.length == 2) {
        _openTime = _parseTime(parts[0].trim());
        _closeTime = _parseTime(parts[1].trim());
      }
    }

    _sync24HoursFromTimes();
  }

  Future<void> _submitLocation() async {
    if (!_formKeyDetails.currentState!.validate() ||
        !_formKeyPricing.currentState!.validate()) {
      _showError(
        'Please fix highlighted fields before saving location details.',
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
      } catch (_) {}
    }

    final regularPrice = _parsePriceOrFallback(
      _priceRegularController,
      fallback: 0,
    );

    if (!_is24Hours && (_openTime == null || _closeTime == null)) {
      setState(() => _isLoading = false);
      _showError('Set both open and close time, or enable 24-hour mode.');
      return;
    }

    final locationData = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'address': _addressController.text.trim(),
      'cityId': resolvedCityId,
      'latitude': _latitude,
      'longitude': _longitude,
      'pricePerHour': regularPrice,
      'priceRegular': regularPrice,
      'priceDisabled': _parsePriceOrFallback(
        _priceDisabledController,
        fallback: regularPrice,
      ),
      'priceElectric': _parsePriceOrFallback(
        _priceElectricController,
        fallback: regularPrice,
      ),
      'priceCovered': _parsePriceOrFallback(
        _priceCoveredController,
        fallback: regularPrice,
      ),
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
      'operatingHours': _is24Hours
          ? null
          : '${_formatTime(_openTime!)}-${_formatTime(_closeTime!)}',
    };

    try {
      if (_createdLocationId == null) {
        var result = await _locationProvider.insert(locationData);
        _createdLocationId = result.id;

        _showSuccess('Location saved. You can now add parking spots.');
      } else {
        await _locationProvider.update(_createdLocationId!, locationData);
        _showSuccess('Location updated successfully.');
      }

      _loadSpots();

      if (_currentStep < 2) {
        setState(() => _currentStep++);
      }
    } catch (e) {
      _showError('Failed to save location: ${normalizeErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  TimeOfDay? _parseTime(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  bool get _hasDefinedOperatingWindow => _openTime != null && _closeTime != null;

  void _sync24HoursFromTimes() {
    _is24Hours = !_hasDefinedOperatingWindow;
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
      _showSuccess('$count $spotType spots added.');
      _loadSpots();
    } catch (e) {
      _showError('Failed to create spots: ${normalizeErrorMessage(e)}');
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
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Parking name is required.';
                    }
                    if (v.trim().length < 3) {
                      return 'Parking name must have at least 3 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedCity ?? 'city-none'),
                  initialValue: _selectedCity,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                  ),
                  items: _cities.map((city) {
                    return DropdownMenuItem(
                      value: city.city,
                      child: Text(city.city),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCity = val;
                      final cityObj = _cities.firstWhere(
                        (c) => c.city == val,
                        orElse: () => CityCoordinate(
                          city: '',
                          latitude: _latitude,
                          longitude: _longitude,
                        ),
                      );
                      _selectedCityId = val == null ? null : _resolveCityId(val);
                      if (cityObj.city.isNotEmpty) {
                        _latitude = cityObj.latitude;
                        _longitude = cityObj.longitude;
                      }
                    });
                  },
                  validator: (v) => v == null || v.isEmpty
                      ? 'City selection is required.'
                      : null,
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
                  if (t != null) {
                    setState(() {
                      _openTime = t;
                      _sync24HoursFromTimes();
                    });
                  }
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
                  if (t != null) {
                    setState(() {
                      _closeTime = t;
                      _sync24HoursFromTimes();
                    });
                  }
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
                onChanged: _hasDefinedOperatingWindow
                    ? null
                    : (v) => setState(() => _is24Hours = v ?? true),
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
    final isRegular = label == 'Regular';
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: '$label Price',
        border: const OutlineInputBorder(),
        prefixText: '\$',
      ),
      validator: (v) {
        final raw = v?.trim() ?? '';
        if (raw.isEmpty) {
          return isRegular ? '$label price is required.' : null;
        }
        final parsed = double.tryParse(raw);
        if (parsed == null) return 'Enter valid number for $label price.';
        if (parsed < 0) return '$label price cannot be negative.';
        return null;
      },
    );
  }

  int? _resolveCityId(String cityName) {
    if (widget.location != null &&
        widget.location!.city.trim().toLowerCase() ==
            cityName.trim().toLowerCase()) {
      return widget.location!.cityId;
    }
    return null;
  }

  Future<void> _deleteSpot(int id) async {
    try {
      await _spotProvider.delete(id);
      _loadSpots();
      _showSuccess('Spot deleted successfully.');
    } catch (e) {
      _showError('Failed to delete spot: ${normalizeErrorMessage(e)}');
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
      _showError('Failed to update spot status: ${normalizeErrorMessage(e)}');
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

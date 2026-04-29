import 'package:flutter/material.dart';
import 'package:easypark_desktop/models/parking_location_model.dart';
import 'package:easypark_desktop/widgets/map_picker.dart';

class ParkingLocationEditor extends StatefulWidget {
  final ParkingLocation? location;
  final Function(Map<String, dynamic> locationData) onSave;

  const ParkingLocationEditor({super.key, this.location, required this.onSave});

  @override
  State<ParkingLocationEditor> createState() => _ParkingLocationEditorState();
}

class _ParkingLocationEditorState extends State<ParkingLocationEditor> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _postalCodeController;
  late TextEditingController _descriptionController;
  late TextEditingController _pricePerHourController;
  late TextEditingController _pricePerDayController;
  late TextEditingController _operatingHoursController;

  late double _selectedLatitude;
  late double _selectedLongitude;

  bool _hasVideoSurveillance = false;
  bool _hasNightSurveillance = false;
  bool _hasDisabledSpots = false;
  bool _hasRamp = false;
  bool _is24Hours = false;
  bool _hasElectricCharging = false;
  bool _hasCoveredSpots = false;
  bool _hasSecurityGuard = false;
  bool _hasWifi = false;
  bool _hasRestroom = false;

  String? _parkingType;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final location = widget.location;
    _nameController = TextEditingController(text: location?.name);
    _addressController = TextEditingController(text: location?.address);
    _cityController = TextEditingController(text: location?.city);
    _postalCodeController = TextEditingController(text: location?.postalCode);
    _descriptionController = TextEditingController(text: location?.description);
    _pricePerHourController = TextEditingController(
      text: location?.pricePerHour.toString(),
    );
    _pricePerDayController = TextEditingController(
      text: location?.pricePerDay?.toString(),
    );
    _operatingHoursController = TextEditingController(
      text: location?.operatingHours,
    );

    _selectedLatitude = location?.latitude ?? 43.8563;
    _selectedLongitude = location?.longitude ?? 18.4131;

    if (location != null) {
      _hasVideoSurveillance = location.hasVideoSurveillance;
      _hasNightSurveillance = location.hasNightSurveillance;
      _hasDisabledSpots = location.hasDisabledSpots;
      _hasRamp = location.hasRamp;
      _is24Hours = location.is24Hours;
      _hasElectricCharging = location.hasElectricCharging;
      _hasCoveredSpots = location.hasCoveredSpots;
      _hasSecurityGuard = location.hasSecurityGuard;
      _hasWifi = location.hasWifi;
      _hasRestroom = location.hasRestroom;
      _parkingType = location.parkingType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _descriptionController.dispose();
    _pricePerHourController.dispose();
    _pricePerDayController.dispose();
    _operatingHoursController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final locationData = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'postalCode': _postalCodeController.text.trim().isEmpty
            ? null
            : _postalCodeController.text.trim(),
        'latitude': _selectedLatitude,
        'longitude': _selectedLongitude,
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'pricePerHour': double.parse(_pricePerHourController.text),
        'pricePerDay': _pricePerDayController.text.trim().isEmpty
            ? null
            : double.parse(_pricePerDayController.text),
        'hasVideoSurveillance': _hasVideoSurveillance,
        'hasNightSurveillance': _hasNightSurveillance,
        'hasDisabledSpots': _hasDisabledSpots,
        'hasRamp': _hasRamp,
        'is24Hours': _is24Hours,
        'hasElectricCharging': _hasElectricCharging,
        'hasCoveredSpots': _hasCoveredSpots,
        'hasSecurityGuard': _hasSecurityGuard,
        'hasWifi': _hasWifi,
        'hasRestroom': _hasRestroom,
        'parkingType': _parkingType,
        'operatingHours': _operatingHoursController.text.trim().isEmpty
            ? null
            : _operatingHoursController.text.trim(),
      };

      await widget.onSave(locationData);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.location == null
            ? 'Add New Parking Location'
            : 'Edit Parking Location',
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 600,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final raw = value?.trim() ?? '';
                    if (raw.isEmpty) return 'Location name is required.';
                    if (raw.length < 2) {
                      return 'Location name must be at least 2 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final raw = value?.trim() ?? '';
                    if (raw.isEmpty) return 'Address is required.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'City *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final raw = value?.trim() ?? '';
                          if (raw.isEmpty) return 'City is required.';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _postalCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Postal Code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pricePerHourController,
                        decoration: const InputDecoration(
                          labelText: 'Price Per Hour (BAM) *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final raw = value?.trim() ?? '';
                          if (raw.isEmpty) return 'Hourly price is required.';
                          final parsed = double.tryParse(raw);
                          if (parsed == null) {
                            return 'Enter a valid hourly price.';
                          }
                          if (parsed < 0) {
                            return 'Hourly price cannot be negative.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _pricePerDayController,
                        decoration: const InputDecoration(
                          labelText: 'Price Per Day (BAM)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Location on Map:'),
                const SizedBox(height: 8),
                MapPicker(
                  initialLatitude: _selectedLatitude,
                  initialLongitude: _selectedLongitude,
                  onLocationSelected: (lat, lng) {
                    _selectedLatitude = lat;
                    _selectedLongitude = lng;
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Features:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildFeatureChip(
                      'Video Surveillance',
                      _hasVideoSurveillance,
                      (v) => setState(() => _hasVideoSurveillance = v),
                    ),
                    _buildFeatureChip(
                      'Night Surveillance',
                      _hasNightSurveillance,
                      (v) => setState(() => _hasNightSurveillance = v),
                    ),
                    _buildFeatureChip(
                      'Disabled Spots',
                      _hasDisabledSpots,
                      (v) => setState(() => _hasDisabledSpots = v),
                    ),
                    _buildFeatureChip(
                      'Ramp',
                      _hasRamp,
                      (v) => setState(() => _hasRamp = v),
                    ),
                    _buildFeatureChip(
                      '24 Hours',
                      _is24Hours,
                      (v) => setState(() => _is24Hours = v),
                    ),
                    _buildFeatureChip(
                      'Electric Charging',
                      _hasElectricCharging,
                      (v) => setState(() => _hasElectricCharging = v),
                    ),
                    _buildFeatureChip(
                      'Covered Spots',
                      _hasCoveredSpots,
                      (v) => setState(() => _hasCoveredSpots = v),
                    ),
                    _buildFeatureChip(
                      'Security Guard',
                      _hasSecurityGuard,
                      (v) => setState(() => _hasSecurityGuard = v),
                    ),
                    _buildFeatureChip(
                      'WiFi',
                      _hasWifi,
                      (v) => setState(() => _hasWifi = v),
                    ),
                    _buildFeatureChip(
                      'Restroom',
                      _hasRestroom,
                      (v) => setState(() => _hasRestroom = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _parkingType,
                  decoration: const InputDecoration(
                    labelText: 'Parking Type',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Underground', 'Surface', 'Multi-level'].map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _parkingType = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _operatingHoursController,
                  decoration: const InputDecoration(
                    labelText: 'Operating Hours (e.g., 08:00-22:00)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.location == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }

  Widget _buildFeatureChip(
    String label,
    bool selected,
    Function(bool) onSelected,
  ) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
    );
  }
}

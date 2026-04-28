import 'package:flutter/material.dart';
import 'package:easypark_desktop/models/parking_spot_model.dart';
import 'package:easypark_desktop/models/parking_location_model.dart';
import 'package:easypark_desktop/providers/parking_location_provider.dart';
import 'package:easypark_desktop/utils/utils.dart';

class ParkingSpotEditor extends StatefulWidget {
  final ParkingSpot? spot;
  final Function(Map<String, dynamic> spotData) onSave;

  const ParkingSpotEditor({super.key, this.spot, required this.onSave});

  @override
  State<ParkingSpotEditor> createState() => _ParkingSpotEditorState();
}

class _ParkingSpotEditorState extends State<ParkingSpotEditor> {
  final _formKey = GlobalKey<FormState>();
  final ParkingLocationProvider _locationProvider = ParkingLocationProvider();

  late TextEditingController _spotNumberController;
  int? _selectedLocationId;
  String _selectedSpotType = 'Regular';
  bool _isActive = true;

  List<ParkingLocation> _locations = [];
  bool _isLoadingLocations = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadLocations();
  }

  void _initializeControllers() {
    final spot = widget.spot;
    _spotNumberController = TextEditingController(text: spot?.spotNumber);

    if (spot != null) {
      _selectedSpotType = spot.spotType;
      _isActive = spot.isActive;
    }
  }

  Future<void> _loadLocations() async {
    try {
      var searchResult = await _locationProvider.get(page: 0, pageSize: 1000);
      if (mounted) {
        setState(() {
          _locations = searchResult.result;
          _isLoadingLocations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocations = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _spotNumberController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.spot == null && _selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a parking location before saving the spot.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final spotData = {
        if (widget.spot == null) 'parkingLocationId': _selectedLocationId,
        'spotNumber': _spotNumberController.text.trim(),
        'spotType': _selectedSpotType,
        'isActive': _isActive,
      };

      await widget.onSave(spotData);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.spot == null ? 'Add New Parking Spot' : 'Edit Parking Spot',
      ),
      content: SizedBox(
        width: 400,
        child: _isLoadingLocations && widget.spot == null
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.spot == null) ...[
                      DropdownButtonFormField<int>(
                        initialValue: _selectedLocationId,
                        decoration: const InputDecoration(
                          labelText: 'Parking Location *',
                          border: OutlineInputBorder(),
                        ),
                        items: _locations.map((location) {
                          return DropdownMenuItem(
                            value: location.id,
                            child: Text(location.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedLocationId = value;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Parking location is required.' : null,
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      Text(
                        'Location: ${widget.spot?.parkingLocationName ?? 'Unknown'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _spotNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Spot Number *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          inputRequired(value, 'Spot number is required.'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSpotType,
                      decoration: const InputDecoration(
                        labelText: 'Spot Type *',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Regular', 'Disabled', 'Electric', 'Covered'].map(
                        (type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        },
                      ).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedSpotType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('Active'),
                      value: _isActive,
                      onChanged: (value) {
                        setState(() {
                          _isActive = value ?? true;
                        });
                      },
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.spot == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPicker extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final Function(double latitude, double longitude) onLocationSelected;

  const MapPicker({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.onLocationSelected,
  });

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  late LatLng _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(widget.initialLatitude, widget.initialLongitude);
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
    widget.onLocationSelected(location.latitude, location.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _selectedLocation,
          zoom: 15,
        ),
        onMapCreated: (_) {},
        onTap: _onMapTap,
        markers: {
          Marker(
            markerId: const MarkerId('selected_location'),
            position: _selectedLocation,
            draggable: true,
            onDragEnd: (LatLng newPosition) {
              setState(() {
                _selectedLocation = newPosition;
              });
              widget.onLocationSelected(
                newPosition.latitude,
                newPosition.longitude,
              );
            },
          ),
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(widget.initialLatitude, widget.initialLongitude);
  }

  @override
  void didUpdateWidget(MapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialLatitude != widget.initialLatitude ||
        oldWidget.initialLongitude != widget.initialLongitude) {
      _selectedLocation = LatLng(widget.initialLatitude, widget.initialLongitude);
      _mapController.move(_selectedLocation, 15.0);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
    widget.onLocationSelected(location.latitude, location.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _selectedLocation,
          initialZoom: 15.0,
          onTap: _onMapTap,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.easypark.desktop',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _selectedLocation,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

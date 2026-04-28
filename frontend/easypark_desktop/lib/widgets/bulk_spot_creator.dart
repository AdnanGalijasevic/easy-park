import 'package:flutter/material.dart';
import 'package:easypark_desktop/utils/utils.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';

class BulkSpotCreator extends StatefulWidget {
  final int parkingLocationId;
  final Function(String spotType, int count) onSpotsCreated;

  const BulkSpotCreator({
    super.key,
    required this.parkingLocationId,
    required this.onSpotsCreated,
  });

  @override
  State<BulkSpotCreator> createState() => _BulkSpotCreatorState();
}

class _BulkSpotCreatorState extends State<BulkSpotCreator> {
  final TextEditingController _countController = TextEditingController(
    text: '1',
  );
  String _selectedSpotType = 'Regular';
  String? _countError;

  final List<String> _spotTypes = [
    'Regular',
    'Disabled',
    'Electric',
    'Covered',
  ];

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  void _createSpots() {
    final countValidation =
        inputRequired(_countController.text) ??
        onlyNumbers(_countController.text) ??
        positiveNumber(_countController.text);

    setState(() {
      _countError = countValidation;
    });

    if (_countError != null) return;

    final count = int.parse(_countController.text);
    if (count <= 0 || count > 100) {
      setState(() {
        _countError = 'Count must be between 1 and 100.';
      });
      return;
    }

    widget.onSpotsCreated(_selectedSpotType, count);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Multiple Parking Spots',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Spot Type:'),
            DropdownButtonFormField<String>(
              initialValue: _selectedSpotType,
              items: _spotTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSpotType = value!;
                });
              },
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _countController,
              decoration: InputDecoration(
                labelText: 'Number of Spots',
                hintText: 'Enter number (1-100)',
                errorText: _countError,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                if (_countError != null) {
                  setState(() {
                    _countError = null;
                  });
                }
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _createSpots,
                  icon: const Icon(Icons.add_circle),
                  label: const Text('Add Spots'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EasyParkColors.info,
                    foregroundColor: EasyParkColors.onAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

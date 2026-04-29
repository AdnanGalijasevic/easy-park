import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easypark_mobile/providers/parking_location_provider.dart';
import 'package:easypark_mobile/theme/easy_park_colors.dart';

class _FilterOption {
  const _FilterOption(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}

const _filterOptions = [
  _FilterOption(
    ParkingLocationSearchKeys.hasVideoSurveillance,
    'Video surveillance',
    Icons.videocam_outlined,
  ),
  _FilterOption(
    ParkingLocationSearchKeys.hasNightSurveillance,
    'Night surveillance',
    Icons.nightlight_outlined,
  ),
  _FilterOption(
    ParkingLocationSearchKeys.hasSecurityGuard,
    'Security guard',
    Icons.security,
  ),
  _FilterOption(
    ParkingLocationSearchKeys.hasRamp,
    'Ramp',
    Icons.accessible_forward,
  ),
  _FilterOption(
    ParkingLocationSearchKeys.hasWifi,
    'Wi‑Fi',
    Icons.wifi,
  ),
  _FilterOption(
    ParkingLocationSearchKeys.hasRestroom,
    'Restroom',
    Icons.wc_outlined,
  ),
  _FilterOption(
    ParkingLocationSearchKeys.hasDisabledSpots,
    'Disabled spots',
    Icons.accessible,
  ),
  _FilterOption(
    ParkingLocationSearchKeys.is24Hours,
    'Open 24h',
    Icons.schedule,
  ),
  _FilterOption(
    ParkingLocationSearchKeys.hasElectricCharging,
    'EV charging',
    Icons.ev_station_outlined,
  ),
  _FilterOption(
    ParkingLocationSearchKeys.hasCoveredSpots,
    'Covered spots',
    Icons.roofing_outlined,
  ),
];

/// Compact filter control: icon row + expandable checkbox list (no online payment / attendant).
class ParkingLocationFiltersBar extends StatefulWidget {
  const ParkingLocationFiltersBar({super.key});

  @override
  State<ParkingLocationFiltersBar> createState() =>
      _ParkingLocationFiltersBarState();
}

class _ParkingLocationFiltersBarState extends State<ParkingLocationFiltersBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ParkingLocationProvider>(
      builder: (context, parking, _) {
        final n = parking.activeLocationFilterCount;
        final busy = parking.isLoading;

        return Material(
          color: EasyParkColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Badge(
                        isLabelVisible: n > 0,
                        label: Text('$n',
                            style: const TextStyle(fontSize: 10)),
                        child: Icon(
                          Icons.tune,
                          color: n > 0
                              ? EasyParkColors.accent
                              : EasyParkColors.onBackgroundMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _expanded
                              ? 'Amenities & features'
                              : 'Filter parking locations',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: n > 0
                                ? EasyParkColors.onBackground
                                : EasyParkColors.textSecondary,
                          ),
                        ),
                      ),
                      if (n > 0 && !busy)
                        TextButton(
                          onPressed: parking.clearLocationFilters,
                          child: const Text('Clear'),
                        ),
                      Icon(
                        _expanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: EasyParkColors.onBackgroundMuted,
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      // Keep panel compact and prevent bottom overflow on small devices.
                      maxHeight: MediaQuery.of(context).size.height * 0.34,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: _filterOptions.map((opt) {
                          final on = parking.hasLocationFilter(opt.key);
                          return CheckboxTheme(
                            data: CheckboxThemeData(
                              fillColor: WidgetStateProperty.resolveWith((s) {
                                if (s.contains(WidgetState.selected)) {
                                  return EasyParkColors.accent;
                                }
                                return null;
                              }),
                            ),
                            child: CheckboxListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              secondary: Icon(opt.icon, size: 22),
                              title: Text(
                                opt.label,
                                style: const TextStyle(fontSize: 14),
                              ),
                              value: on,
                              onChanged: busy
                                  ? null
                                  : (v) {
                                      parking.setLocationFilter(
                                        opt.key,
                                        v ?? false,
                                      );
                                    },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        );
      },
    );
  }
}

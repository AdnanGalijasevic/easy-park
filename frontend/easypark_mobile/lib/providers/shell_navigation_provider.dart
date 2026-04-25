import 'package:flutter/foundation.dart';

/// Drives bottom tab index and "open Home + focus parking" from other tabs (e.g. Bookmarks).
class ShellNavigationProvider extends ChangeNotifier {
  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;

  int? _pendingParkingLocationIdToFocus;
  int? get pendingParkingLocationIdToFocus => _pendingParkingLocationIdToFocus;

  void setTab(int index) {
    if (index < 0 || index > 4) return;
    if (_currentTabIndex == index) return;
    _currentTabIndex = index;
    notifyListeners();
  }

  /// Switches to Home (index 0) and requests focus on this parking location once data is ready.
  void goToHomeAndFocusParking(int parkingLocationId) {
    _pendingParkingLocationIdToFocus = parkingLocationId;
    _currentTabIndex = 0;
    notifyListeners();
  }

  void clearPendingMapFocus() {
    if (_pendingParkingLocationIdToFocus == null) return;
    _pendingParkingLocationIdToFocus = null;
    notifyListeners();
  }
}

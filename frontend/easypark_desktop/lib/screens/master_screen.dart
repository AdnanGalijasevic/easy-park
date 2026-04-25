import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:easypark_desktop/models/menu_model.dart';
import 'package:easypark_desktop/providers/auth_provider.dart';
import 'package:easypark_desktop/providers/base_provider.dart';
import 'package:easypark_desktop/screens/parking_locations_screen.dart';
import 'package:easypark_desktop/screens/reservation_history_screen.dart';
import 'package:easypark_desktop/screens/reviews_screen.dart';
import 'package:easypark_desktop/screens/users_screen.dart';
import 'package:easypark_desktop/screens/report_screen.dart';
import 'package:easypark_desktop/main.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';

final GlobalKey<MasterScreenState> masterScreenKey =
    GlobalKey<MasterScreenState>();

class MasterScreen extends StatefulWidget {
  const MasterScreen({super.key});

  @override
  State<MasterScreen> createState() => MasterScreenState();
}

final List<DrawerItem> drawerItems = [
  DrawerItem(
    title: 'Parking Locations',
    screen: const ParkingLocationsScreen(),
  ),
  DrawerItem(
    title: 'Reservation History',
    screen: const ReservationHistoryScreen(),
  ),
  DrawerItem(title: 'Reviews', screen: const ReviewsScreen()),
  DrawerItem(title: 'Users', screen: const UsersScreen()),
  DrawerItem(title: 'Reports', screen: const ReportScreen()),
];

class MasterScreenState extends State<MasterScreen> {
  Widget _selectedScreen = const ParkingLocationsScreen();
  int _selectedIndex = 0;
  DateTime _lastChange = DateTime.fromMillisecondsSinceEpoch(0);

  void _changeScreen(int index) {
    final now = DateTime.now();
    if (now.difference(_lastChange) < const Duration(seconds: 1)) return;

    _lastChange = now;

    setState(() {
      _selectedIndex = index;
      _selectedScreen = drawerItems[index].screen;
    });
    Navigator.pop(context);
  }

  void navigateTo(Widget screen) {
    setState(() {
      _selectedIndex = -1;
      _selectedScreen = screen;
    });
  }

  Future<void> _logout() async {
    final accessToken = AuthProvider.accessToken;
    final refreshToken = AuthProvider.refreshToken;
    if (accessToken != null) {
      final uri = Uri.parse('${BaseProvider.baseUrl}User/logout');
      await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Client-Type': 'desktop',
        },
        body: jsonEncode({'refreshToken': refreshToken}),
      );
    }
    await AuthProvider.clearCredentials();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EasyPark'),
        actions: [
          Row(
            children: [
              Text(
                AuthProvider.username ?? 'Guest',
                style: const TextStyle(color: EasyParkColors.onBackground, fontSize: 16),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.person, color: EasyParkColors.onBackground),
                color: EasyParkColors.surfaceElevated,
                onSelected: (value) {
                  if (value == 'logout') {
                    _logout();
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout),
                      title: Text('Logout'),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 32),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            Container(
              height: 70,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                'Menu',
                style: TextStyle(fontSize: 22, color: EasyParkColors.onBackground),
              ),
            ),
            ...drawerItems.asMap().entries.map((entry) {
              int index = entry.key;
              DrawerItem item = entry.value;

              return ListTile(
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: _selectedIndex == index
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                selected: _selectedIndex == index,
                onTap: () => _changeScreen(index),
              );
            }),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                _logout();
              },
            ),
          ],
        ),
      ),
      body: _selectedScreen,
    );
  }
}

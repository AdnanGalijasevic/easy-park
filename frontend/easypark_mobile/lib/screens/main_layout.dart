import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easypark_mobile/providers/bookmark_provider.dart';
import 'package:easypark_mobile/screens/home_screen.dart';
import 'package:easypark_mobile/screens/reservations_screen.dart';
import 'package:easypark_mobile/screens/transactions_screen.dart';
import 'package:easypark_mobile/screens/bookmarks_screen.dart';
import 'package:easypark_mobile/screens/profile_screen.dart';
import 'package:easypark_mobile/screens/notification_screen.dart';
import 'package:easypark_mobile/providers/notification_provider.dart';
import 'package:easypark_mobile/providers/auth_provider.dart';
import 'package:easypark_mobile/providers/shell_navigation_provider.dart';
import 'package:easypark_mobile/utils/constants.dart';
import 'package:easypark_mobile/theme/easy_park_colors.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  static const Duration _notificationRefreshInterval = Duration(seconds: 30);
  Timer? _notificationRefreshTimer;

  void _refreshNotifications() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.user == null) {
      return;
    }
    Provider.of<NotificationProvider>(
      context,
      listen: false,
    ).fetchMyNotifications(auth.user!.id);
  }

  void _startNotificationAutoRefresh() {
    _notificationRefreshTimer?.cancel();
    _notificationRefreshTimer = Timer.periodic(
      _notificationRefreshInterval,
      (_) => _refreshNotifications(),
    );
  }

  void _stopNotificationAutoRefresh() {
    _notificationRefreshTimer?.cancel();
    _notificationRefreshTimer = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BookmarkProvider>(context, listen: false).loadBookmarks();
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        _refreshNotifications();
        _startNotificationAutoRefresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotifications();
      _startNotificationAutoRefresh();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopNotificationAutoRefresh();
    }
  }

  @override
  void dispose() {
    _stopNotificationAutoRefresh();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    ReservationsScreen(),
    TransactionsScreen(),
    BookmarksScreen(),
    ProfileScreen(),
  ];

  final List<String> _titles = [
    AppConstants.appName,
    "My Reservations",
    "Transactions",
    "Bookmarks",
    "Profile",
  ];

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellNavigationProvider>();
    final currentIndex = shell.currentTabIndex;
    final notificationProvider = Provider.of<NotificationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[currentIndex]),
        centerTitle: true,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NotificationScreen()),
                  );
                },
              ),
              if (notificationProvider.unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: EasyParkColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${notificationProvider.unreadCount}',
                      style: const TextStyle(
                        color: EasyParkColors.onAccent,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _screens[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: shell.setTab,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "Reservations",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: "Transactions",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border),
            label: "Bookmarks",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

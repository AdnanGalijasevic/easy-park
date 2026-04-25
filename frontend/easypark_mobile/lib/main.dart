import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:easypark_mobile/providers/auth_provider.dart';
import 'package:easypark_mobile/providers/parking_location_provider.dart';
import 'package:easypark_mobile/providers/reservation_provider.dart';
import 'package:easypark_mobile/providers/bookmark_provider.dart';
import 'package:easypark_mobile/providers/review_provider.dart';
import 'package:easypark_mobile/providers/notification_provider.dart';
import 'package:easypark_mobile/providers/shell_navigation_provider.dart';
import 'package:easypark_mobile/screens/login_screen.dart';
import 'package:easypark_mobile/utils/constants.dart';
import 'package:easypark_mobile/screens/main_layout.dart';
import 'package:easypark_mobile/theme/easy_park_theme.dart';
import 'package:easypark_mobile/utils/web_url_helper_stub.dart'
    if (dart.library.html) 'package:easypark_mobile/utils/web_url_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('dotenv .env: $e');
    try {
      await dotenv.load(fileName: 'assets/config.env');
    } catch (e2) {
      debugPrint('dotenv config.env: $e2');
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => ShellNavigationProvider()),
        ChangeNotifierProvider(create: (_) => ParkingLocationProvider()),
        ChangeNotifierProvider(create: (_) => ReservationProvider()),
        ChangeNotifierProvider(create: (_) => BookmarkProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        theme: EasyParkTheme.dark,
        themeMode: ThemeMode.dark,
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _paymentHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePaymentReturn());
  }

  Future<void> _handlePaymentReturn() async {
    if (_paymentHandled) return;
    final sessionId = getWebQueryParam('payment_success');
    if (sessionId == null || sessionId.isEmpty) return;
    _paymentHandled = true;

    // Clear query params from browser URL without reload.
    clearWebQueryParams();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    // Wait for auth to finish loading before proceeding.
    if (auth.isLoading) {
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return auth.isLoading;
      });
    }
    if (!auth.isAuthenticated) return;

    try {
      await auth.completePurchase(sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment confirmed! Coins added to your account.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('complete-purchase error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment received but confirmation failed. Pull-to-refresh your balance. ($e)',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (auth.isAuthenticated) {
      return const MainLayout();
    }

    return const LoginScreen();
  }
}

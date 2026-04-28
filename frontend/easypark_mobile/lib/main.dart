import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
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
import 'package:easypark_mobile/utils/app_feedback.dart';
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
  }

  Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
  await Stripe.instance.applySettings();

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
        scaffoldMessengerKey: appScaffoldMessengerKey,
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
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    _initNativeDeepLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePaymentReturn());
  }

  Future<void> _initNativeDeepLinks() async {
    if (kIsWeb) return;
    _appLinks = AppLinks();
    try {
      final initialUri = await _appLinks!.getInitialLink();
      final sessionId = _extractPaymentSessionId(initialUri);
      if (sessionId != null && sessionId.isNotEmpty) {
        await _handlePaymentReturn(sessionIdOverride: sessionId);
      }
    } catch (e) {
      debugPrint('initial deep-link error: $e');
    }

    _deepLinkSub = _appLinks!.uriLinkStream.listen((uri) {
      final sessionId = _extractPaymentSessionId(uri);
      if (sessionId != null && sessionId.isNotEmpty) {
        _handlePaymentReturn(sessionIdOverride: sessionId);
      }
    }, onError: (Object err) {
      debugPrint('deep-link stream error: $err');
    });
  }

  String? _extractPaymentSessionId(Uri? uri) {
    if (uri == null) return null;
    final v1 = uri.queryParameters['payment_success'];
    if (v1 != null && v1.isNotEmpty) return v1;
    final v2 = uri.queryParameters['session_id'];
    if (v2 != null && v2.isNotEmpty) return v2;
    return null;
  }

  Future<void> _handlePaymentReturn({String? sessionIdOverride}) async {
    if (_paymentHandled) return;
    final sessionId = sessionIdOverride ?? getWebQueryParam('payment_success');
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
        AppFeedback.success(
          'Payment confirmed! Coins added to your account.',
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      debugPrint('complete-purchase error: $e');
      if (mounted) {
        AppFeedback.error(
          'Payment received but confirmation failed. Pull-to-refresh your balance. ($e)',
          duration: const Duration(seconds: 5),
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

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    _deepLinkSub = null;
    super.dispose();
  }
}

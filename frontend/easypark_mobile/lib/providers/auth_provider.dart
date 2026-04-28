import 'package:flutter/material.dart';
import 'dart:async';
import 'package:easypark_mobile/models/user.dart';
import 'package:easypark_mobile/services/auth_service.dart';
import 'package:easypark_mobile/services/transaction_service.dart';
import 'package:easypark_mobile/utils/session_events.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;
  StreamSubscription<SessionEvent>? _sessionSubscription;
  bool _handlingUnauthorized = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthService get service => _authService;

  Future<void> _handleUnauthorized() async {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;
    try {
      _user = null;
      await _authService.logout();
      notifyListeners();
    } catch (_) {
      _user = null;
      notifyListeners();
    } finally {
      _handlingUnauthorized = false;
    }
  }

  Future<void> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authService.login(username, password);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirm,
    required DateTime birthDate,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authService.register(
        firstName: firstName,
        lastName: lastName,
        username: username,
        email: email,
        phone: phone,
        password: password,
        passwordConfirm: passwordConfirm,
        birthDate: birthDate,
      );
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestPasswordReset(String emailOrUsername) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.requestPasswordReset(emailOrUsername);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.resetPassword(
        token: token,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  Future<void> getCurrentUser({bool notify = true}) async {
    if (_user == null) return;
    try {
      if (notify) {
        _isLoading = true;
        notifyListeners();
      }
      _user = await _authService.getCurrentUser(_user!.id);
    } catch (e) {
      rethrow;
    } finally {
      if (notify) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> update(Map<String, dynamic> request) async {
    if (_user == null) return;
    try {
      _isLoading = true;
      notifyListeners();
      _user = await _authService.update(_user!.id, request);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Called after Stripe redirects back to the app with a session ID.
  /// Completes the purchase server-side and refreshes user coins.
  Future<void> completePurchase(String sessionId) async {
    try {
      await TransactionService().completePurchase(sessionId);
    } catch (_) {
      rethrow;
    } finally {
      // Always refresh user balance regardless.
      if (_user != null) {
        try {
          _user = await _authService.getCurrentUser(_user!.id);
          notifyListeners();
        } catch (_) {}
      }
    }
  }

  // Restore previously issued JWT session and cached profile.
  Future<void> init() async {
    _sessionSubscription ??= SessionEvents.stream.listen((event) {
      if (event == SessionEvent.unauthorized) {
        _handleUnauthorized();
      }
    });

    _isLoading = true;
    notifyListeners();

    try {
      await _authService.tryAutoLogin();

      final accessToken = _authService.accessToken;
      final userId = _authService.userId;
      if (accessToken != null && userId != null) {
        _user = await _authService.getCurrentUser(userId);
      }
    } catch (_) {
      // Stored credentials are invalid or backend unavailable.
      _user = null;
      await _authService.logout();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:easypark_mobile/services/base_service.dart';

class BaseProvider<T> with ChangeNotifier {
  final BaseService<T> _service;
  List<T> _items = [];
  bool _isLoading = false;
  String? _error;

  BaseProvider(this._service);

  List<T> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadData({Map<String, dynamic>? search}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await _service.get(search: search);
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

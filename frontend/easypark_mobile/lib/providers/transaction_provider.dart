import 'package:flutter/foundation.dart';
import 'package:easypark_mobile/models/transaction.dart';
import 'package:easypark_mobile/providers/base_provider.dart';
import 'package:easypark_mobile/services/transaction_service.dart';
import 'package:url_launcher/url_launcher.dart';

class TransactionProvider extends BaseProvider<Transaction> {
  TransactionProvider() : super(TransactionService());
  bool _isBuying = false;
  bool get isBuying => _isBuying;

  Future<bool> buyCoins(int amount) async {
    _isBuying = true;
    notifyListeners();
    try {
      final service = TransactionService();
      final url = await service.createCheckoutSession(amount);

      final uri = Uri.parse(url);
      if (!await canLaunchUrl(uri)) {
        throw Exception('Could not launch payment URL');
      }

      // On web: use platformDefault so Stripe opens in the same tab
      // and redirects back to our app URL on completion.
      // On mobile: open in an in-app browser so the user can return.
      final mode = kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.inAppBrowserView;

      await launchUrl(uri, mode: mode);
      _isBuying = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error in buyCoins: $e');
      _isBuying = false;
      notifyListeners();
      return false;
    }
  }
}

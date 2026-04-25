import 'dart:ui_web' as ui_web;
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:easypark_mobile/utils/constants.dart';

@JS('JSON.stringify')
external String? _jsStringify(JSAny? value);

Future<bool> showStripePaymentDialog(
  BuildContext context, {
  required String token,
  required int amount,
}) async {
  final viewId = 'stripe-payment-iframe-${DateTime.now().millisecondsSinceEpoch}';
  final src = '${AppConstants.baseUrl}/Transaction/payment-form?amount=$amount&token=${Uri.encodeComponent(token)}';

  final completer = _PaymentCompleter();

  // Register iframe element factory.
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final iframe = web.HTMLIFrameElement()
      ..src = src
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    return iframe;
  });

  // Listen for postMessage from iframe.
  void onMessage(web.MessageEvent event) {
    try {
      final data = event.data;
      if (data == null) return;
      final jsonStr = _jsStringify(data);
      if (jsonStr == null) return;
      // Simple string check — avoids dart:convert dependency in this file.
      if (jsonStr.contains('"STRIPE_PAYMENT_SUCCESS"')) {
        completer.complete(true);
      }
    } catch (_) {}
  }

  final listener = onMessage.toJS;
  web.window.addEventListener('message', listener);

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _PaymentFormDialog(
      viewId: viewId,
      completer: completer,
    ),
  );

  web.window.removeEventListener('message', listener);
  return result ?? false;
}

class _PaymentCompleter {
  bool _completed = false;
  bool get isCompleted => _completed;
  VoidCallback? _onComplete;

  void complete(bool success) {
    if (_completed) return;
    _completed = true;
    _onComplete?.call();
  }

  void onComplete(VoidCallback cb) {
    _onComplete = cb;
    if (_completed) cb();
  }
}

class _PaymentFormDialog extends StatefulWidget {
  final String viewId;
  final _PaymentCompleter completer;

  const _PaymentFormDialog({required this.viewId, required this.completer});

  @override
  State<_PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends State<_PaymentFormDialog> {
  @override
  void initState() {
    super.initState();
    widget.completer.onComplete(() {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        decoration: BoxDecoration(
          color: const Color(0xFF16213e),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Top Up Coins',
                    style: TextStyle(color: Color(0xFF86B94E), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: HtmlElementView(viewType: widget.viewId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

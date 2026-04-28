import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import 'package:easypark_mobile/models/transaction.dart';
import 'package:easypark_mobile/providers/transaction_provider.dart';
import 'package:easypark_mobile/providers/auth_provider.dart';
import 'package:easypark_mobile/services/transaction_service.dart';
import 'package:easypark_mobile/theme/easy_park_colors.dart';
import 'package:easypark_mobile/utils/app_feedback.dart';
import 'package:easypark_mobile/utils/stripe_pdf_export.dart';
import 'package:easypark_mobile/widgets/payment_dialog_result.dart';
import 'package:easypark_mobile/widgets/stripe_payment_dialog.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TransactionProvider _transactionProvider = TransactionProvider();

  List<Transaction> _transactions = [];
  bool _isLoading = true;
  bool _isPaymentInProgress = false;
  String? _errorMessage;
  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '').trim();
  String? _actionDisabledReason(AuthProvider auth) {
    if (_isPaymentInProgress) {
      return 'Payment is currently processing. Please wait for completion.';
    }
    if (_isLoading) {
      return 'Transactions are loading. Actions will be enabled shortly.';
    }
    if ((auth.service.accessToken ?? '').trim().isEmpty) {
      return 'Your session expired. Please log in again to continue.';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadTransactions();
      }
    });
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.getCurrentUser(notify: false);

      final currentUserId = auth.user?.id;

      await _transactionProvider.loadData(search: {'userId': currentUserId});

      if (mounted) {
        setState(() {
          _transactions = List.from(_transactionProvider.items);
          _transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _cleanError(e);
          _isLoading = false;
        });
      }
    }
  }

  Color _getTypeColor(Transaction tx) {
    if (_isRefundLike(tx)) {
      return EasyParkColors.highlightBorder;
    }
    if (!tx.isPaid) {
      return EasyParkColors.error;
    }
    if (tx.type.toLowerCase() == 'credit') {
      return EasyParkColors.success;
    }
    return EasyParkColors.error;
  }

  bool _isCancelOrRefund({required String type, String? description}) {
    final loweredType = type.trim().toLowerCase();
    final loweredDescription = (description ?? '').trim().toLowerCase();
    return loweredType.contains('refund') ||
        loweredType.contains('cancel') ||
        loweredDescription.contains('refund') ||
        loweredDescription.contains('cancel');
  }

  bool _isRefundLike(Transaction tx) {
    if (_isCancelOrRefund(type: tx.type, description: tx.description)) {
      return true;
    }
    final loweredType = tx.type.trim().toLowerCase();
    return loweredType == 'debit' && tx.amount > 0;
  }

  String _getDisplayTypeLabel(Transaction tx) {
    if (_isRefundLike(tx)) {
      return 'CREDIT';
    }
    final loweredType = tx.type.trim().toLowerCase();
    if (loweredType == 'credit') return 'CREDIT';
    if (loweredType == 'debit') return 'DEBIT';
    return tx.type.toUpperCase();
  }

  String _getDisplayTitle(Transaction tx) {
    if (_isRefundLike(tx)) return 'App Refund';
    return tx.description ?? 'App Transaction';
  }

  String _formatAmount(double amount, String type, bool isPaid) {
    if (!isPaid) {
      return "+${amount.toStringAsFixed(2)} Coins";
    }
    String pfx = '';
    if (type.toLowerCase() == 'credit' || type.toLowerCase() == 'refund') {
      pfx = '+';
    } else {
      pfx = '-';
    }
    return "$pfx${amount.toStringAsFixed(2)} Coins";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EasyParkColors.background,
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        color: EasyParkColors.accent,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: EasyParkColors.error,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Unable to load transactions.",
                      style: TextStyle(
                        fontSize: 16,
                        color: EasyParkColors.onBackground,
                      ),
                    ),
                    if (_errorMessage != null && _errorMessage!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: EasyParkColors.textSecondary,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: _loadTransactions,
                      child: const Text("Try again"),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  _buildSummaryCard(),
                  Expanded(
                    child: _transactions.isEmpty
                        ? _buildEmptyState()
                        : _buildTransactionsList(),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _downloadAndShareStripePdf({
    required bool allTime,
    int? year,
    int? month,
  }) async {
    try {
      final svc = TransactionService();
      final bytes = await svc.downloadStripePaymentsPdf(
        allTime: allTime,
        year: year,
        month: month,
      );
      if (!mounted) return;
      final name = allTime
          ? 'easypark-stripe-payments-all-time.pdf'
          : 'easypark-stripe-${year!}-${month!.toString().padLeft(2, '0')}.pdf';
      final path = await exportStripePdfBytes(bytes, name);

      if (!mounted) return;
      AppFeedback.success(
        path != null && path.isNotEmpty ? 'PDF saved: $path' : 'PDF download started',
      );
      await Printing.sharePdf(bytes: bytes, filename: name);
    } catch (e) {
      if (mounted) {
        AppFeedback.error('Could not export PDF. ${_cleanError(e)}');
      }
    }
  }

  Future<void> _showStripePdfDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stripe payments PDF'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('All time'),
              onTap: () => Navigator.pop(ctx, 'all'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Single month…'),
              onTap: () => Navigator.pop(ctx, 'month'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'month') {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime(now.year, now.month),
        firstDate: DateTime(now.year - 5),
        lastDate: now,
      );
      if (picked == null || !mounted) return;
      await _downloadAndShareStripePdf(
        allTime: false,
        year: picked.year,
        month: picked.month,
      );
    } else {
      await _downloadAndShareStripePdf(allTime: true);
    }
  }

  Future<void> _showBuyCoinsDialog() async {
    if (_isPaymentInProgress) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final coinsToCharge = await showDialog<int>(
      context: context,
      builder: (ctx) => const _CoinAmountPickerDialog(),
    );
    if (coinsToCharge == null || !mounted) return;

    final token = auth.service.accessToken?.trim();
    if (token == null || token.isEmpty) {
      AppFeedback.error('Please log in again to make a payment.');
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _PaymentLoadingDialog(),
      );
    }

    StripePaymentResult paymentResult = const StripePaymentResult(
      status: StripePaymentStatus.cancelled,
    );
    try {
      if (mounted) {
        setState(() => _isPaymentInProgress = true);
      }
      paymentResult = await openStripePaymentDialog(
        context,
        token: token,
        amount: coinsToCharge,
      );
    } finally {
      if (mounted) {
        setState(() => _isPaymentInProgress = false);
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    }

    if (!mounted) return;
    if (paymentResult.isSuccess) {
      await auth.getCurrentUser();
      await _loadTransactions();
      if (!mounted) return;
      AppFeedback.success(
        paymentResult.status == StripePaymentStatus.alreadyPaid
            ? 'Payment already completed earlier. Balance refreshed.'
            : '$coinsToCharge coins added to your account.',
      );
      return;
    }

    if (paymentResult.status == StripePaymentStatus.failed) {
      AppFeedback.error(
        paymentResult.message ??
            'Payment could not be completed. No coins were charged.',
      );
      return;
    }

    if (paymentResult.status == StripePaymentStatus.cancelled) {
      AppFeedback.info(
        paymentResult.message ??
            'Payment was cancelled. Your balance remains unchanged.',
      );
    }
  }

  Widget _buildSummaryCard() {
    final authUser = Provider.of<AuthProvider>(context).user;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final coins = authUser?.coins ?? 0.0;
    final disabledReason = _actionDisabledReason(auth);
    final hasDisabledReason = disabledReason != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: EasyParkColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: EasyParkColors.shadowSubtle,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Column(
            children: [
              const Text(
                "Balance",
                style: TextStyle(
                  color: EasyParkColors.onBackgroundMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.stars,
                    color: EasyParkColors.highlightBorder,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    coins.toStringAsFixed(2),
                    style: const TextStyle(
                      color: EasyParkColors.onBackground,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: hasDisabledReason ? null : _showBuyCoinsDialog,
                  icon: const Icon(
                    Icons.add_card,
                    color: EasyParkColors.accent,
                  ),
                  label: const Text(
                    'Top Up Coins',
                    style: TextStyle(
                      color: EasyParkColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EasyParkColors.inverseSurface,
                    disabledBackgroundColor: EasyParkColors.surfaceWash,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: hasDisabledReason ? null : _loadTransactions,
                icon: const Icon(Icons.refresh, color: EasyParkColors.accent),
                label: const Text(
                  'Refresh',
                  style: TextStyle(
                    color: EasyParkColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EasyParkColors.inverseSurface,
                  disabledBackgroundColor: EasyParkColors.surfaceWash,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: hasDisabledReason ? null : _showStripePdfDialog,
              icon: const Icon(
                Icons.picture_as_pdf,
                color: EasyParkColors.onBackground,
              ),
              label: const Text(
                'Export Stripe payments (PDF)',
                style: TextStyle(
                  color: EasyParkColors.onBackground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: EasyParkColors.onBackground,
                side: const BorderSide(color: EasyParkColors.outline),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (hasDisabledReason) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: EasyParkColors.onBackgroundMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    disabledReason,
                    style: const TextStyle(
                      fontSize: 12,
                      color: EasyParkColors.onBackgroundMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.only(top: 100),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(
              Icons.receipt_long,
              size: 80,
              color: EasyParkColors.onBackgroundMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              "No transactions found",
              style: TextStyle(
                fontSize: 18,
                color: EasyParkColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Your payment history will appear here.",
              style: TextStyle(color: EasyParkColors.onBackgroundMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final createdLocal = tx.createdAt.toLocal();
        final isCancelOrRefund = _isRefundLike(tx);
        final typeColor = _getTypeColor(tx);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: typeColor.withValues(alpha: 0.1),
                  child: Icon(
                    tx.type.toLowerCase() == 'credit' ||
                            isCancelOrRefund
                        ? Icons.south_west
                        : Icons.north_east,
                    color: typeColor,
                  ),
                ),
                title: Text(
                  _getDisplayTitle(tx),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      "${createdLocal.day}.${createdLocal.month}.${createdLocal.year} ${createdLocal.hour.toString().padLeft(2, '0')}:${createdLocal.minute.toString().padLeft(2, '0')}",
                      style: TextStyle(
                        color: EasyParkColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.stars,
                          size: 14,
                          color: EasyParkColors.highlightBorder,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatAmount(tx.amount, tx.type, tx.isPaid),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: typeColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: EasyParkColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getDisplayTypeLabel(tx),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: EasyParkColors.onBackgroundMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!tx.isPaid && !isCancelOrRefund)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: EasyParkColors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: EasyParkColors.errorLight),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: EasyParkColors.error,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment unsuccessful',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: EasyParkColors.errorOnContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CoinAmountPickerDialog extends StatefulWidget {
  const _CoinAmountPickerDialog();

  @override
  State<_CoinAmountPickerDialog> createState() =>
      _CoinAmountPickerDialogState();
}

class _CoinAmountPickerDialogState extends State<_CoinAmountPickerDialog> {
  static const List<int> _options = [10, 20, 50, 100];
  int _selectedCoins = 10;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Top Up Coins'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('1 coin = 1.00 BAM. Pick an amount:'),
          const SizedBox(height: 8),
          Text(
            'Will charge: $_selectedCoins coins ($_selectedCoins.00 BAM)',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _options.map((amount) {
              return ChoiceChip(
                label: Text('$amount'),
                selected: _selectedCoins == amount,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedCoins = amount);
                },
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: EasyParkColors.accent,
          ),
          onPressed: () => Navigator.of(context).pop(_selectedCoins),
          child: const Text(
            'Continue to Payment',
            style: TextStyle(color: EasyParkColors.onAccent),
          ),
        ),
      ],
    );
  }
}

class _PaymentLoadingDialog extends StatelessWidget {
  const _PaymentLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return const Dialog(
      backgroundColor: EasyParkColors.surfaceElevated,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text(
              'Preparing secure payment...',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: EasyParkColors.onBackground,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Please keep this screen open until checkout is ready.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: EasyParkColors.onBackgroundMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

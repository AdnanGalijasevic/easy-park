import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import 'package:easypark_mobile/models/transaction.dart';
import 'package:easypark_mobile/providers/transaction_provider.dart';
import 'package:easypark_mobile/providers/auth_provider.dart';
import 'package:easypark_mobile/services/transaction_service.dart';
import 'package:easypark_mobile/theme/easy_park_colors.dart';
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
  String? _errorMessage;

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
      // Always refresh user so balance reflects latest server state.
      await auth.getCurrentUser(notify: false);

      final currentUserId = auth.user?.id;

      await _transactionProvider.loadData(
        search: {
          'userId': currentUserId,
        },
      );

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
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getTypeColor(String type) {
    if (type.toLowerCase() == 'credit' || type.toLowerCase() == 'refund') {
      return EasyParkColors.success;
    }
    return EasyParkColors.error;
  }

  String _formatAmount(double amount, String type) {
    String pfx = '';
    if (type.toLowerCase() == 'credit' || type.toLowerCase() == 'refund') {
      pfx = '+';
    } else {
      pfx = '-';
    }
    return "$pfx${amount.toStringAsFixed(2)} BAM";
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
                      "Failed to load transactions",
                      style: TextStyle(fontSize: 16, color: EasyParkColors.onBackground),
                    ),
                    TextButton(
                      onPressed: _loadTransactions,
                      child: const Text("Tap to Retry"),
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
      await Printing.sharePdf(bytes: bytes, filename: name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export PDF: $e')),
        );
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
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // First show coin amount picker.
    final coinsToCharge = await showDialog<int>(
      context: context,
      builder: (ctx) => const _CoinAmountPickerDialog(),
    );
    if (coinsToCharge == null || !mounted) return;

    final token = auth.service.accessToken;
    if (token == null) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Please log in again to make a payment.')),
      );
      return;
    }

    final paid = await openStripePaymentDialog(
      context,
      token: token,
      amount: coinsToCharge,
    );

    if (!mounted) return;
    if (paid) {
      await auth.getCurrentUser();
      await _loadTransactions();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text('$coinsToCharge coins added to your account!'),
          backgroundColor: EasyParkColors.success,
        ),
      );
    }
  }

  Widget _buildSummaryCard() {
    final authUser = Provider.of<AuthProvider>(context).user;
    final coins = authUser?.coins ?? 0.0;

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
                  const Icon(Icons.stars, color: EasyParkColors.highlightBorder, size: 20),
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
                  onPressed: _showBuyCoinsDialog,
                  icon: const Icon(Icons.add_card, color: EasyParkColors.accent),
                  label: const Text(
                    'Top Up Coins',
                    style: TextStyle(
                      color: EasyParkColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EasyParkColors.inverseSurface,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _loadTransactions,
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
              onPressed: _showStripePdfDialog,
              icon: const Icon(Icons.picture_as_pdf, color: EasyParkColors.onBackground),
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
            const Icon(Icons.receipt_long, size: 80, color: EasyParkColors.onBackgroundMuted),
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
        final typeColor = _getTypeColor(tx.type);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: typeColor.withValues(alpha: 0.1),
              child: Icon(
                tx.type.toLowerCase() == 'credit' ||
                        tx.type.toLowerCase() == 'refund'
                    ? Icons.south_west
                    : Icons.north_east,
                color: typeColor,
              ),
            ),
            title: Text(
              tx.description ?? "App Transaction",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  "${tx.createdAt.day}.${tx.createdAt.month}.${tx.createdAt.year} ${tx.createdAt.hour.toString().padLeft(2, '0')}:${tx.createdAt.minute.toString().padLeft(2, '0')}",
                  style: TextStyle(color: EasyParkColors.textSecondary, fontSize: 13),
                ),
                if (tx.reservationId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      "Reservation #${tx.reservationId}",
                      style: TextStyle(color: EasyParkColors.onBackgroundMuted, fontSize: 12),
                    ),
                  ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatAmount(tx.amount, tx.type),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: typeColor,
                  ),
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
                    tx.type.toUpperCase(),
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
        );
      },
    );
  }
}

class _CoinAmountPickerDialog extends StatefulWidget {
  const _CoinAmountPickerDialog();

  @override
  State<_CoinAmountPickerDialog> createState() => _CoinAmountPickerDialogState();
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
          style: ElevatedButton.styleFrom(backgroundColor: EasyParkColors.accent),
          onPressed: () => Navigator.of(context).pop(_selectedCoins),
          child: const Text('Continue to Payment', style: TextStyle(color: EasyParkColors.onAccent)),
        ),
      ],
    );
  }
}

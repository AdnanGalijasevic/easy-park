
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import 'package:easypark_desktop/providers/reservation_provider.dart';
import 'package:easypark_desktop/providers/auth_provider.dart';
import 'package:easypark_desktop/providers/base_provider.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';
import 'package:easypark_desktop/utils/error_message.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ReservationProvider _reservationProvider = ReservationProvider();
  String _period = 'weekly';
  bool _isLoading = true;
  List<Map<String, dynamic>> _reportData = [];
  double _totalRevenue = 0;
  int _totalReservations = 0;

  DateTime _pdfMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _pdfGraphsOnly = false;
  bool _pdfExporting = false;
  DateTime _stripePdfMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _stripePdfAllTime = false;
  bool _stripePdfExporting = false;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final url =
          '${BaseProvider.baseUrl}Report?reportType=${_period[0].toUpperCase()}${_period.substring(1)}';
      final uri = Uri.parse(url);
      final headers = _createHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final list = decoded['resultList'] as List<dynamic>? ?? [];
        var reports = list.cast<Map<String, dynamic>>();
        if (reports.isEmpty) {
          reports = await _buildFallbackReportData();
        }

        double revenue = 0;
        int reservations = 0;
        for (final r in reports) {
          revenue += (r['totalRevenue'] as num?)?.toDouble() ?? 0;
          reservations += (r['totalReservations'] as num?)?.toInt() ?? 0;
        }

        if (mounted) {
          setState(() {
            _reportData = reports;
            _totalRevenue = revenue;
            _totalReservations = reservations;
            _isLoading = false;
          });
        }
      } else {
        final fallback = await _buildFallbackReportData();
        if (mounted) {
          setState(() {
            _reportData = fallback;
            _totalRevenue = fallback.fold<double>(
              0,
              (sum, r) => sum + ((r['totalRevenue'] as num?)?.toDouble() ?? 0),
            );
            _totalReservations = fallback.fold<int>(
              0,
              (sum, r) => sum + ((r['totalReservations'] as num?)?.toInt() ?? 0),
            );
            _isLoading = false;
          });
          return;
        }
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text('Failed to load reports: ${normalizeErrorMessage(e)}'),
          ),
        );
      }
    }
  }

  DateTime _periodStartUtc() {
    final now = DateTime.now().toUtc();
    switch (_period) {
      case 'daily':
        return DateTime(now.year, now.month, now.day);
      case 'weekly':
        return now.subtract(const Duration(days: 6));
      case 'monthly':
      default:
        return now.subtract(const Duration(days: 29));
    }
  }

  Future<List<Map<String, dynamic>>> _buildFallbackReportData() async {
    final start = _periodStartUtc();
    final result = await _reservationProvider.get(
      filter: {'startTimeFrom': start.toIso8601String()},
      pageSize: 5000,
    );

    final buckets = <String, Map<String, dynamic>>{};
    for (final reservation in result.result) {
      final keyDate = DateTime(
        reservation.startTime.year,
        reservation.startTime.month,
        reservation.startTime.day,
      );
      final key =
          '${keyDate.year}-${keyDate.month.toString().padLeft(2, '0')}-${keyDate.day.toString().padLeft(2, '0')}';

      buckets.putIfAbsent(
        key,
        () => {
          'periodStart': keyDate.toIso8601String(),
          'periodEnd': keyDate.add(const Duration(days: 1)).toIso8601String(),
          'reportType': 'Live',
          'totalRevenue': 0.0,
          'totalReservations': 0,
          'averageRating': null,
        },
      );

      final status = reservation.status;
      if (status != 'Cancelled' && status != 'Expired') {
        buckets[key]!['totalRevenue'] =
            (buckets[key]!['totalRevenue'] as double) + reservation.totalPrice;
        buckets[key]!['totalReservations'] =
            (buckets[key]!['totalReservations'] as int) + 1;
      }
    }

    final list = buckets.values.toList()
      ..sort((a, b) => (a['periodStart'] as String).compareTo(b['periodStart'] as String));
    return list;
  }

  Map<String, String> _createHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${AuthProvider.accessToken ?? ''}',
      'X-Client-Type': 'desktop',
    };
  }

  Map<String, String> _createPdfHeaders() {
    final h = _createHeaders();
    h.remove('Content-Type');
    return h;
  }

  Future<void> _pickPdfMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pdfMonth,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year, now.month + 1, 0),
    );
    if (picked != null && mounted) {
      setState(() => _pdfMonth = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _exportMonthlyPdf() async {
    setState(() => _pdfExporting = true);
    try {
      final y = _pdfMonth.year;
      final m = _pdfMonth.month;
      final q = <String, String>{
        'year': '$y',
        'month': '$m',
        if (_pdfGraphsOnly) 'graphsOnly': 'true',
      };
      final uri = Uri.parse('${BaseProvider.baseUrl}Report/monthly-summary-pdf')
          .replace(queryParameters: q);
      final response = await http.get(uri, headers: _createPdfHeaders());
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final suffix = _pdfGraphsOnly ? 'charts' : 'report';
        final name =
            'easypark-admin-$suffix-${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}.pdf';
        await Printing.sharePdf(bytes: response.bodyBytes, filename: name);
      } else if (mounted) {
        final body = response.body;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF export failed (${response.statusCode})'
              '${body.isNotEmpty ? ': $body' : ''}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to export monthly PDF: ${normalizeErrorMessage(e)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfExporting = false);
    }
  }

  Future<void> _pickStripePdfMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _stripePdfMonth,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year, now.month + 1, 0),
    );
    if (picked != null && mounted) {
      setState(() => _stripePdfMonth = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _exportStripePaymentsPdf() async {
    setState(() => _stripePdfExporting = true);
    try {
      final q = <String, String>{
        if (_stripePdfAllTime) 'allTime': 'true',
        if (!_stripePdfAllTime) 'year': '${_stripePdfMonth.year}',
        if (!_stripePdfAllTime) 'month': '${_stripePdfMonth.month}',
      };
      final uri = Uri.parse('${BaseProvider.baseUrl}Transaction/stripe-payments-pdf')
          .replace(queryParameters: q);
      final response = await http.get(uri, headers: _createPdfHeaders());
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final name = _stripePdfAllTime
            ? 'easypark-stripe-payments-all-time.pdf'
            : 'easypark-stripe-payments-${_stripePdfMonth.year.toString().padLeft(4, '0')}-${_stripePdfMonth.month.toString().padLeft(2, '0')}.pdf';
        await Printing.sharePdf(bytes: response.bodyBytes, filename: name);
      } else if (mounted) {
        final body = response.body;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stripe PDF export failed (${response.statusCode})'
              '${body.isNotEmpty ? ': $body' : ''}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to export Stripe payments PDF: ${normalizeErrorMessage(e)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _stripePdfExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          _buildPeriodToggle(),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReports),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMonthlyPdfCard(),
                  const SizedBox(height: 12),
                  _buildStripePdfCard(),
                  const SizedBox(height: 20),
                  _buildSummaryRow(),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildRevenueChart()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildReservationsChart()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDataTable(),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodToggle() {
    return Container(
      margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: EasyParkColors.inverseSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['daily', 'weekly', 'monthly'].map((p) {
          final isSelected = _period == p;
          return GestureDetector(
            onTap: () {
              if (_period != p) {
                setState(() => _period = p);
                _loadReports();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? EasyParkColors.accent : EasyParkColors.inverseSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                p[0].toUpperCase() + p.substring(1),
                style: TextStyle(
                  color: isSelected ? EasyParkColors.onAccent : EasyParkColors.accent,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthlyPdfCard() {
    final label = DateFormat.yMMMM().format(_pdfMonth);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.picture_as_pdf, color: EasyParkColors.accent),
                SizedBox(width: 8),
                Text(
                  'Monthly PDF (admin)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Export is always for a single calendar month. Choose month, optional graphs-only layout, then share or print.',
              style: TextStyle(fontSize: 13, color: EasyParkColors.textOnLightSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickPdfMonth,
                  icon: const Icon(Icons.calendar_month, size: 20),
                  label: Text(label),
                ),
                FilterChip(
                  label: const Text('Graphs only (no totals / table)'),
                  selected: _pdfGraphsOnly,
                  labelStyle: const TextStyle(color: EasyParkColors.onAccent),
                  selectedColor: EasyParkColors.accent,
                  checkmarkColor: EasyParkColors.onAccent,
                  backgroundColor: EasyParkColors.surfaceElevated,
                  onSelected: (v) => setState(() => _pdfGraphsOnly = v),
                ),
                Tooltip(
                  message: _pdfExporting
                      ? 'Monthly PDF export already in progress.'
                      : 'Export monthly PDF report',
                  child: FilledButton.icon(
                    onPressed: _pdfExporting ? null : _exportMonthlyPdf,
                    icon: _pdfExporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share, size: 20),
                    label: Text(_pdfExporting ? 'Preparing…' : 'Export PDF'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStripePdfCard() {
    final label = DateFormat.yMMMM().format(_stripePdfMonth);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long, color: EasyParkColors.accent),
                SizedBox(width: 8),
                Text(
                  'Stripe Payments PDF',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Export Stripe payment transactions as a separate finance report (monthly or all-time).',
              style: TextStyle(fontSize: 13, color: EasyParkColors.textOnLightSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: const Text('All time'),
                  selected: _stripePdfAllTime,
                  labelStyle: const TextStyle(color: EasyParkColors.onAccent),
                  selectedColor: EasyParkColors.accent,
                  checkmarkColor: EasyParkColors.onAccent,
                  backgroundColor: EasyParkColors.surfaceElevated,
                  onSelected: (v) => setState(() => _stripePdfAllTime = v),
                ),
                Tooltip(
                  message: _stripePdfAllTime
                      ? 'Disable "All time" to choose month.'
                      : 'Choose export month',
                  child: OutlinedButton.icon(
                    onPressed: _stripePdfAllTime ? null : _pickStripePdfMonth,
                    icon: const Icon(Icons.calendar_month, size: 20),
                    label: Text(label),
                  ),
                ),
                Tooltip(
                  message: _stripePdfExporting
                      ? 'Stripe PDF export already in progress.'
                      : 'Export Stripe payments PDF',
                  child: FilledButton.icon(
                    onPressed: _stripePdfExporting ? null : _exportStripePaymentsPdf,
                    icon: _stripePdfExporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share, size: 20),
                    label: Text(_stripePdfExporting ? 'Preparing…' : 'Export PDF'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        _statCard(
          'Total Revenue',
          '\$${_totalRevenue.toStringAsFixed(2)}',
          Icons.attach_money,
          EasyParkColors.success,
        ),
        const SizedBox(width: 16),
        _statCard(
          'Total Reservations',
          '$_totalReservations',
          Icons.book_online,
          EasyParkColors.info,
        ),
        const SizedBox(width: 16),
        _statCard(
          'Report Periods',
          '${_reportData.length}',
          Icons.calendar_today,
          EasyParkColors.accent,
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(title, style: const TextStyle(color: EasyParkColors.muted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    if (_reportData.isEmpty) {
      return const Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            height: 300,
            child: Center(
              child: Text('No data', style: TextStyle(color: EasyParkColors.onBackgroundMuted)),
            ),
          ),
        ),
      );
    }

    final spots = _reportData.asMap().entries.map((e) {
      final revenue = (e.value['totalRevenue'] as num?)?.toDouble() ?? 0;
      return FlSpot(e.key.toDouble(), revenue);
    }).toList();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) =>
                            Text('#${val.toInt() + 1}'),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: EasyParkColors.success,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: EasyParkColors.success.withValues(alpha: 0.2),
                      ),
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationsChart() {
    if (_reportData.isEmpty) {
      return const Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            height: 300,
            child: Center(
              child: Text('No data', style: TextStyle(color: EasyParkColors.onBackgroundMuted)),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reservations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) =>
                            Text('#${val.toInt() + 1}'),
                      ),
                    ),
                  ),
                  barGroups: _reportData.asMap().entries.map((e) {
                    final reservations =
                        (e.value['totalReservations'] as num?)?.toDouble() ?? 0;
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: reservations,
                          color: EasyParkColors.info,
                          width: 18,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    if (_reportData.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Period Start')),
                  DataColumn(label: Text('Period End')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Revenue')),
                  DataColumn(label: Text('Reservations')),
                  DataColumn(label: Text('Avg Rating')),
                ],
                rows: _reportData.map((r) {
                  final start = _parseDate(r['periodStart']);
                  final end = _parseDate(r['periodEnd']);
                  return DataRow(
                    cells: [
                      DataCell(Text(start)),
                      DataCell(Text(end)),
                      DataCell(Text(r['reportType']?.toString() ?? '—')),
                      DataCell(
                        Text(
                          '\$${(r['totalRevenue'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                        ),
                      ),
                      DataCell(Text('${r['totalReservations'] ?? 0}')),
                      DataCell(
                        Text(
                          (r['averageRating'] as num?)?.toStringAsFixed(1) ??
                              '—',
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _parseDate(dynamic val) {
    if (val == null) return '—';
    try {
      final dt = DateTime.parse(val.toString());
      return '${dt.day}.${dt.month}.${dt.year}';
    } catch (_) {
      return val.toString();
    }
  }
}

extension StringExtension on String {
  String capitalize() =>
      isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : this;
}

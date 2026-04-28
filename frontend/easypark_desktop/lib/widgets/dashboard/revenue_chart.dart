import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:easypark_desktop/models/reservation_model.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';

class RevenueChart extends StatefulWidget {
  final List<Reservation> reservations;

  const RevenueChart({super.key, required this.reservations});

  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart> {
  static const _days = 30;

  bool _isRevenueStatus(String status) {
    return status != 'Cancelled' && status != 'Expired';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final spots = <FlSpot>[];
    final dayLabels = <String>[];
    double maxRevenue = 0;
    double totalRevenue = 0;

    for (int dayOffset = _days - 1; dayOffset >= 0; dayOffset--) {
      final dayDate = DateTime(now.year, now.month, now.day - dayOffset);
      final nextDay = dayDate.add(const Duration(days: 1));
      final index = (_days - 1 - dayOffset).toDouble();

      dayLabels.add('${dayDate.day}/${dayDate.month}');

      final revenue = widget.reservations
          .where(
            (r) =>
                _isRevenueStatus(r.status) &&
                !r.startTime.isBefore(dayDate) &&
                r.startTime.isBefore(nextDay),
          )
          .fold(0.0, (sum, r) => sum + r.totalPrice);

      if (revenue > maxRevenue) maxRevenue = revenue;
      totalRevenue += revenue;
      spots.add(FlSpot(index, revenue));
    }

    const lineColor = EasyParkColors.chartElectric;
    final fillColor = lineColor.withValues(alpha: 0.12);

    String formatCurrency(double val) {
      if (val >= 1000) {
        return '\$${(val / 1000).toStringAsFixed(1)}k';
      }
      return '\$${val.toStringAsFixed(0)}';
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.attach_money,
                  size: 18,
                  color: EasyParkColors.chartElectric,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Revenue – Last 30 Days',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (widget.reservations.any((r) => _isRevenueStatus(r.status)))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: EasyParkColors.chartElectric.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Total: ${formatCurrency(totalRevenue)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: EasyParkColors.chartElectric,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 260,
              child: widget.reservations.isEmpty
                  ? _buildEmptyState()
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (val) => FlLine(
                            color: EasyParkColors.muted.withValues(alpha: 0.15),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            bottom: BorderSide(
                              color: EasyParkColors.muted.withValues(alpha: 0.3),
                            ),
                            left: BorderSide(
                              color: EasyParkColors.muted.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        minY: 0,
                        maxY: maxRevenue < 1 ? 100 : maxRevenue * 1.25,
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final dayLabel = dayLabels[spot.x.toInt()];
                                return LineTooltipItem(
                                  '$dayLabel\n${formatCurrency(spot.y)}',
                                  const TextStyle(
                                    color: EasyParkColors.onAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                          handleBuiltInTouches: true,
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 52,
                              getTitlesWidget: (val, meta) {
                                if (val == meta.min || val == meta.max) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  formatCurrency(val),
                                  style: const TextStyle(fontSize: 9),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              interval: 1,
                              getTitlesWidget: (val, _) {
                                final i = val.toInt();
                                if (i < 0 || i >= dayLabels.length || i % 5 != 0) {
                                  return const SizedBox.shrink();
                                }
                                if (i >= 0 && i < dayLabels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      dayLabels[i],
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            curveSmoothness: 0.35,
                            color: lineColor,
                            barWidth: 3,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, bar, index) =>
                                  FlDotCirclePainter(
                                    radius: 4,
                                    color: EasyParkColors.inverseSurface,
                                    strokeWidth: 2,
                                    strokeColor: lineColor,
                                  ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  lineColor.withValues(alpha: 0.25),
                                  fillColor,
                                ],
                              ),
                            ),
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

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 48, color: EasyParkColors.borderLight),
          SizedBox(height: 8),
          Text(
            'No revenue data available',
            style: TextStyle(color: EasyParkColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

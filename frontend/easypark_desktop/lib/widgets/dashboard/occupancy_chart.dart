import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:easypark_desktop/models/reservation_model.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';

class OccupancyChart extends StatefulWidget {
  final List<Reservation> reservations;

  const OccupancyChart({super.key, required this.reservations});

  @override
  State<OccupancyChart> createState() => _OccupancyChartState();
}

class _OccupancyChartState extends State<OccupancyChart> {
  static const _spotTypes = ['Regular', 'Disabled', 'Electric', 'Covered'];
  static const _spotColors = [
    EasyParkColors.chartRegular,
    EasyParkColors.chartDisabled,
    EasyParkColors.chartElectric,
    EasyParkColors.chartCovered,
  ];

  int _touchedIndex = -1;

  static const _days = 30;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final dailyData = <int, Map<String, double>>{};
    for (int i = 0; i < _days; i++) {
      dailyData[i] = {for (var t in _spotTypes) t: 0};
    }

    for (final r in widget.reservations) {
      final startOfDay = DateTime(
        r.startTime.year,
        r.startTime.month,
        r.startTime.day,
      );
      final today = DateTime(now.year, now.month, now.day);
      final diffDays = today.difference(startOfDay).inDays;
      if (diffDays >= 0 && diffDays < _days) {
        final index = (_days - 1) - diffDays;
        final type = r.spotType ?? 'Regular';
        if (dailyData[index]!.containsKey(type)) {
          dailyData[index]![type] = (dailyData[index]![type] ?? 0) + 1;
        }
      }
    }

    final barGroups = <BarChartGroupData>[];
    double maxY = 0;

    for (int i = 0; i < _days; i++) {
      final rods = <BarChartRodStackItem>[];
      double cumY = 0;
      for (int t = 0; t < _spotTypes.length; t++) {
        final count = dailyData[i]![_spotTypes[t]] ?? 0;
        if (count > 0) {
          rods.add(BarChartRodStackItem(cumY, cumY + count, _spotColors[t]));
          cumY += count;
        }
      }
      if (rods.isEmpty) {
        rods.add(BarChartRodStackItem(0, 0.001, EasyParkColors.transparent));
      }
      if (cumY > maxY) maxY = cumY;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: cumY == 0 ? 0.001 : cumY,
              rodStackItems: rods,
              width: _days > 14 ? 8 : 14,
              borderRadius: BorderRadius.circular(3),
              color: EasyParkColors.transparent,
            ),
          ],
        ),
      );
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Occupancy – Last 30 Days',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 10,
                  children: List.generate(
                    _spotTypes.length,
                    (i) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _spotColors[i],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _spotTypes[i],
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: widget.reservations.isEmpty
                  ? _buildEmptyState()
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY < 1 ? 5 : maxY * 1.25,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final day = DateTime(
                                now.year,
                                now.month,
                                now.day - (_days - 1 - group.x),
                              );
                              final dayLabel = '${day.day}/${day.month}';
                              final total = rod.toY.round();
                              return BarTooltipItem(
                                '$dayLabel\n$total reservations',
                                const TextStyle(
                                  color: EasyParkColors.onAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                          touchCallback:
                              (FlTouchEvent event, BarTouchResponse? resp) {
                                setState(() {
                                  _touchedIndex =
                                      resp?.spot?.touchedBarGroupIndex ?? -1;
                                });
                              },
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
                              reservedSize: 28,
                              getTitlesWidget: (val, _) {
                                if (val == val.roundToDouble()) {
                                  return Text(
                                    val.toInt().toString(),
                                    style: const TextStyle(fontSize: 9),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              getTitlesWidget: (v, _) {
                                final i = v.toInt();
                                if (i % 5 != 0) return const SizedBox.shrink();
                                final day = DateTime(
                                  now.year,
                                  now.month,
                                  now.day - (_days - 1 - i),
                                );
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${day.day}/${day.month}',
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
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
                        barGroups: List.generate(barGroups.length, (i) {
                          final group = barGroups[i];
                          if (i == _touchedIndex) {
                            return group;
                          }
                          return group;
                        }),
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
          Icon(Icons.bar_chart, size: 48, color: EasyParkColors.borderLight),
          SizedBox(height: 8),
          Text(
            'No reservation data available',
            style: TextStyle(color: EasyParkColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

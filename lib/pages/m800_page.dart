import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
// NOTE: sesuaikan path ini dengan lokasi DataService kamu
import 'package:combisense/services/background_task_service.dart'; // berisi DataService

/// Halaman M800 (punya PageStorageKey + Refresh seperti VentFilter)
class M800Page extends StatefulWidget {
  const M800Page({super.key});

  @override
  State<M800Page> createState() => _M800PageState();
}

class _M800PageState extends State<M800Page> {
  static const _lampMax = 4500.0;

  // warna grafik
  static const kTocColor = Color(0xFFED4D9B);
  static const kTempColor = Color(0xFF25D8A8);
  static const kConductColor = Color(0xFF7A7CCE);

  static const kLampGreen = Color(0xFF6FCF97);
  static const kLampYellow = Color(0xFFF2C94C);
  static const kLampRed = Color(0xFFFF6B6B);

  final _ds = DataService();
  bool _refreshing = false;
  bool _reloadingBox = false; // pause semua builder Hive saat reload

  Future<void> _handleRefresh() async {
    if (_refreshing || _reloadingBox) return;
    setState(() {
      _refreshing = true;
      _reloadingBox = true;
    });

    try {
      // Tutup & buka ulang boxes agar sinkron dengan background isolate
      const boxes = [
        'm800_toc_history',
        'm800_temp_history',
        'm800_conduct_history',
        // opsional: kalau latest ikut disimpan di sensorDataBox
        'sensorDataBox',
      ];

      for (final name in boxes) {
        if (Hive.isBoxOpen(name)) {
          try {
            await Hive.box(name).close();
          } catch (_) {}
        }
        await Hive.openBox(name);
      }

      // jeda kecil biar transisi halus
      await Future.delayed(const Duration(milliseconds: 150));
    } catch (e) {
      debugPrint('Hive reload failed (M800): $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _reloadingBox = false;
        _refreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController.none(
      child: Padding(
        key: const PageStorageKey('page_m800'),
        padding:
            const EdgeInsets.only(top: 25.0, left: 16, right: 30, bottom: 16),
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            primary: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header minimalis + Lamp badge kecil
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'M800',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const Divider(
                    thickness: 2,
                    color: Colors.black,
                    indent: 0,
                    endIndent: 150),
                const SizedBox(height: 10),

                // === Lamp paling atas ===
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _reloadingBox
                      ? _lampSkeleton()
                      : _LampStickCard(ds: _ds, maxValue: _lampMax),
                ),

                const SizedBox(height: 14),

                // === TOC ===
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _reloadingBox
                      ? _metricSkeleton()
                      : _MetricCard(
                          title: 'TOC',
                          unit: 'ppb',
                          boxName: 'm800_toc_history',
                          latest: _ds.m800Toc,
                          lineColor: kTocColor,
                        ),
                ),

                const SizedBox(height: 10),

                // === Temp ===
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _reloadingBox
                      ? _metricSkeleton()
                      : _MetricCard(
                          title: 'Temp',
                          unit: '°C',
                          boxName: 'm800_temp_history',
                          latest: _ds.m800Temp,
                          lineColor: kTempColor,
                        ),
                ),

                const SizedBox(height: 10),

                // === Conduct ===
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _reloadingBox
                      ? _metricSkeleton()
                      : _MetricCard(
                          title: 'Conduct',
                          unit: 'uS/cm',
                          boxName: 'm800_conduct_history',
                          latest: _ds.m800Conduct,
                          lineColor: kConductColor,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricSkeleton() => Container(
        height: 150,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );

  Widget _lampSkeleton() => Container(
        height: 90,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.unit,
    required this.boxName,
    required this.latest,
    required this.lineColor,
    this.take = 120,
  });

  final String title;
  final String unit;
  final String boxName;
  final ValueNotifier<double?> latest;
  final Color lineColor;
  final int take;

  Text _miniLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
      );

  Set<int> _allowedIndices(int n, {int maxCount = 5}) {
    final res = <int>{};
    if (n <= 0) return res;
    final count = n < maxCount ? n : maxCount;
    if (count == 1) {
      res.add(0);
    } else {
      final step = (n - 1) / (count - 1);
      for (int k = 0; k < count; k++) {
        final idx = (k * step).round().clamp(0, n - 1);
        res.add(idx);
      }
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _miniLabel(title),
              const Spacer(),
              ValueListenableBuilder<double?>(
                valueListenable: latest,
                builder: (_, v, __) => Text(
                  v == null ? '-' : '${v.toStringAsFixed(2)} $unit',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 132,
            child: ValueListenableBuilder(
              valueListenable: Hive.box(boxName).listenable(),
              builder: (_, __, ___) {
                final box = Hive.box(boxName);
                final int len = box.length;
                final int start = (len - take).clamp(0, len).toInt();

                final items = <Map<String, dynamic>>[];
                for (int i = start; i < len; i++) {
                  final it = box.getAt(i);
                  if (it is Map && it['t'] != null && it['v'] != null) {
                    items.add(it.cast<String, dynamic>());
                  }
                }

                // kalau kosong
                if (items.isEmpty) {
                  return const Center(
                    child: Text('No data'),
                  );
                }

                // Spots pakai INDEX 0..n-1 (seperti Vent Filter),
                // label jam tetap dari timestamp
                final spots = <FlSpot>[];
                final labels = <String>[];
                int idx = 0;

                // cek rentang waktu untuk format label adaptif
                final ts = items.map((m) => (m['t'] as int)).toList();
                final minTs = ts.reduce(math.min);
                final maxTs = ts.reduce(math.max);
                final spanMs = (maxTs - minTs).abs();
                final timeFmt = (spanMs < 5 * 60 * 1000)
                    ? DateFormat('HH:mm:ss')
                    : DateFormat('HH:mm');

                for (var m in items) {
                  final t = (m['t'] as int);
                  final v = (m['v'] as num).toDouble();
                  spots.add(FlSpot(idx.toDouble(), v));
                  labels.add(
                      timeFmt.format(DateTime.fromMillisecondsSinceEpoch(t)));
                  idx++;
                }

                // allowed label kiri—kanan & tengah (maks 5)
                final n = labels.length;
                final allowed = _allowedIndices(n, maxCount: 5);

                // auto-scale Y dan tampilkan sumbu Y
                double? minY, maxY;
                if (spots.isNotEmpty) {
                  for (final s in spots) {
                    minY = (minY == null) ? s.y : (s.y < minY! ? s.y : minY);
                    maxY = (maxY == null) ? s.y : (s.y > maxY! ? s.y : maxY);
                  }
                  if (minY == maxY) {
                    minY = minY! - 1;
                    maxY = maxY! + 1;
                  }
                }

                // tentukan interval Y yang rapih (3 ticks)
                double? intervalY;
                if (minY != null && maxY != null) {
                  final span = (maxY! - minY!).abs();
                  if (span <= 0) {
                    intervalY = 1.0;
                  } else {
                    double _roundNice(double x) {
                      const bases = <double>[
                        0.1,
                        0.2,
                        0.5,
                        1.0,
                        2.0,
                        5.0,
                        10.0
                      ];
                      for (final b in bases) {
                        if (x <= b) return b;
                      }
                      return 10.0;
                    }

                    intervalY = _roundNice(span / 3.0);
                  }
                }

                final double minX = 0.0;
                final double maxX =
                    (n - 1).clamp(0, double.infinity).toDouble();

                return LineChart(
                  LineChartData(
                    minX: minX,
                    maxX: maxX.isNaN ? 0 : maxX,
                    minY: minY,
                    maxY: maxY,

                    // grid rapih
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      getDrawingVerticalLine: (_) => FlLine(
                          color: Colors.grey.withOpacity(0.10), strokeWidth: 1),
                      getDrawingHorizontalLine: (_) => FlLine(
                          color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
                    ),

                    // Axis
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval: intervalY,
                          getTitlesWidget: (v, _) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              v.toStringAsFixed(
                                  (intervalY != null && intervalY! < 1)
                                      ? 1
                                      : 0),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black54),
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1, // penting: biar v = indeks integer
                          getTitlesWidget: (value, meta) {
                            final i = value.round();
                            if (i < 0 || i >= labels.length) {
                              return const SizedBox.shrink();
                            }
                            if (!allowed.contains(i)) {
                              return const SizedBox.shrink();
                            }

                            final isFirst = i == 0;
                            final isLast = i == labels.length - 1;
                            return Padding(
                              padding: EdgeInsets.only(
                                top: 6,
                                left: isFirst ? 2 : 0,
                                right: isLast ? 8 : 0,
                              ),
                              child: Align(
                                alignment: isLast
                                    ? Alignment.centerRight
                                    : (isFirst
                                        ? Alignment.centerLeft
                                        : Alignment.center),
                                child: Text(labels[i],
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.black54)),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.black54, width: 1),
                    ),

                    // Tooltip & indikator
                    lineTouchData: LineTouchData(
                      enabled: true,
                      handleBuiltInTouches: true,
                      touchTooltipData: LineTouchTooltipData(
                        tooltipRoundedRadius: 8,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((s) {
                            final i = s.x.round().clamp(0, labels.length - 1);
                            final textTime = labels[i];
                            return LineTooltipItem(
                              '$textTime\n${s.y.toStringAsFixed(2)} $unit',
                              TextStyle(
                                color: lineColor,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList();
                        },
                      ),
                      getTouchedSpotIndicator: (bar, idxs) => idxs
                          .map((_) => TouchedSpotIndicatorData(
                                FlLine(
                                  color: lineColor.withOpacity(0.25),
                                  strokeWidth: 1,
                                ),
                                FlDotData(
                                  show: true,
                                  getDotPainter: (spot, __, ___, ____) =>
                                      FlDotCirclePainter(
                                    radius: 3,
                                    color: Colors.white,
                                    strokeWidth: 2,
                                    strokeColor: lineColor,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),

                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: false,
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        color: lineColor,
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LampBadge extends StatelessWidget {
  const _LampBadge({required this.ds});
  final DataService ds;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: ds.m800Lamp,
      builder: (_, v, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.grey.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.light_mode, size: 16, color: Colors.black87),
            const SizedBox(width: 6),
            Text(
              'Lamp ${v?.toString() ?? '-'}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

class _LampStickCard extends StatefulWidget {
  const _LampStickCard({required this.ds, required this.maxValue});
  final DataService ds;
  final double maxValue;

  @override
  State<_LampStickCard> createState() => _LampStickCardState();
}

class _LampStickCardState extends State<_LampStickCard> {
  double _lastFrac = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ValueListenableBuilder<int?>(
        valueListenable: widget.ds.m800Lamp,
        builder: (_, v, __) {
          final val = (v ?? 0).toDouble();
          final frac = (val / widget.maxValue).clamp(0.0, 1.0).toDouble();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Running Hours UV Lamp',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey)),
              const SizedBox(height: 4),
              Text(
                  '${val.toStringAsFixed(0)} / ${widget.maxValue.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              const SizedBox(height: 8),

              // Lamp bar (progress bar)
              Builder(
                builder: (context) {
                  final bg = Colors.grey.withOpacity(0.12);

                  // 1.0 → hijau, 0.5 → kuning, 0.0 → merah
                  late final Color fg;
                  if (frac >= 0.5) {
                    // segmen hijau → kuning
                    final t = (1.0 - frac) / 0.5; // 1→0, 0.5→1
                    fg = Color.lerp(_M800PageState.kLampGreen,
                        _M800PageState.kLampYellow, t)!;
                  } else {
                    // segmen kuning → merah
                    final t = (0.5 - frac) / 0.5; // 0.5→0, 0.0→1
                    fg = Color.lerp(_M800PageState.kLampYellow,
                        _M800PageState.kLampRed, t)!;
                  }

                  // bar selalu full width; yang berubah cuma fill-nya
                  return Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: frac, // 0..1
                        child: Container(
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: fg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

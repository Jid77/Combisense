import 'package:flutter/material.dart';
import 'package:combisense/services/tf3_service.dart';
import 'package:combisense/utils/auth_helper.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class lbeng04Page extends StatefulWidget {
  final double tempAhu04lb;
  final double rhAhu04lb;
  final Tf3Service tf3Service;

  const lbeng04Page({
    Key? key,
    required this.tempAhu04lb,
    required this.rhAhu04lb,
    required this.tf3Service,
  }) : super(key: key);

  @override
  State<lbeng04Page> createState() => _lbeng04PageState();
}

class _lbeng04PageState extends State<lbeng04Page> {
  final Tf3Service _tf3Service = Tf3Service(name: 'tf3');
  bool _reloadingBox = false;

  @override
  void dispose() {
    _tf3Service.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_reloadingBox) return;
    setState(() => _reloadingBox = true);

    const boxName = 'sensorDataBox';
    try {
      if (Hive.isBoxOpen(boxName)) {
        try {
          await Hive.box(boxName).close();
        } catch (_) {}
      }
      await Hive.openBox(boxName);
      await Future.delayed(const Duration(milliseconds: 120)); // transisi halus
    } catch (e) {
      debugPrint('LBENG reload Hive failed: $e');
    } finally {
      if (!mounted) return;
      setState(() => _reloadingBox = false);
    }
  }

  Widget _buildSP(Stream<double> stream) {
    return StreamBuilder<double>(
      stream: stream,
      builder: (context, snapshot) {
        final sp = snapshot.data?.toStringAsFixed(1) ?? '--';
        return Text(
          "SV: $sp°C",
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        );
      },
    );
  }

  Widget _buildPV(Stream<double> stream, Tf3Service service,
      {double circleSize = 80}) {
    return StreamBuilder<double>(
      stream: stream,
      builder: (context, snapshot) {
        final pv = snapshot.data?.toStringAsFixed(1) ?? '--';
        final value = snapshot.data ?? 0.0;
        final color = value < 18 || value > 28
            ? const Color(0xFFFF6B6B)
            : const Color(0xFF8547b0);
        return GestureDetector(
          onTap: () async {
            if (await AuthHelper.verifyPassword(context)) {
              final controller = TextEditingController();
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Set Preset untuk AHU04LB"),
                  content: TextField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: "Contoh: 23.5"),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Batal"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final val = double.tryParse(controller.text);
                        if (val != null && val > 0) {
                          service.setPreset(val);
                          Navigator.pop(context);
                          AuthHelper.showTopNotification(
                              context, "Preset AHU04LB diatur: $val°C");
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8547b0),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Kirim"),
                    ),
                  ],
                ),
              );
            }
          },
          child: _CircularValue(
            label: 'TF3 Sensor',
            valueText: '$pv°C',
            color: color,
            size: circleSize,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController.none(
      child: Padding(
        key: const PageStorageKey('page3'),
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            primary: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (tanpa tombol refresh)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "LBENG-AHU-004",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 4),
                      Divider(
                        thickness: 2,
                        color: Colors.black,
                        indent: 0,
                        endIndent: 150,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Card status
                Card(
                  elevation: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  shadowColor: Colors.black.withOpacity(0.32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Current Status",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final circleSize = (constraints.maxWidth / 5.2)
                                .clamp(72, 110)
                                .toDouble();
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildPV(
                                          _tf3Service.pvStream, _tf3Service,
                                          circleSize: circleSize),
                                      const SizedBox(height: 6),
                                      _buildSP(_tf3Service.spStream),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _CircularValue(
                                        label: "Temperature",
                                        valueText:
                                            '${widget.tempAhu04lb.toStringAsFixed(1)}°C',
                                        color: const Color(0xFF00B8D4),
                                        size: circleSize,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _CircularValue(
                                        label: "Humidity",
                                        valueText:
                                            '${widget.rhAhu04lb.toStringAsFixed(1)}%',
                                        color: const Color(0xFF00B8D4),
                                        size: circleSize,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Chart interaktif (tanpa tombol refresh – cukup pull-to-refresh)
                AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _reloadingBox
                        ? _chartSkeleton() // <-- sementara, supaya nggak akses Hive saat close/open
                        : const _LbengAhuChartBox() // <-- normal
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chartSkeleton() => Container(
        height: 360,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 6)),
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 2,
                offset: const Offset(0, 1)),
          ],
        ),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
}

class _CircularValue extends StatelessWidget {
  final String label;
  final String valueText;
  final Color color;
  final double size;

  const _CircularValue({
    required this.label,
    required this.valueText,
    required this.color,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: Center(
            child: Text(
              valueText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// ====================[  CHART BOX ala VentFilter (Temp & RH) ]====================
class _LbengAhuChartBox extends StatefulWidget {
  const _LbengAhuChartBox({Key? key}) : super(key: key);

  @override
  State<_LbengAhuChartBox> createState() => _LbengAhuChartBoxState();
}

class _LbengAhuChartBoxState extends State<_LbengAhuChartBox> {
  final List<int> _windows = const [10, 20, 30, 50];
  int _win = 30;
  bool _showTemp = true, _showRh = true;

  DateTime _parseTs(dynamic ts) {
    if (ts is DateTime) return ts;
    final s = ts?.toString() ?? '';
    for (final f in [
      'dd/MM/yy HH:mm',
      'dd/MM/yyyy HH:mm',
      'yyyy-MM-dd HH:mm:ss',
    ]) {
      try {
        return DateFormat(f).parse(s);
      } catch (_) {}
    }
    try {
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('sensorDataBox');

    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        children: [
          // Header judul + dropdown PTS (tanpa tombol refresh)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Graphic Temperature & Humidity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _win,
                    items: _windows
                        .map(
                          (w) => DropdownMenuItem(
                            value: w,
                            child: Text(
                              '$w pts',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _win = v);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Chart
          Expanded(
            child: ValueListenableBuilder<Box>(
              valueListenable: box.listenable(keys: ['sensorDataList']),
              builder: (context, b, _) {
                final list = (b.get('sensorDataList') as List?) ?? [];
                if (list.isEmpty) {
                  return const Center(child: Text('No sensor data available'));
                }

                final total = list.length;
                final start = (total > _win) ? total - _win : 0;

                final temp = <FlSpot>[];
                final rh = <FlSpot>[];
                final labels = <String>[];

                for (int i = start; i < total; i++) {
                  final m = Map.from(list[i] as Map);
                  final x = (i - start).toDouble();
                  final vT = (m['temp_ahu04lb'] as num?)?.toDouble() ?? 0;
                  final vH = (m['rh_ahu04lb'] as num?)?.toDouble() ?? 0;

                  temp.add(FlSpot(x, vT));
                  rh.add(FlSpot(x, vH));
                  labels.add(
                      DateFormat('HH:mm').format(_parseTs(m['timestamp'])));
                }

                // autoscale Y gabungan Temp & RH
                double minY, maxY;
                final all = <double>[
                  ...temp.map((e) => e.y),
                  ...rh.map((e) => e.y)
                ];
                if (all.isEmpty) {
                  minY = 0;
                  maxY = 100;
                } else {
                  final lo = all.reduce((a, b) => a < b ? a : b);
                  final hi = all.reduce((a, b) => a > b ? a : b);
                  minY = (lo - 2).floorToDouble();
                  maxY = (hi + 2).ceilToDouble();
                  if (maxY - minY < 5) maxY = minY + 5;
                }

                final minX = 0.0;
                final maxX = (total > _win)
                    ? (_win - 1).toDouble()
                    : (total - 1).toDouble();

                // ==== Sumbu bawah: kalau pts > 10 → tampilkan 5 label; kalau ≤10 → tampilkan semua ====
                final allowed = <int>{};
                final n = labels.length;
                final count = (n > 10) ? 5 : n; // sesuai request
                if (n > 0 && count > 0) {
                  if (count == 1) {
                    allowed.add(0);
                  } else {
                    final step = (n - 1) / (count - 1); // sebar merata
                    for (int k = 0; k < count; k++) {
                      final idx = (k * step).round();
                      allowed.add(idx.clamp(0, n - 1));
                    }
                  }
                }

                LineChartBarData _line(List<FlSpot> s, Color c) =>
                    LineChartBarData(
                      spots: s,
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: c,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    );

                const tempColor = const Color(0xFFED4D9B);
                const rhColor = Color(0xFF25D8A8);

                final lineTemp = _line(temp, tempColor);
                final lineRh = _line(rh, rhColor);
                final lines = <LineChartBarData>[
                  if (_showTemp) lineTemp,
                  if (_showRh) lineRh,
                ];

                final lineTouchData = LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 10,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                      final lineColor = s.bar.gradient?.colors.first ??
                          (s.bar.color ?? Colors.black);
                      final i = s.x.toInt();
                      final t = (i >= 0 && i < labels.length) ? labels[i] : '';
                      final isTempBar = identical(s.bar, lineTemp);
                      final unit = isTempBar ? '°C' : '%';
                      return LineTooltipItem(
                        '$t\n${s.y.toStringAsFixed(1)} $unit',
                        TextStyle(
                            color: lineColor, fontWeight: FontWeight.bold),
                      );
                    }).toList(),
                  ),
                  getTouchedSpotIndicator: (bar, idxs) {
                    final lineColor = bar.gradient?.colors.first ??
                        (bar.color ?? Colors.black);
                    return idxs
                        .map(
                          (_) => TouchedSpotIndicatorData(
                            FlLine(
                                color: lineColor.withOpacity(0.6),
                                strokeWidth: 1.5),
                            FlDotData(
                              show: true,
                              getDotPainter: (spot, __, ___, ____) =>
                                  FlDotCirclePainter(
                                radius: 3.5,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: lineColor,
                              ),
                            ),
                          ),
                        )
                        .toList();
                  },
                );

                return Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 4, left: 2),
                  child: LineChart(
                    LineChartData(
                      minX: minX,
                      maxX: maxX.isNaN ? 0 : maxX,
                      minY: minY,
                      maxY: maxY,
                      clipData: const FlClipData(
                          top: false, right: false, left: false, bottom: false),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: 2,
                        drawVerticalLine: true,
                        getDrawingHorizontalLine: (_) => FlLine(
                            color: Colors.grey.withOpacity(0.15),
                            strokeWidth: 1),
                        getDrawingVerticalLine: (_) => FlLine(
                            color: Colors.grey.withOpacity(0.10),
                            strokeWidth: 1),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.black54, width: 1),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (v, _) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(v.toInt().toString(),
                                  style: const TextStyle(fontSize: 11)),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 1, // kita filter manual
                            getTitlesWidget: (v, _) {
                              final i = v.round();
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
                                      style: const TextStyle(fontSize: 10)),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: lineTouchData,
                      // garis bantu batas rekomendasi
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: 18,
                            color: tempColor.withOpacity(0.35),
                            strokeWidth: 1.2,
                            dashArray: const [6, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.centerLeft,
                              style: TextStyle(fontSize: 10, color: tempColor),
                              labelResolver: (_) => 'Temp 18°C',
                            ),
                          ),
                          HorizontalLine(
                            y: 27,
                            color: tempColor.withOpacity(0.35),
                            strokeWidth: 1.2,
                            dashArray: const [6, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.centerLeft,
                              style: TextStyle(fontSize: 10, color: tempColor),
                              labelResolver: (_) => 'Temp 27°C',
                            ),
                          ),
                          HorizontalLine(
                            y: 40,
                            color: rhColor.withOpacity(0.35),
                            strokeWidth: 1.2,
                            dashArray: const [6, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.centerLeft,
                              style: TextStyle(fontSize: 10, color: rhColor),
                              labelResolver: (_) => 'RH 40%',
                            ),
                          ),
                          HorizontalLine(
                            y: 60,
                            color: rhColor.withOpacity(0.35),
                            strokeWidth: 1.2,
                            dashArray: const [6, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.centerLeft,
                              style: TextStyle(fontSize: 10, color: rhColor),
                              labelResolver: (_) => 'RH 60%',
                            ),
                          ),
                        ],
                      ),
                      lineBarsData: lines,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Legend interaktif
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _chip('Temp', const Color(0xFFED4D9B), _showTemp,
                    () => setState(() => _showTemp = !_showTemp)),
                _chip('RH', const Color(0xFF25D8A8), _showRh,
                    () => setState(() => _showRh = !_showRh)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color c, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.withOpacity(0.12) : Colors.grey.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? c : Colors.grey.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.black87 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

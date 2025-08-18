import 'dart:async';
import 'package:flutter/material.dart';
import 'package:combisense/services/vent_filter_service.dart';
import 'package:combisense/utils/auth_helper.dart';
import 'package:hive_flutter/hive_flutter.dart'; // penting untuk .listenable()
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class VentFilterPage extends StatefulWidget {
  final double tk201;
  final double tk202;
  final double tk103;

  final Widget? chartWidget; // opsional: kalau mau kirim chart custom dari luar
  final Future<Widget> Function()?
      reloadChart; // opsional: builder chart eksternal

  const VentFilterPage({
    Key? key,
    required this.tk201,
    required this.tk202,
    required this.tk103,
    this.chartWidget,
    this.reloadChart,
  }) : super(key: key);

  @override
  State<VentFilterPage> createState() => _VentFilterPageState();
}

class _VentFilterPageState extends State<VentFilterPage> {
  final _tk201Service = VentFilterService(name: 'tk201');
  final _tk202Service = VentFilterService(name: 'tk202');
  final _tk103Service = VentFilterService(name: 'tk103');

  /// chart eksternal (kalau dikasih dari parent), kalau enggak pakai chart bawaan
  Widget? _externalChart;
  bool _refreshing = false;
  bool _reloadingBox = false;

  @override
  void initState() {
    super.initState();
    _externalChart = widget.chartWidget;
  }

  @override
  void dispose() {
    _tk201Service.dispose();
    _tk202Service.dispose();
    _tk103Service.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_refreshing || _reloadingBox) return;
    setState(() {
      _refreshing = true;
      _reloadingBox = true; // PAUSE semua builder yang baca Hive
    });

    try {
      const boxName = 'sensorDataBox';

      // Tutup aman (kalau sudah keburu ketutup, biarin)
      if (Hive.isBoxOpen(boxName)) {
        try {
          await Hive.box(boxName).close();
        } catch (_) {}
      }

      // Buka lagi dari disk biar baca data terbaru yang ditulis background isolate
      await Hive.openBox(boxName);

      // (opsional) kalau kamu juga sync history:
      // const hist = 'alarmHistoryBox';
      // if (Hive.isBoxOpen(hist)) { try { await Hive.box(hist).close(); } catch (_) {} }
      // await Hive.openBox(hist);

      // Kasih sedikit jeda biar UI nggak kebut saat transisi
      await Future.delayed(const Duration(milliseconds: 150));
    } catch (e) {
      debugPrint('Hive reload failed: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _reloadingBox = false; // resume UI yang listenable ke box
        _refreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Box? sensorBox = _reloadingBox ? null : Hive.box('sensorDataBox');

    return PrimaryScrollController.none(
      child: Padding(
        key: const PageStorageKey('page2'),
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
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      "Vent Filter",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                    ),
                  ],
                ),
                const Divider(
                    thickness: 2,
                    color: Colors.black,
                    indent: 0,
                    endIndent: 150),
                const SizedBox(height: 10),

                // === Card "Current Temperature" — pause saat reload ===
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _reloadingBox
                      ? _statusSkeleton()
                      : _statusCard(sensorBox!), // <- render card asli
                ),

                const SizedBox(height: 16),

                // === Chart — pause saat reload ===
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _reloadingBox
                      ? _chartSkeleton()
                      : const VentFilterChart(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusCard(Box sensorBox) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      shadowColor: Colors.black.withOpacity(0.32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Current Temperature",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ValueListenableBuilder<Box>(
              valueListenable: sensorBox.listenable(keys: ['sensorStatus']),
              builder: (context, box, _) {
                final m = (box.get('sensorStatus') as Map?) ?? {};
                final tk201 = (m['tk201'] as num?)?.toDouble() ?? widget.tk201;
                final tk202 = (m['tk202'] as num?)?.toDouble() ?? widget.tk202;
                final tk103 = (m['tk103'] as num?)?.toDouble() ?? widget.tk103;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final circleSize =
                        (constraints.maxWidth / 5.2).clamp(72, 110).toDouble();

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _TempCircleWithTap(
                                  label: 'Tk201',
                                  value: tk201,
                                  service: _tk201Service,
                                  size: circleSize),
                              const SizedBox(height: 6),
                              _SPText(stream: _tk201Service.spStream),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _TempCircleWithTap(
                                  label: 'Tk202',
                                  value: tk202,
                                  service: _tk202Service,
                                  size: circleSize),
                              const SizedBox(height: 6),
                              _SPText(stream: _tk202Service.spStream),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _TempCircleWithTap(
                                  label: 'Tk103',
                                  value: tk103,
                                  service: _tk103Service,
                                  size: circleSize),
                              const SizedBox(height: 6),
                              _SPText(stream: _tk103Service.spStream),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusSkeleton() => Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              SizedBox(
                  width: 80, height: 80, child: CircularProgressIndicator()),
              SizedBox(
                  width: 80, height: 80, child: CircularProgressIndicator()),
              SizedBox(
                  width: 80, height: 80, child: CircularProgressIndicator()),
            ],
          ),
        ),
      );

  Widget _chartSkeleton() => Container(
        height: 360,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 12,
                offset: Offset(0, 6)),
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 2,
                offset: Offset(0, 1)),
          ],
        ),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
}

/// Bulatan suhu + onTap untuk set preset
class _TempCircleWithTap extends StatelessWidget {
  final String label;
  final double value;
  final VentFilterService service;
  final double size;

  const _TempCircleWithTap({
    Key? key,
    required this.label,
    required this.value,
    required this.service,
    this.size = 80,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = (value < 65 || value > 80)
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF8547b0);

    return GestureDetector(
      onTap: () async {
        if (await AuthHelper.verifyPassword(context)) {
          final controller =
              TextEditingController(text: value.toStringAsFixed(0));
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text("Set Preset untuk $label"),
              content: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Contoh: 70"),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Batal")),
                ElevatedButton(
                  onPressed: () {
                    final val = double.tryParse(controller.text);
                    if (val != null && val > 0) {
                      service.setPreset(val);
                      Navigator.pop(context);
                      AuthHelper.showTopNotification(
                          context, "Preset $label diatur: $val");
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
      child: Column(
        children: [
          Container(
            width: size, // <-- pakai size
            height: size, // <-- pakai size
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Center(
              child: Text(
                '${value.toInt()}°C',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Teks SV kecil
class _SPText extends StatelessWidget {
  final Stream<double> stream;
  const _SPText({Key? key, required this.stream}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: stream,
      builder: (context, snapshot) {
        final sp = snapshot.data?.toStringAsFixed(0) ?? '--';
        return Text("SV: $sp",
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey));
      },
    );
  }
}

/// ====================[  CHART INTERAKTIF BAWAAN (baca Hive) ]====================
class VentFilterChart extends StatefulWidget {
  final int windowSize;
  final String title;
  const VentFilterChart({
    Key? key,
    this.windowSize = 30,
    this.title = 'Graphic Temperature',
  }) : super(key: key);

  @override
  State<VentFilterChart> createState() => _VentFilterChartState();
}

class _VentFilterChartState extends State<VentFilterChart> {
  bool _show201 = true, _show202 = true, _show103 = true;
  late int _win;
  final _windows = const [10, 20, 30, 50];

  @override
  void initState() {
    super.initState();
    _win = widget.windowSize;
  }

  DateTime _parseTs(dynamic ts) {
    if (ts is DateTime) return ts;
    final s = ts?.toString() ?? '';
    for (final f in [
      'dd/MM/yy HH:mm',
      'dd/MM/yyyy HH:mm',
      'yyyy-MM-dd HH:mm:ss'
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

    return ValueListenableBuilder<Box>(
      valueListenable: box.listenable(keys: ['sensorDataList']),
      builder: (context, b, _) {
        final list = (b.get('sensorDataList') as List?) ?? [];
        if (list.isEmpty) {
          return _wrap(
              360, const Center(child: Text('No sensor data available')));
        }

        final total = list.length;
        final start = (total > _win) ? total - _win : 0;

        final tk201 = <FlSpot>[], tk202 = <FlSpot>[], tk103 = <FlSpot>[];
        final labels = <String>[];

        for (int i = start; i < total; i++) {
          final m = Map.from(list[i] as Map);
          final x = (i - start).toDouble();
          final v201 = (m['tk201'] as num?)?.toDouble() ?? 0;
          final v202 = (m['tk202'] as num?)?.toDouble() ?? 0;
          final v103 = (m['tk103'] as num?)?.toDouble() ?? 0;

          tk201.add(FlSpot(x, v201));
          tk202.add(FlSpot(x, v202));
          tk103.add(FlSpot(x, v103));
          labels.add(DateFormat('HH:mm').format(_parseTs(m['timestamp'])));
        }

        //labels
        final allowed = <int>{};
        final n = labels.length;
        final count = (n > 10) ? 5 : n;
        if (n > 0 && count > 0) {
          if (count == 1) {
            allowed.add(0);
          } else {
            final step = (n - 1) / (count - 1);
            for (int k = 0; k < count; k++) {
              final idx = (k * step).round().clamp(0, n - 1);
              allowed.add(idx);
            }
          }
        }

        // autoscale Y + jaga band 65–80 kelihatan
        double minY = 60, maxY = 85;
        final vals = <double>[
          ...tk201.map((e) => e.y),
          ...tk202.map((e) => e.y),
          ...tk103.map((e) => e.y)
        ];
        if (vals.isNotEmpty) {
          final lo = vals.reduce((a, b) => a < b ? a : b);
          final hi = vals.reduce((a, b) => a > b ? a : b);
          minY = (lo - 1 < 60 ? lo - 1 : 60).floorToDouble();
          maxY = (hi + 1 > 85 ? hi + 1 : 85).ceilToDouble();
          if (maxY - minY < 5) maxY = minY + 5;
        }

        final minX = 0.0;
        final maxX =
            (total > _win) ? (_win - 1).toDouble() : (total - 1).toDouble();

        LineChartBarData _line(List<FlSpot> s, Color c) => LineChartBarData(
              spots: s,
              isCurved: true,
              curveSmoothness: 0.25,
              color: c,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            );

        final lines = <LineChartBarData>[
          if (_show201) _line(tk201, const Color(0xFFED4D9B)),
          if (_show202) _line(tk202, const Color(0xFF25D8A8)),
          if (_show103) _line(tk103, const Color(0xFF7A7CCE)),
        ];

        // Tooltip & indikator ikut warna garis
        final lineTouchData = LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 10,
            // tooltipBgColor: Colors.black.withOpacity(0.80),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final lineColor =
                  s.bar.gradient?.colors.first ?? (s.bar.color ?? Colors.black);
              final i = s.x.toInt();
              final t = (i >= 0 && i < labels.length) ? labels[i] : '';
              return LineTooltipItem(
                '$t\n${s.y.toStringAsFixed(1)} °C',
                TextStyle(color: lineColor, fontWeight: FontWeight.bold),
              );
            }).toList(),
          ),
          getTouchedSpotIndicator: (bar, idxs) {
            final lineColor =
                bar.gradient?.colors.first ?? (bar.color ?? Colors.black);
            return idxs
                .map((_) => TouchedSpotIndicatorData(
                      FlLine(
                          color: lineColor.withOpacity(0.6), strokeWidth: 1.5),
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
                    ))
                .toList();
          },
        );

        // chart + judul di dalam (anti label jam kepotong)
        final chartWithTitle = Stack(
          children: [
            Positioned(
              left: 4,
              top: 0,
              child: Text(
                widget.title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 22, right: 8, bottom: 4),
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
                        color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
                    getDrawingVerticalLine: (_) => FlLine(
                        color: Colors.grey.withOpacity(0.10), strokeWidth: 1),
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
                        reservedSize: 30,
                        getTitlesWidget: (v, _) {
                          final i = v.round();
                          if (i < 0 || i >= labels.length)
                            return const SizedBox.shrink();
                          final isFirst = i == 0;
                          final isLast = i == labels.length - 1;
                          return Padding(
                            padding: EdgeInsets.only(
                              top: 6,
                              left: isFirst ? 2 : 0,
                              right: isLast
                                  ? 8
                                  : 0, // <-- ruang ekstra label terakhir
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
                  rangeAnnotations: RangeAnnotations(
                    horizontalRangeAnnotations: [
                      HorizontalRangeAnnotation(
                          y1: 65,
                          y2: 80,
                          color: Colors.green.withOpacity(0.08)),
                    ],
                  ),
                  lineBarsData: lines,
                ),
              ),
            ),
          ],
        );

        return _wrap(
          360,
          Column(
            children: [
              // Header chart: judul kiri + dropdown kanan
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _win,
                        items: _windows
                            .map((w) => DropdownMenuItem(
                                  value: w,
                                  child: Text('$w pts',
                                      style: const TextStyle(fontSize: 12)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _win = v);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Chart (tanpa Stack & Positioned)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: LineChart(
                    LineChartData(
                      minX: minX,
                      maxX: maxX.isNaN ? 0 : maxX,
                      minY: minY,
                      maxY: maxY,
                      clipData: const FlClipData.all(),
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
                              child: Text(
                                v.toInt().toString(),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize:
                                34, // supaya label terakhir gak kepotong
                            interval: 1, // kita filter manual pakai 'allowed'
                            getTitlesWidget: (v, _) {
                              final i = v.round();
                              if (i < 0 || i >= labels.length)
                                return const SizedBox.shrink();
                              if (!allowed.contains(i))
                                return const SizedBox.shrink();

                              final isFirst = i == 0;
                              final isLast = i == labels.length - 1;
                              return Padding(
                                padding: EdgeInsets.only(
                                  top: 6,
                                  left: isFirst ? 2 : 0,
                                  right: isLast
                                      ? 8
                                      : 0, // ruang ekstra label terakhir
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
                      lineTouchData:
                          lineTouchData, // pakai yang sudah kamu set (warna ikut garis)
                      rangeAnnotations: RangeAnnotations(
                        horizontalRangeAnnotations: [
                          HorizontalRangeAnnotation(
                            y1: 65,
                            y2: 80,
                            color: Colors.green.withOpacity(0.08),
                          ),
                        ],
                      ),
                      lineBarsData: lines,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // legend
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _chip('Tk201', const Color(0xFFED4D9B), _show201,
                        () => setState(() => _show201 = !_show201)),
                    _chip('Tk202', const Color(0xFF25D8A8), _show202,
                        () => setState(() => _show202 = !_show202)),
                    _chip('Tk103', const Color(0xFF7A7CCE), _show103,
                        () => setState(() => _show103 = !_show103)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.black87 : Colors.black54)),
        ]),
      ),
    );
  }

  Widget _wrap(double h, Widget child) {
    // mengikuti tampilan kamu sekarang (boxed ala card di dalam)
    return Container(
      height: h,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: child,
    );
  }
}

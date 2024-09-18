import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<FlSpot> _tk201Data = [];
  List<FlSpot> _tk202Data = [];
  List<FlSpot> _tk103Data = [];

  List<String> _timestamps = [];
  int _index = 0;
  late Timer _timer;
  late Box _sensorDataBox;
  final DateFormat formatter = DateFormat('HH:mm');

  int _boilerStatus = 0;
  int _ofdaStatus = 0;
  int _oilessStatus = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _sensorDataBox = Hive.box('sensorDataBox');

    _loadDataFromHive();

    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      _fetchData();
    });

    _fetchData();
  }

  void _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    final dataSnapshot = await _database.child('sensor_data').get();
    if (dataSnapshot.value != null) {
      final data = Map<dynamic, dynamic>.from(dataSnapshot.value as Map);
      final tk201 = data['tk201']?.toDouble() ?? 0;
      final tk202 = data['tk202']?.toDouble() ?? 0;
      final tk103 = data['tk103']?.toDouble() ?? 0;
      final boiler = data['boiler'] ?? 0;
      final ofda = data['ofda'] ?? 0;
      final oiless = data['oiless'] ?? 0;
      final timestamp = DateTime.now();

      setState(() {
        _index++;
        _tk201Data.add(FlSpot(_index.toDouble(), tk201));
        _tk202Data.add(FlSpot(_index.toDouble(), tk202));
        _tk103Data.add(FlSpot(_index.toDouble(), tk103));
        _timestamps.add(formatter.format(timestamp));

        _boilerStatus = boiler;
        _ofdaStatus = ofda;
        _oilessStatus = oiless;

        _isLoading = false;
      });

      _sensorDataBox.put('tk201_$_index', tk201);
      _sensorDataBox.put('tk202_$_index', tk202);
      _sensorDataBox.put('tk103_$_index', tk103);
      _sensorDataBox.put('timestamp_$_index', timestamp.toIso8601String());
      _sensorDataBox.put('boiler', boiler);
      _sensorDataBox.put('ofda', ofda);
      _sensorDataBox.put('oiless', oiless);
    }
  }

  void _loadDataFromHive() {
    for (int i = 1; i <= _sensorDataBox.length ~/ 3; i++) {
      double? temp201 = _sensorDataBox.get('tk201_$i');
      double? temp202 = _sensorDataBox.get('tk202_$i');
      double? temp103 = _sensorDataBox.get('tk103_$i');

      String? time = _sensorDataBox.get('timestamp_$i');
      if (temp201 != null &&
          temp202 != null &&
          temp103 != null &&
          time != null) {
        _tk201Data.add(FlSpot(i.toDouble(), temp201));
        _tk202Data.add(FlSpot(i.toDouble(), temp202));
        _tk103Data.add(FlSpot(i.toDouble(), temp103));
        _timestamps.add(formatter.format(DateTime.parse(time)));
      }
    }
    _index = _sensorDataBox.length ~/ 3;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard Monitoring Utility'),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            ) // Display loading indicator when fetching data
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Outer container for status widgets with background
                    Container(
                      padding: EdgeInsets.all(
                          16.0), // Padding around the status widgets
                      decoration: BoxDecoration(
                        color:
                            Colors.white, // Background color for the container
                        borderRadius:
                            BorderRadius.circular(12.0), // Rounded corners
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Display the status of boiler, ofda, and oiless
                          Container(
                            padding: EdgeInsets.all(
                                8.0), // Padding inside the status container
                            decoration: BoxDecoration(
                              color: Colors
                                  .white, // Background color for status row
                              borderRadius:
                                  BorderRadius.circular(8.0), // Rounded corners
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: _buildStatusWidget(
                                      'Boiler', _boilerStatus),
                                ),
                                SizedBox(width: 8), // Spacing between widgets
                                Expanded(
                                  child:
                                      _buildStatusWidget('OFDA', _ofdaStatus),
                                ),
                                SizedBox(width: 8), // Spacing between widgets
                                Expanded(
                                  child: _buildStatusWidget(
                                      'Oiless', _oilessStatus),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Minimalist divider
                    Container(
                      height: 2, // Thickness of the line
                      width: double
                          .infinity, // Span the width of the parent container
                      color: Colors.grey
                          .withOpacity(0.3), // Light grey color for the line
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Current Temperature",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildCircularValue(
                                  'Tk201',
                                  _tk201Data.isNotEmpty
                                      ? _tk201Data.last.y
                                      : 0),
                              _buildCircularValue(
                                  'Tk202',
                                  _tk202Data.isNotEmpty
                                      ? _tk202Data.last.y
                                      : 0),
                              _buildCircularValue(
                                  'Tk103',
                                  _tk103Data.isNotEmpty
                                      ? _tk103Data.last.y
                                      : 0),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Title and Chart
                    Text(
                      "Graphic Temperature Vent Filter",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    _buildChart(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusWidget(String label, int status) {
    return Container(
      width: 110, // Increased width for better readability
      padding: EdgeInsets.all(10.0),
      // decoration: BoxDecoration(
      //   color: Colors.white,
      //   borderRadius: BorderRadius.circular(12.0),
      //   border: Border.all(
      //     color: Colors.grey.withOpacity(0.3),
      //     width: 1.0,
      //   ),
      //   // boxShadow: [
      //   //   BoxShadow(
      //   //     color: Colors.grey.withOpacity(0.2),
      //   //     spreadRadius: 1,
      //   //     blurRadius: 5,
      //   //     offset: Offset(0, 1),
      //   //   ),
      //   // ],
      // ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status == 1 ? Icons.circle : Icons.cancel,
            color: status == 1 ? Color(0xFF40A578) : Colors.red,
            size: 36,
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return Container(
      height: 300, // Reduced height for a smaller chart container
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            flex: 8,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.5),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.5),
                      strokeWidth: 0.5,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        int idx = value.toInt();
                        if (idx < _timestamps.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 15),
                            child: Text(
                              _timestamps[idx],
                              style:
                                  TextStyle(color: Colors.black, fontSize: 10),
                            ),
                          );
                        } else {
                          return Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(
                              top: 20, left: 10, bottom: 20),
                          child: Text(
                            value.toInt().toString(),
                            style: TextStyle(color: Colors.black, fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.black, width: 1),
                ),
                minX: 0,
                maxX: _index.toDouble(),
                minY: 65,
                maxY: 85,
                lineBarsData: [
                  LineChartBarData(
                    spots: _tk201Data,
                    isCurved: true,
                    barWidth: 2,
                    color: Color(0xFF1E88E5),
                  ),
                  LineChartBarData(
                    spots: _tk202Data,
                    isCurved: true,
                    barWidth: 2,
                    color: Color(0xFF9C27B0),
                  ),
                  LineChartBarData(
                    spots: _tk103Data,
                    isCurved: true,
                    barWidth: 2,
                    color: Color(0xFFC6849B),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegend(color: Color(0xFF1E88E5), label: 'Tk201'),
              _buildLegend(color: Color(0xFF9C27B0), label: 'Tk202'),
              _buildLegend(color: Color(0xFFC6849B), label: 'Tk103'),
            ],
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildValueWidget(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularValue(String label, double value) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.blueAccent, // Ganti warna sesuai kebutuhan
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${value.toInt()}°C',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

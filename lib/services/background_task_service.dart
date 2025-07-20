// ignore_for_file: non_constant_identifier_names, avoid_print

import 'package:firebase_database/firebase_database.dart';
import 'package:hive/hive.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Inisialisasi notifikasi lokal
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class DataService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Stream untuk boiler, chiller, dan ofda
  final StreamController<int> _boilerStreamController = StreamController<int>();
  final StreamController<int> _chillerStreamController =
      StreamController<int>();
  final StreamController<int> _ofdaStreamController = StreamController<int>();
  final StreamController<int> _ufStreamController = StreamController<int>();
  final StreamController<int> _faultPumpStreamController =
      StreamController<int>();
  final StreamController<int> _highSurfaceTankStreamController =
      StreamController<int>();
  final StreamController<int> _lowSurfaceTankStreamController =
      StreamController<int>();

  Stream<int> get ufStream => _ufStreamController.stream;
  Stream<int> get faultPumpStream => _faultPumpStreamController.stream;
  Stream<int> get highSurfaceTankStream =>
      _highSurfaceTankStreamController.stream;
  Stream<int> get lowSurfaceTankStream =>
      _lowSurfaceTankStreamController.stream;
  Stream<int> get boilerStream => _boilerStreamController.stream;
  Stream<int> get chillerStream => _chillerStreamController.stream;
  Stream<int> get ofdaStream => _ofdaStreamController.stream;

  /// Fetch sensor data from Firebase, save to Hive, update streams, and check alarms
  Future<void> fetchData(
    int index,
    List<FlSpot> tk201Data,
    List<FlSpot> tk202Data,
    List<FlSpot> tk103Data,
    List<FlSpot> temp_ahu02lbData,
    List<FlSpot> rh_ahu02lbData,
    List<String> timestamps,
    DateFormat formatter,
    Function(int, int, int, double, double, double, double, double, int, int,
            int, int // Tambahan 4 data baru
            )
        updateCallback,
  ) async {
    try {
      final dataSnapshot = await _database.child('sensor_data').get();
      if (dataSnapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(dataSnapshot.value as Map);
        final tk201 = data['tk201']?.toDouble() ?? 0;
        final tk202 = data['tk202']?.toDouble() ?? 0;
        final tk103 = data['tk103']?.toDouble() ?? 0;
        final temp_ahu02lb = data['temp_ahu02lb']?.toDouble() ?? 0;
        final rh_ahu02lb = data['rh_ahu02lb']?.toDouble() ?? 0;
        final boiler = data['boiler'] ?? 0;
        final ofda = data['ofda'] ?? 0;
        final chiller = data['chiller'] ?? 0;
        final uf = data['UF'] ?? 0;
        final faultPump = data['fault_pump'] ?? 0;
        final highSurfaceTank = data['high_surface_tank'] ?? 0;
        final lowSurfaceTank = data['low_surface_tank'] ?? 0;
        final timestamp = DateTime.now();

        await _saveToHive(
            tk201,
            tk202,
            tk103,
            temp_ahu02lb,
            rh_ahu02lb,
            boiler,
            ofda,
            chiller,
            uf,
            faultPump,
            highSurfaceTank,
            lowSurfaceTank,
            timestamp);

        updateCallback(
            boiler.toInt(),
            chiller.toInt(),
            ofda.toInt(),
            tk201,
            tk202,
            tk103,
            temp_ahu02lb,
            rh_ahu02lb,
            uf,
            faultPump,
            highSurfaceTank,
            lowSurfaceTank);

        _boilerStreamController.add(boiler.toInt());
        _chillerStreamController.add(chiller.toInt());
        _ofdaStreamController.add(ofda.toInt());
        _ufStreamController.add(uf.toInt());
        _faultPumpStreamController.add(faultPump.toInt());
        _highSurfaceTankStreamController.add(highSurfaceTank.toInt());
        _lowSurfaceTankStreamController.add(lowSurfaceTank.toInt());

        await checkAlarmCondition(
          tk201: tk201,
          tk202: tk202,
          tk103: tk103,
          boiler: boiler,
          ofda: ofda,
          chiller: chiller,
          tempAhu: temp_ahu02lb,
          uf: uf,
          faultPump: faultPump,
          highSurfaceTank: highSurfaceTank,
          lowSurfaceTank: lowSurfaceTank,
        );
      }
    } catch (e) {
      print("Error fetching data from Firebase: $e");
    }
  }

  Future<void> _saveToHive(
    double tk201,
    double tk202,
    double tk103,
    double temp_ahu02lb,
    double rh_ahu02lb,
    int boiler,
    int ofda,
    int chiller,
    int uf,
    int faultPump,
    int highSurfaceTank,
    int lowSurfaceTank,
    DateTime timestamp,
  ) async {
    final formatter = DateFormat('dd/MM/yy HH:mm');
    final formattedTimestamp = formatter.format(timestamp);
    final sensorDataBox = await Hive.openBox('sensorDataBox');

    List<dynamic> sensorDataList =
        sensorDataBox.get('sensorDataList', defaultValue: []);
    final sensorData = {
      'tk201': tk201,
      'tk202': tk202,
      'tk103': tk103,
      'temp_ahu02lb': temp_ahu02lb,
      'rh_ahu02lb': rh_ahu02lb,
      'timestamp': formattedTimestamp,
      'uf': uf,
      'fault_pump': faultPump,
      'high_surface_tank': highSurfaceTank,
      'low_surface_tank': lowSurfaceTank,
    };
    sensorDataList.add(sensorData);
    await sensorDataBox.put('sensorDataList', sensorDataList);

    final sensorStatus = {
      'boiler': boiler,
      'ofda': ofda,
      'chiller': chiller,
      'tk201': tk201,
      'tk202': tk202,
      'tk103': tk103,
      'temp_ahu02lb': temp_ahu02lb,
      'rh_ahu02lb': rh_ahu02lb,
      'timestamp': formattedTimestamp,
      'uf': uf,
      'fault_pump': faultPump,
      'high_surface_tank': highSurfaceTank,
      'low_surface_tank': lowSurfaceTank,
    };
    await sensorDataBox.put('sensorStatus', sensorStatus);

    print("Data sensor disimpan ke Hive");
  }

  // Jangan lupa untuk menutup stream controller saat tidak digunakan
  void dispose() {
    _boilerStreamController.close();
    _chillerStreamController.close();
    _ofdaStreamController.close();
  }

  Future<void> loadInitialData(
    Function(int, int, int, double, double, double, double, double, int, int,
            int, int)
        updateCallback,
  ) async {
    final sensorDataBox = await Hive.openBox('sensorDataBox');
    final sensorStatus = sensorDataBox.get('sensorStatus');
    if (sensorStatus != null) {
      updateCallback(
        sensorStatus['boiler'] ?? 0,
        sensorStatus['chiller'] ?? 0,
        sensorStatus['ofda'] ?? 0,
        sensorStatus['tk201']?.toDouble() ?? 0.0,
        sensorStatus['tk202']?.toDouble() ?? 0.0,
        sensorStatus['tk103']?.toDouble() ?? 0.0,
        sensorStatus['temp_ahu02lb']?.toDouble() ?? 0.0,
        sensorStatus['rh_ahu02lb']?.toDouble() ?? 0.0,
        sensorStatus['uf'] ?? 0,
        sensorStatus['fault_pump'] ?? 0,
        sensorStatus['high_surface_tank'] ?? 0,
        sensorStatus['low_surface_tank'] ?? 0,
      );
      _boilerStreamController.add(sensorStatus['boiler'] ?? 0);
      _chillerStreamController.add(sensorStatus['chiller'] ?? 0);
      _ofdaStreamController.add(sensorStatus['ofda'] ?? 0);
      _ufStreamController.add(sensorStatus['uf'] ?? 0);
      _faultPumpStreamController.add(sensorStatus['fault_pump'] ?? 0);
      _highSurfaceTankStreamController
          .add(sensorStatus['high_surface_tank'] ?? 0);
      _lowSurfaceTankStreamController
          .add(sensorStatus['low_surface_tank'] ?? 0);

      print("Data awal diambil dari Hive dan ditampilkan");
    } else {
      print("Data awal tidak ditemukan di Hive.");
    }
  }

  Future<void> sendAlarmNotification(String message) async {
    print("Sending alarm notification: $message");
    const androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      'Sensor Alarm',
      channelDescription: 'Alarm when sensor data is out of range',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('classicalarm'),
      ticker: 'Sensor Alarm',
      playSound: true,
    );
    const platformDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      0,
      'Sensor Alarm',
      message,
      platformDetails,
    );
  }

  /// Check all alarm conditions and send notification if needed
  Future<void> checkAlarmCondition({
    required double tk201,
    required double tk202,
    required double tk103,
    required int boiler,
    required int ofda,
    required int chiller,
    required double tempAhu,
    required int uf,
    required int faultPump,
    required int highSurfaceTank,
    required int lowSurfaceTank,
  }) async {
    final box = Hive.box('alarmHistoryBox');
    SharedPreferences prefs = await SharedPreferences.getInstance();

    final List<_AlarmRule> alarmRules = [
      _AlarmRule(
        enabled: prefs.getBool("task1") ?? false,
        condition: () => boiler == 0,
        message: "Warning: Boiler System Abnormal",
        name: "boiler",
        value: boiler,
      ),
      _AlarmRule(
        enabled: prefs.getBool("task2") ?? false,
        condition: () => ofda == 0,
        message: "Warning: OFDA System Abnormal",
        name: "ofda",
        value: ofda,
      ),
      _AlarmRule(
        enabled: prefs.getBool("task3") ?? false,
        condition: () => chiller == 0,
        message: "Warning: Chiller System Abnormal",
        name: "chiller",
        value: chiller,
      ),
      _AlarmRule(
        enabled: prefs.getBool("task4") ?? false,
        condition: () => tk201 < 65 || tk201 > 80,
        message: "Warning: tk201 out of range: $tk201",
        name: "tk201",
        value: tk201,
      ),
      _AlarmRule(
        enabled: prefs.getBool("task5") ?? false,
        condition: () => tk202 < 65 || tk202 > 80,
        message: "Warning: tk202 out of range: $tk202",
        name: "tk202",
        value: tk202,
      ),
      _AlarmRule(
        enabled: prefs.getBool("task6") ?? false,
        condition: () => tk103 < 65 || tk103 > 80,
        message: "Warning: tk103 out of range: $tk103",
        name: "tk103",
        value: tk103,
      ),
      _AlarmRule(
        enabled: prefs.getBool("task7") ?? false,
        condition: () => tempAhu < 18 || tempAhu > 27,
        message: "Warning: Temperature Ahu 02 out of range: $tempAhu",
        name: "Ahu 02 LB",
        value: tempAhu,
      ),
      _AlarmRule(
        enabled: prefs.getBool("task8") ?? false,
        condition: () => uf == 0,
        message: "Warning: UF System Abnormal",
        name: "uf",
        value: uf,
      ),
      _AlarmRule(
        enabled: prefs.getBool("task9") ?? false,
        condition: () => faultPump == 1, // contoh: fault aktif jika 1
        message: "Warning: Fault Pump Detected",
        name: "fault_pump",
        value: faultPump,
      ),
      _AlarmRule(
        enabled: prefs.getBool("task10") ?? false,
        condition: () => lowSurfaceTank == 1,
        message: "Warning: Low Surface Tank Detected",
        name: "low_surface_tank",
        value: lowSurfaceTank,
      ),
    ];

    for (final rule in alarmRules) {
      if (rule.enabled && rule.condition()) {
        await sendAlarmNotification(rule.message);
        box.add({
          'timestamp': DateTime.now(),
          'alarmName': rule.name,
          'sensorValue': rule.value,
        });
      }
    }
    print("Data terbaru di alarmHistoryBox: ${box.values.toList()}");
  }
}

/// Simple alarm rule class for cleaner alarm logic
class _AlarmRule {
  final bool enabled;
  final bool Function() condition;
  final String message;
  final String name;
  final dynamic value;

  _AlarmRule({
    required this.enabled,
    required this.condition,
    required this.message,
    required this.name,
    required this.value,
  });
}

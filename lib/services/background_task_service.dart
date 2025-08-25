import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

// Inisialisasi notifikasi lokal
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;

  late final StreamSubscription<DatabaseEvent> _sensorSubscription;
  final ValueNotifier<double?> m800Toc = ValueNotifier<double?>(null);
  final ValueNotifier<double?> m800Temp = ValueNotifier<double?>(null);
  final ValueNotifier<double?> m800Conduct = ValueNotifier<double?>(null);
  final ValueNotifier<int?> m800Lamp = ValueNotifier<int?>(null);

  DataService._internal() {
    _sensorSubscription = _sensorRef.onValue.listen((event) {
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);

      final boiler = data['boiler'] ?? 0;
      final chiller = data['chiller'] ?? 0;
      final ofda = data['ofda'] ?? 0;
      final uf = data['UF'] ?? 0;
      final faultPump = data['fault_pump'] ?? 0;
      final highSurfaceTank = data['high_surface_tank'] ?? 0;
      final lowSurfaceTank = data['low_surface_tank'] ?? 0;

      _boilerStreamController.add(boiler);
      _chillerStreamController.add(chiller);
      _ofdaStreamController.add(ofda);
      _ufStreamController.add(uf);
      _faultPumpStreamController.add(faultPump);
      _highSurfaceTankStreamController.add(highSurfaceTank);
      _lowSurfaceTankStreamController.add(lowSurfaceTank);
    });
  }

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final DatabaseReference _sensorRef =
      FirebaseDatabase.instance.ref('sensor_data');

  // Stream Controller
  final _boilerStreamController = StreamController<int>.broadcast();
  final _chillerStreamController = StreamController<int>.broadcast();
  final _ofdaStreamController = StreamController<int>.broadcast();
  final _ufStreamController = StreamController<int>.broadcast();
  final _faultPumpStreamController = StreamController<int>.broadcast();
  final _highSurfaceTankStreamController = StreamController<int>.broadcast();
  final _lowSurfaceTankStreamController = StreamController<int>.broadcast();

  // Stream getter
  Stream<int> get boilerStream => _boilerStreamController.stream;
  Stream<int> get chillerStream => _chillerStreamController.stream;
  Stream<int> get ofdaStream => _ofdaStreamController.stream;
  Stream<int> get ufStream => _ufStreamController.stream;
  Stream<int> get faultPumpStream => _faultPumpStreamController.stream;
  Stream<int> get highSurfaceTankStream =>
      _highSurfaceTankStreamController.stream;
  Stream<int> get lowSurfaceTankStream =>
      _lowSurfaceTankStreamController.stream;

  void dispose() {
    _sensorSubscription.cancel();
    _boilerStreamController.close();
    _chillerStreamController.close();
    _ofdaStreamController.close();
    _ufStreamController.close();
    _faultPumpStreamController.close();
    _highSurfaceTankStreamController.close();
    _lowSurfaceTankStreamController.close();
  }

  Future<void> fetchData(
    int index,
    List<FlSpot> tk201Data,
    List<FlSpot> tk202Data,
    List<FlSpot> tk103Data,
    List<FlSpot> temp_ahu04lbData,
    List<FlSpot> rh_ahu04lbData,
    List<String> timestamps,
    DateFormat formatter,
    Function(
      int,
      int,
      int,
      double,
      double,
      double,
      double,
      double,
      int,
      int,
      int,
      int,
    ) updateCallback,
  ) async {
    try {
      final dataSnapshot = await _database.child('sensor_data').get();
      if (dataSnapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(dataSnapshot.value as Map);

        final tk201 =
            (data['tk201'] is num) ? (data['tk201'] as num).toDouble() : 0.0;
        final tk202 =
            (data['tk202'] is num) ? (data['tk202'] as num).toDouble() : 0.0;
        final tk103 =
            (data['tk103'] is num) ? (data['tk103'] as num).toDouble() : 0.0;

        final temp_ahu04lb = (data['temp_ahu04lb'] is num)
            ? (data['temp_ahu04lb'] as num).toDouble()
            : 0.0;
        final rh_ahu04lb = (data['rh_ahu04lb'] is num)
            ? (data['rh_ahu04lb'] as num).toDouble()
            : 0.0;

        // ====== M800 ======
        final m800_toc = (data['m800_toc'] is num)
            ? (data['m800_toc'] as num).toDouble()
            : 0.0;
        final m800_temp = (data['m800_temp'] is num)
            ? (data['m800_temp'] as num).toDouble()
            : 0.0;
        final m800_conduct = (data['m800_conduct'] is num)
            ? (data['m800_conduct'] as num).toDouble()
            : 0.0;
        final m800_lamp =
            (data['m800_lamp'] is num) ? (data['m800_lamp'] as num).toInt() : 0;

        final boiler = data['boiler'] ?? 0;
        final ofda = data['ofda'] ?? 0;
        final chiller = data['chiller'] ?? 0;
        final uf = data['UF'] ?? 0;
        final faultPump = data['fault_pump'] ?? 0;
        final highSurfaceTank = data['high_surface_tank'] ?? 0;
        final lowSurfaceTank = data['low_surface_tank'] ?? 0;

        final timestamp = DateTime.now();
        // update latest (buat UI)
        m800Toc.value = m800_toc;
        m800Temp.value = m800_temp;
        m800Conduct.value = m800_conduct;
        m800Lamp.value = m800_lamp;

        // simpan histori (toc/temp/conduct saja) — rolling window
        await _appendHistory('m800_toc_history', m800_toc, timestamp);
        await _appendHistory('m800_temp_history', m800_temp, timestamp);
        await _appendHistory('m800_conduct_history', m800_conduct, timestamp);

        await _saveToHive(
          tk201,
          tk202,
          tk103,
          temp_ahu04lb,
          rh_ahu04lb,
          boiler,
          ofda,
          chiller,
          uf,
          faultPump,
          highSurfaceTank,
          lowSurfaceTank,
          timestamp,
          m800_toc: m800_toc,
          m800_temp: m800_temp,
          m800_conduct: m800_conduct,
          m800_lamp: m800_lamp,
        );

        updateCallback(
          boiler.toInt(),
          chiller.toInt(),
          ofda.toInt(),
          tk201,
          tk202,
          tk103,
          temp_ahu04lb,
          rh_ahu04lb,
          uf,
          faultPump,
          highSurfaceTank,
          lowSurfaceTank,
        );

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
          tempAhu: temp_ahu04lb,
          rhAhu: rh_ahu04lb,
          uf: uf,
          faultPump: faultPump,
          highSurfaceTank: highSurfaceTank,
          lowSurfaceTank: lowSurfaceTank,
          m800Toc: m800_toc,
          m800Temp: m800_temp,
          m800Conduct: m800_conduct,
          m800Lamp: m800_lamp,
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
      double temp_ahu04lb,
      double rh_ahu04lb,
      int boiler,
      int ofda,
      int chiller,
      int uf,
      int faultPump,
      int highSurfaceTank,
      int lowSurfaceTank,
      DateTime timestamp,
      {double? m800_toc,
      double? m800_temp,
      double? m800_conduct,
      int? m800_lamp}) async {
    final formatter = DateFormat('dd/MM/yy HH:mm');
    final formattedTimestamp = formatter.format(timestamp);
    final sensorDataBox = await Hive.openBox('sensorDataBox');

    List<dynamic> sensorDataList =
        sensorDataBox.get('sensorDataList', defaultValue: []);
    final sensorData = {
      'tk201': tk201,
      'tk202': tk202,
      'tk103': tk103,
      'temp_ahu04lb': temp_ahu04lb,
      'rh_ahu04lb': rh_ahu04lb,
      'timestamp': formattedTimestamp,
      'uf': uf,
      'fault_pump': faultPump,
      'high_surface_tank': highSurfaceTank,
      'low_surface_tank': lowSurfaceTank,
      if (m800_toc != null) 'm800_toc': m800_toc,
      if (m800_temp != null) 'm800_temp': m800_temp,
      if (m800_conduct != null) 'm800_conduct': m800_conduct,
      if (m800_lamp != null) 'm800_lamp': m800_lamp,
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
      'temp_ahu04lb': temp_ahu04lb,
      'rh_ahu04lb': rh_ahu04lb,
      'timestamp': formattedTimestamp,
      'uf': uf,
      'fault_pump': faultPump,
      'high_surface_tank': highSurfaceTank,
      'low_surface_tank': lowSurfaceTank,
      if (m800_toc != null) 'm800_toc': m800_toc,
      if (m800_temp != null) 'm800_temp': m800_temp,
      if (m800_conduct != null) 'm800_conduct': m800_conduct,
      if (m800_lamp != null) 'm800_lamp': m800_lamp,
    };
    await sensorDataBox.put('sensorStatus', sensorStatus);

    print("Data sensor disimpan ke Hive");
  }

  Future<void> _appendHistory(String boxName, double value, DateTime t) async {
    final box = await Hive.openBox(boxName);
    await box.add({'t': t.millisecondsSinceEpoch, 'v': value});
    // rolling window 500
    const maxPoints = 500;
    if (box.length > maxPoints) {
      final over = box.length - maxPoints;
      for (int i = 0; i < over; i++) {
        await box.deleteAt(0);
      }
    }
  }

  Future<void> loadInitialData(
    Function(
      int,
      int,
      int,
      double,
      double,
      double,
      double,
      double,
      int,
      int,
      int,
      int,
    ) updateCallback,
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
        sensorStatus['temp_ahu04lb']?.toDouble() ?? 0.0,
        sensorStatus['rh_ahu04lb']?.toDouble() ?? 0.0,
        sensorStatus['uf'] ?? 0,
        sensorStatus['fault_pump'] ?? 0,
        sensorStatus['high_surface_tank'] ?? 0,
        sensorStatus['low_surface_tank'] ?? 0,
      );
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

  Future<void> checkAlarmCondition({
    required double tk201,
    required double tk202,
    required double tk103,
    required int boiler,
    required int ofda,
    required int chiller,
    required double tempAhu,
    required double rhAhu,
    required int uf,
    required int faultPump,
    required int highSurfaceTank,
    required int lowSurfaceTank,
    required double m800Toc,
    required double m800Temp,
    required double m800Conduct,
    required int m800Lamp,
  }) async {
    final box = await Hive.openBox('alarmHistoryBox');
    final prefs = await SharedPreferences.getInstance();

    final List<_AlarmRule> alarmRules = [
      _AlarmRule(
        enabled: prefs.getBool("task1") ?? false,
        condition: () => boiler == 1,
        message: "Warning: Boiler System Abnormal",
        name: "Boiler System Abnormal",
        value: boiler,
      ),
      _AlarmRule(
        enabled: prefs.getBool("task2") ?? false,
        condition: () => ofda == 1,
        message: "Warning: OFDA System Abnormal",
        name: "OFDA System Abnormal",
        value: ofda,
      ),
      _AlarmRule(
        enabled: prefs.getBool("task3") ?? false,
        condition: () => chiller == 0,
        message: "Warning: Chiller System Abnormal",
        name: "Chiller System Abnormal",
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
        condition: () =>
            tempAhu < 18 || tempAhu > 27 || rhAhu < 40 || rhAhu > 60,
        message:
            "Warning: Ahu 04 out of range: Temperature $tempAhu, Humidity $rhAhu",
        name: "Ahu 04 LB",
        value: {'tempAhu': tempAhu, 'rhAhu': rhAhu},
      ),
      _AlarmRule(
        enabled: prefs.getBool("task8") ?? false,
        condition: () => uf == 1,
        message: "Warning: UF System Abnormal",
        name: "UF System Abnormal",
        value: uf,
      ),
      _AlarmRule(
        enabled: prefs.getBool("task9") ?? false,
        condition: () => faultPump == 1,
        message: "Warning: Fault Pump Detected",
        name: "Fault Domestic Pump",
        value: faultPump,
      ),
      _AlarmRule(
        enabled: prefs.getBool("task10") ?? false,
        condition: () => lowSurfaceTank == 1,
        message: "Warning: Low Surface Tank Detected",
        name: "Low Domestic Tank",
        value: lowSurfaceTank,
      ),
      _AlarmRule(
        enabled: prefs.getBool("task10") ?? false,
        condition: () => lowSurfaceTank == 1,
        message: "Warning: Low Surface Tank Detected",
        name: "Low Domestic Tank",
        value: lowSurfaceTank,
      ),
      _AlarmRule(
        enabled: prefs.getBool("task11") ?? false,
        condition: () =>
            (m800Temp > 35.0) ||
            (m800Toc > 100.0) ||
            (m800Conduct > 1.2) ||
            (m800Lamp == 0),
        message: "Warning: M800 out of range",
        name: "M800 Out of Range",
        value: {
          if (m800Temp > 35.0) 'temp': m800Temp,
          if (m800Toc > 100.0) 'toc': m800Toc,
          if (m800Conduct > 1.2) 'conduct': m800Conduct,
          if (m800Lamp == 0) 'lamp': m800Lamp,
        },
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
        await box.flush();

        FlutterBackgroundService().invoke('alarm_update');
      }
    }

    print("Data terbaru di alarmHistoryBox: ${box.values.toList()}");
  }
}

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

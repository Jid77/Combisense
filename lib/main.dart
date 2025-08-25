import 'dart:async';
import 'package:combisense/app.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:combisense/services/background_task_service.dart'; // Import background task service
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

double tk201 = 0;
double tk202 = 0;
double tk103 = 0;
int boiler = 0;
int ofda = 0;
int chiller = 0;
double temp_ahu04lb = 0;
double p_ofda = 0;
int uf = 0;
int faultPump = 0;
int highSurfaceTank = 0;
int lowSurfaceTank = 0;

Timer? _bgTimer5m;
int _tick5m = 0; // 0,1,2,3,... untuk nentuin kapan 10 menit

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (details) {
    return Material(
      child: Center(
        child: Text(
          'Terjadi error.\n${details.exceptionAsString()}',
          textAlign: TextAlign.center,
        ),
      ),
    );
  };
  await Firebase.initializeApp();

  await Hive.initFlutter();
  await Hive.openBox('sensorDataBox');
  await Hive.openBox('alarmHistoryBox');
  await Hive.openBox('settingsBox');

  await Hive.openBox('m800_toc_history');
  await Hive.openBox('m800_temp_history');
  await Hive.openBox('m800_conduct_history');

  await requestNotificationPermission();

  await initializeService();

  runZonedGuarded(() {
    runApp(MyApp());
  }, (error, stack) {
    print("Uncaught Flutter error: $error");
  });
}

// Fungsi untuk meminta izin notifikasi
Future<void> requestNotificationPermission() async {
  var status = await Permission.notification.status;

  if (!status.isGranted) {
    await Permission.notification.request();

    if (await Permission.notification.isGranted) {
      print("Izin notifikasi diberikan!");
    } else {
      print("Izin notifikasi ditolak.");
    }
  } else {
    print("Izin notifikasi sudah diberikan.");
  }
}

// inisialisasi background service
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: (_) => false,
    ),
  );

  service.startService();
}

// Fungsi yang akan dijalankan saat background service dimulai
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  try {
    await Hive.initFlutter();
    await Hive.openBox('sensorDataBox');
    await Hive.openBox('alarmHistoryBox');
    await Hive.openBox('m800_toc_history');
    await Hive.openBox('m800_temp_history');
    await Hive.openBox('m800_conduct_history');
  } catch (e) {
    print("Error opening Hive box: $e");
  }
  print("Background service started");

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  flutterLocalNotificationsPlugin.initialize(initializationSettings);

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Combisense",
      content: "Combisense Running in Background",
    );
  }

  // Jalankan fetch sekali saat start (biar ada data awal)
  try {
    await executeFetchData();
  } catch (e) {
    print("Initial executeFetchData error: $e");
  }

  // Pastikan gak dobel timer
  _bgTimer5m?.cancel();
  _tick5m = 0;

  // === SATU TIMER, 5 MENIT SEKALI ===
  _bgTimer5m = Timer.periodic(const Duration(minutes: 5), (timer) async {
    if (service is AndroidServiceInstance) {
      final isFg = await service.isForegroundService();
      if (!isFg) return;
    }

    _tick5m++;

    // 1) Cek alarm subset SELALU tiap 5 menit (pakai snapshot terakhir di Hive)
    try {
      await executeQuickAlarmCheck();
    } catch (e) {
      print("executeQuickAlarmCheck error: $e");
    }

    // 2) Setiap 2 tick (≈10 menit), sekalian fetch data
    if (_tick5m % 2 == 0) {
      print("5m timer: tick=$_tick5m → RUN FETCH (10m cadence)");
      try {
        await executeFetchData();
      } catch (e) {
        print("Periodic executeFetchData error: $e");
      }
    } else {
      print("5m timer: tick=$_tick5m → quick alarm only");
    }
  });

  // Listen for data sent from the UI
  SharedPreferences prefs = await SharedPreferences.getInstance();
  service.on('updateData').listen((event) async {
    if (event == null) return;
    if (event["task1"] != null) await prefs.setBool("task1", event["task1"]);
    if (event["task2"] != null) await prefs.setBool("task2", event["task2"]);
    if (event["task3"] != null) await prefs.setBool("task3", event["task3"]);
    if (event["task4"] != null) await prefs.setBool("task4", event["task4"]);
    if (event["task5"] != null) await prefs.setBool("task5", event["task5"]);
    if (event["task6"] != null) await prefs.setBool("task6", event["task6"]);
    if (event["task7"] != null) await prefs.setBool("task7", event["task7"]);
    if (event["task8"] != null) await prefs.setBool("task8", event["task8"]);
    if (event["task9"] != null) await prefs.setBool("task9", event["task9"]);
    if (event["task10"] != null) await prefs.setBool("task10", event["task10"]);
    if (event["task11"] != null) await prefs.setBool("task11", event["task11"]);
  });
}

// Fungsi untuk menjalankan fetchData dari DataService
Future<void> executeFetchData() async {
  final dataService = DataService();
  List<FlSpot> tk201Data = [];
  List<FlSpot> tk202Data = [];
  List<FlSpot> tk103Data = [];
  List<FlSpot> temp_ahu04lbData = [];
  List<FlSpot> p_ofdaData = [];
  List<String> timestamps = [];
  DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');

  // Callback untuk update data setelah fetch
  void updateCallback(
    int newBoiler,
    int newChiller,
    int newOfda,
    double newTk201,
    double newTk202,
    double newTk103,
    double newTemp_ahu04lb,
    double newP_ofda,
    int newUf,
    int newFaultPump,
    int newHighSurfaceTank,
    int newLowSurfaceTank,
  ) {
    // Simpan data yang diperoleh dari fetchData
    boiler = newBoiler;
    chiller = newChiller;
    ofda = newOfda;
    tk201 = newTk201;
    tk202 = newTk202;
    tk103 = newTk103;
    temp_ahu04lb = newTemp_ahu04lb;
    p_ofda = newP_ofda;
    uf = newUf;
    faultPump = newFaultPump;
    highSurfaceTank = newHighSurfaceTank;
    lowSurfaceTank = newLowSurfaceTank;

    print(
        "Data : Boiler: $boiler, Chiller: $chiller, OFDA: $ofda, TK201: $tk201, TK202: $tk202, TK103: $tk103, temp_ahu04lb : $temp_ahu04lb, PressureOfda : $p_ofda, UF: $uf, FaultPump: $faultPump, HighSurfaceTank: $highSurfaceTank, LowSurfaceTank: $lowSurfaceTank");
  }

  // Panggil fetchData dengan parameter baru
  await dataService.fetchData(
    0,
    tk201Data,
    tk202Data,
    tk103Data,
    temp_ahu04lbData,
    p_ofdaData,
    timestamps,
    formatter,
    updateCallback,
  );
}

/// Quick alarm check tiap 5 menit (tanpa re-fetch):
Future<void> executeQuickAlarmCheck() async {
  try {
    final sensorDataBox = await Hive.openBox('sensorDataBox');
    final sensorStatus = sensorDataBox.get('sensorStatus');

    if (sensorStatus == null) {
      print("QuickAlarm: sensorStatus not found, skip.");
      return;
    }

    // Ambil nilai terakhir dengan aman
    final int boiler = (sensorStatus['boiler'] as num?)?.toInt() ?? 0;
    final int ofda = (sensorStatus['ofda'] as num?)?.toInt() ?? 0;
    final int uf = (sensorStatus['uf'] as num?)?.toInt() ?? 0;
    final int chiller = (sensorStatus['chiller'] as num?)?.toInt() ?? 0;
    final int faultPump = (sensorStatus['fault_pump'] as num?)?.toInt() ?? 0;
    final int lowTank =
        (sensorStatus['low_surface_tank'] as num?)?.toInt() ?? 0;

    final prefs = await SharedPreferences.getInstance();
    final box = await Hive.openBox('alarmHistoryBox');

    // Helper kirim notif cepat (pakai channel yang sama)
    Future<void> _sendQuick(String message, String name, dynamic value) async {
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

      final id = DateTime.now().millisecondsSinceEpoch % 100000;
      await flutterLocalNotificationsPlugin.show(
        id,
        'Sensor Alarm',
        message,
        platformDetails,
      );
      await box.add({
        'timestamp': DateTime.now(),
        'alarmName': name,
        'sensorValue': value,
      });
      await box.flush(); // <-- penting, commit ke disk
      FlutterBackgroundService().invoke('alarm_update');
    }

    // Rules subset
    if ((prefs.getBool("task1") ?? false) && boiler == 1) {
      await _sendQuick(
          "Warning: Boiler System Abnormal", "Boiler System Abnormal", boiler);
    }
    if ((prefs.getBool("task2") ?? false) && ofda == 1) {
      await _sendQuick(
          "Warning: OFDA System Abnormal", "OFDA System Abnormal", ofda);
    }
    if ((prefs.getBool("task3") ?? false) && chiller == 0) {
      await _sendQuick("Warning: Chiller System Abnormal",
          "Chiller System Abnormal", chiller);
    }
    if ((prefs.getBool("task8") ?? false) && uf == 1) {
      await _sendQuick("Warning: UF System Abnormal", "UF System abnormal", uf);
    }
    if ((prefs.getBool("task9") ?? false) && faultPump == 1) {
      await _sendQuick(
          "Warning: Fault Domestic Pump", "Fault Domestic Pump", faultPump);
    }
    if ((prefs.getBool("task10") ?? false) && lowTank == 1) {
      await _sendQuick(
          "Warning: Low Surface Tank Detected", "Low Domestic Tank", lowTank);
    }
  } catch (e) {
    print("executeQuickAlarmCheck error: $e");
  }
}

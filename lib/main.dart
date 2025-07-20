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

// Variabel global untuk menyimpan data sensor
double tk201 = 0;
double tk202 = 0;
double tk103 = 0;
int boiler = 0;
int ofda = 0;
int chiller = 0;
double temp_ahu02lb = 0;
double p_ofda = 0;
// Tambahkan variabel global jika ingin akses di file lain
int uf = 0;
int faultPump = 0;
int highSurfaceTank = 0;
int lowSurfaceTank = 0;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase
  await Firebase.initializeApp();

  // Inisialisasi Hive
  await Hive.initFlutter();
  await Hive.openBox('sensorDataBox');
  await Hive.openBox('alarmHistoryBox');
  await Hive.openBox('settingsBox');

  await requestNotificationPermission();

  await initializeService();

  runApp(MyApp());
}

// Fungsi untuk meminta izin notifikasi
Future<void> requestNotificationPermission() async {
  var status = await Permission.notification.status;

  if (!status.isGranted) {
    // Meminta izin notifikasi
    await Permission.notification.request();

    // Mengecek kembali status izin setelah permintaan
    if (await Permission.notification.isGranted) {
      print("Izin notifikasi diberikan!");
    } else {
      print("Izin notifikasi ditolak.");
    }
  } else {
    print("Izin notifikasi sudah diberikan.");
  }
}

// Fungsi untuk inisialisasi background service
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart, // Panggil fungsi `onStart` untuk Android
      isForegroundMode: true, // Menjalankan sebagai foreground service
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart, // Panggil fungsi `onStart` untuk iOS (foreground)
      onBackground: (_) =>
          false, // Layanan latar belakang tidak didukung di iOS
    ),
  );

  // Mulai layanan
  service.startService();
}

// Fungsi yang akan dijalankan saat background service dimulai
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Periksa apakah Firebase sudah diinisialisasi
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  // Buka box Hive yang diperlukan
  try {
    await Hive.initFlutter();
    await Hive.openBox('sensorDataBox');
    await Hive.openBox('alarmHistoryBox');
  } catch (e) {
    print("Error opening Hive box: $e");
  }
  print("Background service started");

  // Inisialisasi notifikasi Android
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  flutterLocalNotificationsPlugin.initialize(initializationSettings);

  if (service is AndroidServiceInstance) {
    // Set notifikasi foreground
    service.setForegroundNotificationInfo(
      title: "Background Service",
      content: "Running background time",
    );
  }
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Interval untuk menjalankan background task
  Timer.periodic(const Duration(minutes: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        print("Running periodic background task");
        await executeFetchData();
      }
    }
  });
  // Listen for data sent from the UI
  service.on('updateData').listen((event) async {
    if (event!["task1"] != null) {
      await prefs.setBool("task1", event["task1"]);
    }
    if (event["task2"] != null) {
      await prefs.setBool("task2", event["task2"]);
    }
    if (event["task3"] != null) {
      await prefs.setBool("task3", event["task3"]);
    }
    if (event["task4"] != null) {
      await prefs.setBool("task4", event["task4"]);
    }
    if (event["task5"] != null) {
      await prefs.setBool("task5", event["task5"]);
    }
    if (event["task6"] != null) {
      await prefs.setBool("task6", event["task6"]);
    }
    if (event["task7"] != null) {
      await prefs.setBool("task7", event["task7"]);
    }
  });
}

// Fungsi untuk menjalankan fetchData dari DataService
Future<void> executeFetchData() async {
  final dataService = DataService();
  List<FlSpot> tk201Data = [];
  List<FlSpot> tk202Data = [];
  List<FlSpot> tk103Data = [];
  List<FlSpot> temp_ahu02lbData = [];
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
    double newTemp_ahu02lb,
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
    temp_ahu02lb = newTemp_ahu02lb;
    p_ofda = newP_ofda;
    uf = newUf;
    faultPump = newFaultPump;
    highSurfaceTank = newHighSurfaceTank;
    lowSurfaceTank = newLowSurfaceTank;

    print(
        "Data : Boiler: $boiler, Chiller: $chiller, OFDA: $ofda, TK201: $tk201, TK202: $tk202, TK103: $tk103, temp_ahu02lb : $temp_ahu02lb, PressureOfda : $p_ofda, UF: $uf, FaultPump: $faultPump, HighSurfaceTank: $highSurfaceTank, LowSurfaceTank: $lowSurfaceTank");
  }

  // Panggil fetchData dengan parameter baru
  await dataService.fetchData(
    0,
    tk201Data,
    tk202Data,
    tk103Data,
    temp_ahu02lbData,
    p_ofdaData,
    timestamps,
    formatter,
    updateCallback,
  );
}

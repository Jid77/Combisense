import 'dart:async';
import 'dart:ffi';
import 'package:aplikasitest1/app.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:aplikasitest1/services/background_task_service.dart'; // Import background task service
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:aplikasitest1/pages/home_page.dart';
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
int oiless = 0;
double pwg = 0;
double p_ofda = 0;

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

  // Inisialisasi background service
  await initializeService();

  // Jalankan aplikasi Flutter
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
  final timestamp = DateTime.now();

  // Periksa apakah Firebase sudah diinisialisasi
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  // Buka box Hive yang diperlukan
  try {
    await Hive.initFlutter();
    await Hive.openBox('sensorDataBox');
    await Hive.openBox('alarmHistoryBox');
    // await Hive.openBox('settingsBox');
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
      content: "Running background tasks",
    );
  }
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Interval untuk menjalankan background task
  Timer.periodic(const Duration(minutes: 10), (timer) async {
    final dataService = DataService();

    await executeFetchData();
    // await dataService.checkAlarmCondition(
    //     tk201, tk202, tk103, boiler, ofda, oiless, DateTime.now());

    // // Hanya jalankan jika service dalam mode foreground
    // if (service is AndroidServiceInstance) {
    //   if (await service.isForegroundService()) {
    //     print("Running periodic background task");

    //     // Panggil executeFetchData untuk mengambil data
    //     await executeFetchData();

    //     // // Panggil checkAlarmCondition setelah data diperbarui
    //     await dataService.checkAlarmCondition(
    //         tk201, tk202, tk103, boiler, ofda, oiless, DateTime.now());
    //   }
    // }
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
  List<FlSpot> pwgData = [];
  List<FlSpot> p_ofdaData = [];
  List<String> timestamps = [];
  DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');

  // Callback untuk update data setelah fetch
  void updateCallback(
      int newBoiler,
      int newOiless,
      int newOfda,
      double newTk201,
      double newTk202,
      double newTk103,
      double newPwg,
      double newP_ofda) {
    // Simpan data yang diperoleh dari fetchData
    boiler = newBoiler;
    oiless = newOiless;
    ofda = newOfda;
    tk201 = newTk201;
    tk202 = newTk202;
    tk103 = newTk103;
    pwg = newPwg;
    p_ofda = newP_ofda;

    print(
        "Data updated: Boiler: $boiler, Oiless: $oiless, OFDA: $ofda, TK201: $tk201, TK202: $tk202, TK103: $tk103, PWG : $pwg, PressureOfda : $p_ofda");
  }

  // Panggil fetchData terlebih dahulu
  await dataService.fetchData(0, tk201Data, tk202Data, tk103Data, pwgData,
      p_ofdaData, timestamps, formatter, updateCallback);
}

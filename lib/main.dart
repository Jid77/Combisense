import 'dart:async';
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

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase
  await Firebase.initializeApp();

  // Inisialisasi Hive
  await Hive.initFlutter();
  await Hive.openBox('sensorDataBox');
  await Hive.openBox('alarmHistoryBox');
  await Hive.openBox('settingsBox');

  // Inisialisasi background service
  await initializeService();

  // Jalankan aplikasi Flutter
  runApp(MyApp());
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
  // // Buka box Hive yang diperlukan
  try {
    await Hive.initFlutter();

    await Hive.openBox('sensorDataBox');
    await Hive.openBox('alarmHistoryBox');
    await Hive.openBox('settingsBox');
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

    // Foreground service akan berjalan dengan notifikasi ini
  }

  // Interval untuk menjalankan background task
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    // Hanya jalankan jika service dalam mode foreground
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        print("Running periodic background task");
        await executeFetchData(); // Memanggil fetchData dari background_task_service.dart
      }
    }
  });
}

// Fungsi untuk menjalankan fetchData dari DataService
Future<void> executeFetchData() async {
  final dataService = DataService();

  // Inisialisasi data yang dibutuhkan oleh fetchData (sesuaikan dengan implementasi Anda)
  List<FlSpot> tk201Data = [];
  List<FlSpot> tk202Data = [];
  List<FlSpot> tk103Data = [];
  List<String> timestamps = [];
  DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');

  // Callback untuk update data setelah fetch (sesuaikan implementasi)
  void updateCallback(int boiler, int oiless, int ofda, double tk201,
      double tk202, double tk103) {
    print(
        "Data updated: Boiler: $boiler, Oiless: $oiless, OFDA: $ofda, TK201: $tk201, TK202: $tk202, TK103: $tk103");
  }

  // Panggil fetchData dari DataService yang sudah Anda buat
  await dataService.fetchData(0, tk201Data, tk202Data, tk103Data, timestamps,
      formatter, updateCallback);
}

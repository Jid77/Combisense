import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'package:aplikasitest1/services/background_task_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter(); // Hive init here
  await Hive.openBox('sensorDataBox'); // Open Box for sensor data
  await Hive.openBox('alarmHistoryBox'); // Open Box for sensor data

  await Hive.openBox('settingsBox'); // Open Box for settings if needed

  Workmanager().initialize(callbackDispatcher);
  Workmanager().registerPeriodicTask(
    "1",
    "fetchDataTask",
    frequency: const Duration(minutes: 15),
  );

  // Inisialisasi notifikasi lokal
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // // Buat saluran notifikasi untuk Android
  // const AndroidNotificationChannel channel = AndroidNotificationChannel(
  //   'sensor_alarm_channel', // ID saluran
  //   'Sensor Alarm', // Nama saluran
  //   description: 'This channel is used for important notifications.',
  //   importance: Importance.high,
  // );

  // flutterLocalNotificationsPlugin
  //     .resolvePlatformSpecificImplementation<
  //         AndroidFlutterLocalNotificationsPlugin>()
  //     ?.createNotificationChannel(channel);

  runApp(const MyApp());
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    print("Workmanager is running the task: $task"); // Tambahkan log ini
    fetchDataFromFirebase();
    return Future.value(true);
  });
}

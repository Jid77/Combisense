import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'app.dart';
import 'services/background_task_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter(); // Hive init here
  await Hive.openBox('sensorDataBox'); // Open Box for sensor data
  await Hive.openBox('settingsBox'); // Open Box for settings if needed

  Workmanager().initialize(callbackDispatcher);
  Workmanager().registerPeriodicTask(
    "1",
    "fetchDataTask",
    frequency: Duration(minutes: 15),
  );

  runApp(MyApp());
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    fetchDataFromFirebase();
    return Future.value(true);
  });
}

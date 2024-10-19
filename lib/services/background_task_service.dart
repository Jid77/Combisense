import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Inisialisasi notifikasi lokal
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class DataService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Stream untuk boiler, oiless, dan ofda
  final StreamController<int> _boilerStreamController = StreamController<int>();
  final StreamController<int> _oilessStreamController = StreamController<int>();
  final StreamController<int> _ofdaStreamController = StreamController<int>();

  Stream<int> get boilerStream => _boilerStreamController.stream;
  Stream<int> get oilessStream => _oilessStreamController.stream;
  Stream<int> get ofdaStream => _ofdaStreamController.stream;

  Future<void> fetchData(
    int index,
    List<FlSpot> tk201Data,
    List<FlSpot> tk202Data,
    List<FlSpot> tk103Data,
    List<String> timestamps,
    DateFormat formatter,
    Function(int, int, int, double, double, double) updateCallback,
  ) async {
    try {
      // Ambil data dari Firebase
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

        // Simpan data, tk201, tk202, dan tk103 di-append, boiler, ofda, dan oiless di-replace
        await _saveToHive(tk201, tk202, tk103, boiler, ofda, oiless, timestamp);

        // // Load pengaturan alarm dan cek kondisi alarm
        // await checkAlarmCondition(
        //     tk201, tk202, tk103, boiler, ofda, oiless, timestamp);

        // Panggil callback dengan data yang diterima
        updateCallback(
            boiler.toInt(), oiless.toInt(), ofda.toInt(), tk201, tk202, tk103);

        // Update stream untuk boiler, oiless, dan ofda
        _boilerStreamController.add(boiler.toInt());
        _oilessStreamController.add(oiless.toInt());
        _ofdaStreamController.add(ofda.toInt());
      }
    } catch (e) {
      print("Error fetching data from Firebase: $e");
    }
  }

  Future<void> _saveToHive(double tk201, double tk202, double tk103, int boiler,
      int ofda, int oiless, DateTime timestamp) async {
    // Buka atau buat box bernama 'sensorDataBox'
    final sensorDataBox = await Hive.openBox('sensorDataBox');

    // Simpan data tk201, tk202, tk103 dengan append (tambahkan ke list)
    List<dynamic> sensorDataList =
        sensorDataBox.get('sensorDataList', defaultValue: []);
    final sensorData = {
      'tk201': tk201,
      'tk202': tk202,
      'tk103': tk103,
      'timestamp': timestamp.toIso8601String(),
    };
    sensorDataList.add(sensorData); // Append data baru ke dalam list
    await sensorDataBox.put(
        'sensorDataList', sensorDataList); // Simpan list baru

    // Replace
    final sensorStatus = {
      'boiler': boiler,
      'ofda': ofda,
      'oiless': oiless,
      'timestamp': timestamp.toIso8601String(),
    };
    await sensorDataBox.put(
        'sensorStatus', sensorStatus); // Replace data status

    print("Data sensor disimpan ke Hive");
  }

  // Jangan lupa untuk menutup stream controller saat tidak digunakan
  void dispose() {
    _boilerStreamController.close();
    _oilessStreamController.close();
    _ofdaStreamController.close();
  }

  // ----------------------------------------------------------------
  Future<void> sendAlarmNotification(String message) async {
    print("Sending alarm notification: $message");
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'alarm_channel', // ID unik untuk channel
      'Sensor Alarm', // Nama channel
      channelDescription: 'Alarm when sensor data is out of range',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('classicalarm'),
      ticker: 'Sensor Alarm',
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Menampilkan notifikasi
    await flutterLocalNotificationsPlugin.show(
      0, // ID notifikasi
      'Sensor Alarm', // Judul notifikasi
      message, // Pesan notifikasi
      platformChannelSpecifics,
      // payload: 'Sensor Alarm Payload', // Payload tambahan (opsional)
    );
  }

  // ----------------------------------------------------------------

  Future<void> checkAlarmCondition(double tk201, double tk202, double tk103,
      int boiler, int ofda, int oiless, DateTime timestamp) async {
    const double minRange = 65.0;
    const double maxRange = 80.0;

    final box =
        Hive.box('alarmHistoryBox'); // Box untuk menyimpan riwayat alarm
    // final settingsBox = await Hive.openBox('settingsBox');
    SharedPreferences prefs = await SharedPreferences.getInstance();

    final task1Enabled = prefs.getBool("task1") ?? false;
    final task2Enabled = prefs.getBool("task2") ?? false;
    final task3Enabled = prefs.getBool("task3") ?? false;
    final task4Enabled = prefs.getBool("task4") ?? false;
    final task5Enabled = prefs.getBool("task5") ?? false;
    final task6Enabled = prefs.getBool("task6") ?? false;

    print(" switch tk202 ${task5Enabled}, switch boiler ${task1Enabled}");

    if (task1Enabled && boiler == 0) {
      await sendAlarmNotification("Warning: Boiler System Abnormal");
      box.add({
        'timestamp': DateTime.now(),
        'alarmName': 'boiler',
        'sensorValue': boiler,
      });
    }
    if (task2Enabled && ofda == 0) {
      await sendAlarmNotification("Warning: OFDA System Abnormal");
      box.add({
        'timestamp': DateTime.now(),
        'alarmName': 'ofda',
        'sensorValue': ofda,
      });
    }
    if (task3Enabled && oiless == 0) {
      await sendAlarmNotification("Warning: Oiless System Abnormal");
      box.add({
        'timestamp': DateTime.now(),
        'alarmName': 'oiless',
        'sensorValue': oiless,
      });
    }
    if (task4Enabled && (tk201 < minRange || tk201 > maxRange)) {
      await sendAlarmNotification("Warning: tk201 out of range: $tk201");
      box.add({
        'timestamp': DateTime.now(),
        'alarmName': 'tk201',
        'sensorValue': tk201,
      });
    }
    if (task5Enabled && (tk202 < minRange || tk202 > maxRange)) {
      await sendAlarmNotification("Warning: tk202 out of range: $tk202");
      box.add({
        'timestamp': DateTime.now(),
        'alarmName': 'tk202',
        'sensorValue': tk202,
      });
    }
    if (task6Enabled && (tk103 < minRange || tk103 > maxRange)) {
      await sendAlarmNotification("Warning: tk103 out of range: $tk103");
      box.add({
        'timestamp': DateTime.now(),
        'alarmName': 'tk103',
        'sensorValue': tk103,
      });
    }
  }
}
  // ----------------------------------------------------------------

//MaSIH ERROR ALARM SETTING LOAD, UNTUK FUNGSI NYA UDH DIPINDAH DARI HOMEPAGE KE SINI
// Coba manggil si checkalarmnya terpisah jangan didalam fetch data


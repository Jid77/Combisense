import 'package:firebase_database/firebase_database.dart';
import 'package:hive/hive.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Inisialisasi notifikasi lokal (Harus diinisialisasi di main.dart sebelumnya)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
// Fungsi ini akan dijalankan sebagai background task
// Future<void> backgroundTaskHandler() async {
//   await fetchDataFromFirebase();
// }
// State untuk mengontrol status alarm
// bool _isBoilerAlarmEnabled = true;
// bool _isOfdaAlarmEnabled = true;
// bool _isOilessAlarmEnabled = true;
// bool _isVentFilterAlarmEnabled = true;
// bool isTk201AlarmEnabled = true;
// bool isTk202AlarmEnabled = true;
// bool isTk103AlarmEnabled = true;
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

class DataService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Future<void> fetchData(
    int index,
    List<FlSpot> tk201Data,
    List<FlSpot> tk202Data,
    List<FlSpot> tk103Data,
    List<String> timestamps,
    DateFormat formatter,
    Function(int, int, int, double, double, double)
        updateCallback, // Pastikan ini sesuai
  ) async {
    try {
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
        // print("Data telah diterima");
        await _loadAlarmSettings();
        await checkAlarmCondition(
            tk201, tk202, tk103, boiler, ofda, oiless, timestamp);
        // Panggil callback dengan data yang diterima
        updateCallback(
            boiler.toInt(), oiless.toInt(), ofda.toInt(), tk201, tk202, tk103);
      }
    } catch (e) {
      print("Error fetching data from Firebase: $e");
    }
  }
}

Future<void> _loadAlarmSettings() async {
  final settingsBox = Hive.box('settingsBox');
  // Mengambil status alarm dari Hive
  bool _isBoilerAlarmEnabled =
      settingsBox.get('boilerAlarmEnabled', defaultValue: true);
  bool _isOfdaAlarmEnabled =
      settingsBox.get('ofdaAlarmEnabled', defaultValue: true);
  bool _isOilessAlarmEnabled =
      settingsBox.get('oilessAlarmEnabled', defaultValue: true);
  bool isTk201AlarmEnabled =
      settingsBox.get('tk201AlarmEnabled', defaultValue: true);
  bool isTk202AlarmEnabled =
      settingsBox.get('tk202AlarmEnabled', defaultValue: true);
  bool isTk103AlarmEnabled =
      settingsBox.get('tk103AlarmEnabled', defaultValue: true);
  print("Alarm  Boiler BACKGROUND:$_isBoilerAlarmEnabled");
}

// await checkAlarmCondition(
//     tk201, tk202, tk103, boiler, ofda, oiless, timestamp);
Future<void> checkAlarmCondition(double tk201, double tk202, double tk103,
    int boiler, int ofda, int oiless, DateTime timestamp) async {
  const double minRange = 65.0;
  const double maxRange = 80.0;

  final box = Hive.box('alarmHistoryBox'); // Box untuk menyimpan riwayat alarm
  final settingsBox = Hive.box('settingsBox'); // Box untuk menyimpan pengaturan

  // Ambil status alarm dari Hive
  bool isTk201AlarmEnabled =
      settingsBox.get('tk201AlarmEnabled', defaultValue: true);
  bool isTk202AlarmEnabled =
      settingsBox.get('tk202AlarmEnabled', defaultValue: true);
  bool isTk103AlarmEnabled =
      settingsBox.get('tk103AlarmEnabled', defaultValue: true);
  bool isBoilerAlarmEnabled =
      settingsBox.get('boilerAlarmEnabled', defaultValue: true);
  bool isOfdaAlarmEnabled =
      settingsBox.get('ofdaAlarmEnabled', defaultValue: true);
  bool isOilessAlarmEnabled =
      settingsBox.get('oilessAlarmEnabled', defaultValue: true);

  if (isTk201AlarmEnabled && (tk201 < minRange || tk201 > maxRange)) {
    await sendAlarmNotification("Warning: tk201 out of range: $tk201");
    box.add({
      'timestamp': DateTime.now(),
      'alarmName': 'tk201',
      'sensorValue': tk201,
    });
  }
  if (isTk202AlarmEnabled && (tk202 < minRange || tk202 > maxRange)) {
    await sendAlarmNotification("Warning: tk202 out of range: $tk202");
    box.add({
      'timestamp': DateTime.now(),
      'alarmName': 'tk202',
      'sensorValue': tk202,
    });
  }
  if (isTk103AlarmEnabled && (tk103 < minRange || tk103 > maxRange)) {
    await sendAlarmNotification("Warning: tk103 out of range: $tk103");
    box.add({
      'timestamp': DateTime.now(),
      'alarmName': 'tk103',
      'sensorValue': tk103,
    });
  }

  if (isBoilerAlarmEnabled && boiler == 0) {
    await sendAlarmNotification("Warning: Boiler System Abnormal");
    box.add({
      'timestamp': DateTime.now(),
      'alarmName': 'boiler',
      'sensorValue': boiler,
    });
  }
  if (isOfdaAlarmEnabled && ofda == 0) {
    await sendAlarmNotification("Warning: OFDA System Abnormal");
    box.add({
      'timestamp': DateTime.now(),
      'alarmName': 'ofda',
      'sensorValue': ofda,
    });
  }
  if (isOilessAlarmEnabled && oiless == 0) {
    await sendAlarmNotification("Warning: Oiless System Abnormal");
    box.add({
      'timestamp': DateTime.now(),
      'alarmName': 'oiless',
      'sensorValue': oiless,
    });
  }
}

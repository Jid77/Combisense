import 'package:firebase_database/firebase_database.dart';
import 'package:hive/hive.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Inisialisasi notifikasi lokal (Harus diinisialisasi di main.dart sebelumnya)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> fetchDataFromFirebase() async {
  try {
    final dataSnapshot =
        await FirebaseDatabase.instance.ref('sensor_data').get();
    if (dataSnapshot.value != null) {
      final data = Map<dynamic, dynamic>.from(dataSnapshot.value as Map);

      // Parsing nilai dari Firebase
      final tk201 = data['tk201']?.toDouble() ?? 0;
      final tk202 = data['tk202']?.toDouble() ?? 0;
      final tk103 = data['tk103']?.toDouble() ?? 0;
      final boiler = data['boiler'] ?? 0;
      final ofda = data['ofda'] ?? 0;
      final oiless = data['oiless'] ?? 0;
      final timestamp = DateTime.now();

      // Cek kondisi alarm, jika data sensor keluar dari range maka kirim notifikasi
      await checkAlarmCondition(
          tk201, tk202, tk103, boiler, ofda, oiless, timestamp);

      // Simpan data ke Hive
      final box = Hive.box('sensorDataBox');
      int index = box.length ~/ 3;
      box.put('tk201_${index + 1}', tk201);
      box.put('tk202_${index + 1}', tk202);
      box.put('tk103_${index + 1}', tk103);
      box.put('timestamp_${index + 1}', timestamp.toIso8601String());
      box.put('boiler', boiler);
      box.put('ofda', ofda);
      box.put('oiless', oiless);
    }
  } catch (e) {
    print("Error fetching data: $e");
  }
}

Future<void> checkAlarmCondition(double tk201, double tk202, double tk103,
    int boiler, int ofda, int oiless, DateTime timestamp) async {
  const double minRange = 65.0;
  const double maxRange = 80.0;

  final box = Hive.box('alarmHistoryBox'); // Box untuk menyimpan riwayat alarm

  if (tk201 < minRange || tk201 > maxRange) {
    await sendAlarmNotification("Warning: tk201 out of range: $tk201");
    box.add({
      'timestamp': DateTime.now(),
      'alarmName': 'tk201',
      'sensorValue': tk201,
    });
  }
  if (tk202 < minRange || tk202 > maxRange) {
    await sendAlarmNotification("Warning: tk202 out of range: $tk202");
    box.add({
      'timestamp': DateTime.now(),
      'alarmName': 'tk202',
      'sensorValue': tk202,
    });
  }
  if (tk103 < minRange || tk103 > maxRange) {
    await sendAlarmNotification("Warning: tk103 out of range: $tk103");
    box.add({
      'timestamp': DateTime.now(),
      'alarmName': 'tk103',
      'sensorValue': tk103,
    });
  }

  if (boiler == 0) {
    await sendAlarmNotification("Warning: Boiler System Abnormal");
    box.add({
      'timestamp': DateTime.now(),
      'alarmName': 'boiler',
      'sensorValue': boiler,
    });
  }
  if (ofda == 0) {
    await sendAlarmNotification("Warning: OFDA System Abnormal");
    box.add({
      'timestamp': DateTime.now(),
      'alarmName': 'ofda',
      'sensorValue': ofda,
    });
  }
  if (oiless == 0) {
    await sendAlarmNotification("Warning: Oiless System Abnormal");
    box.add({
      'timestamp': DateTime.now(),
      'alarmName': 'oiless',
      'sensorValue': oiless,
    });
  }
}

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

Future<void> sendManualNotification() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'manual_channel', // ID unik untuk channel manual
    'Manual Notif', // Nama channel
    channelDescription: 'Triggered manually from button',
    importance: Importance.max,
    priority: Priority.high,
    sound: RawResourceAndroidNotificationSound('classicalarm'),
    ticker: 'Manual Notification',
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  // Tampilkan notifikasi manual
  await flutterLocalNotificationsPlugin.show(
    0, // ID notifikasi
    'Manual Trigger', // Judul notifikasi
    'This notification is triggered manually by pressing a button.', // Pesan notifikasi
    platformChannelSpecifics,
    payload: 'Manual Trigger Payload',
  );
}

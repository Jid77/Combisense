import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> showNotification(
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
  String title,
  String body,
) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'your_channel_id', // Ganti dengan ID channel Anda
    'your_channel_name', // Ganti dengan nama channel Anda
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'ticker',
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    platformChannelSpecifics,
    payload: 'item x',
  );
}

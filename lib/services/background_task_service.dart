import 'package:firebase_database/firebase_database.dart';
import 'package:hive/hive.dart';
import 'dart:async';

Future<void> fetchDataFromFirebase() async {
  try {
    final dataSnapshot =
        await FirebaseDatabase.instance.ref('sensor_data').get();
    if (dataSnapshot.value != null) {
      final data = Map<dynamic, dynamic>.from(dataSnapshot.value as Map);
      final tk201 = data['tk201']?.toDouble() ?? 0;
      final tk202 = data['tk202']?.toDouble() ?? 0;
      final tk103 = data['tk103']?.toDouble() ?? 0;
      final boiler = data['boiler'] ?? 0;
      final ofda = data['ofda'] ?? 0;
      final oiless = data['oiless'] ?? 0;
      final timestamp = DateTime.now();

      final box = Hive.box('sensorDataBox'); // Access the already opened box
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
    // Handle exceptions, maybe log the error
    print("Error fetching data: $e");
  }
}

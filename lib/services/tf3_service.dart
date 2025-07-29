// lib/services/tf3_service.dart
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

class Tf3Service {
  final String name;
  final _spController = StreamController<double>.broadcast();
  final _pvController = StreamController<double>.broadcast();

  Stream<double> get spStream => _spController.stream;
  Stream<double> get pvStream => _pvController.stream;

  Tf3Service({required this.name}) {
    final db = FirebaseDatabase.instance;

    // Listen to SV
    db.ref('sensor_data/${name}_sv').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val != null) {
        final parsed = double.tryParse(val.toString());
        if (parsed != null) _spController.add(parsed);
      }
    });

    // Listen to PV
    db.ref('sensor_data/${name}_pv').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val != null) {
        final parsed = double.tryParse(val.toString());
        if (parsed != null) _pvController.add(parsed);
      }
    });
  }

  void setPreset(double value) {
    final ref = FirebaseDatabase.instance.ref('commands/${name}_sv_set');
    ref.set(value); // Kirim sebagai number
  }

  void dispose() {
    _spController.close();
    _pvController.close();
  }
}

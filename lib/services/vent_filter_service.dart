import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

class VentFilterService {
  final String name; // contoh: "tk201", "tk202", "tk103"
  // final _pvController = StreamController<double>.broadcast();
  final _spController = StreamController<double>.broadcast();
  final _db = FirebaseDatabase.instance.ref();

  // Stream<double> get pvStream => _pvController.stream;
  Stream<double> get spStream => _spController.stream;

  VentFilterService({required this.name}) {
    _listen();
  }

  void _listen() {
    _db.child('sensor_data').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        // final pv = data[name];
        final sp = data['${name}_preset'];
        // if (pv != null) _pvController.add((pv as num).toDouble());
        if (sp != null) _spController.add((sp as num).toDouble());
      }
    });
  }

  void setPreset(double value) {
    _db.child('commands/${name}_preset_set').set(value);
  }

  void dispose() {
    // _pvController.close();
    _spController.close();
  }
}

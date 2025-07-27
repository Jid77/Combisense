import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

class ArtesisTimerService {
  final int number; // e.g. 8 (artesis 2), 9 (artesis 3)
  final _pvController = StreamController<double>.broadcast();
  final _presetController = StreamController<double>.broadcast();

  Stream<double> get pvStream => _pvController.stream;
  Stream<double> get presetStream => _presetController.stream;

  final _db = FirebaseDatabase.instance.ref();

  ArtesisTimerService({required this.number}) {
    _startListening();
  }

  void _startListening() {
    _db.child('sensor_data').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        final pvRaw = data['artesis${number}_pv'];
        final presetRaw = data['artesis${number}_preset'];
        if (pvRaw != null) {
          _pvController.add((pvRaw as num).toDouble());
        }
        if (presetRaw != null) {
          _presetController.add((presetRaw as num).toDouble());
        }
      }
    });
  }

  void setPreset(double value) {
    _db.child('commands/artesis${number}_preset_set').set(value);
  }

  void triggerReset() {
    _db.child('commands/artesis${number}_reset').set(1);
    Future.delayed(const Duration(seconds: 1), () {
      _db.child('commands/artesis${number}_reset').set(0);
    });
  }

  void dispose() {
    _pvController.close();
    _presetController.close();
  }
}

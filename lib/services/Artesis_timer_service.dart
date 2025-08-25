import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

class ArtesisTimerService {
  final int number; // contoh: 2 (artesis 2), 3 (artesis 3)

  final _pvController = StreamController<double>.broadcast();
  final _presetController = StreamController<double>.broadcast();
  final _manualController = StreamController<bool>.broadcast();

  Stream<double> get pvStream => _pvController.stream;
  Stream<double> get presetStream => _presetController.stream;
  Stream<bool> get manualStream => _manualController.stream;

  final DatabaseReference _root = FirebaseDatabase.instance.ref();

  // Path default:
  late final DatabaseReference _sensorRef;
  late final DatabaseReference _manualRef;
  DatabaseReference? _manualTimerRef; // opsional

  StreamSubscription<DatabaseEvent>? _sensorSub;
  StreamSubscription<DatabaseEvent>? _manualSub;

  /// [manualPath] default: 'commands/artesis{number}_manual'
  /// [manualTimerPath] opsional, mis. 'commands/artesis{number}_manual_timer_min'
  ArtesisTimerService({
    required this.number,
    String? manualPath,
    String? manualTimerPath,
  }) {
    _sensorRef = _root.child('sensor_data');
    _manualRef = _root.child(manualPath ?? 'commands/artesis${number}_manual');
    if (manualTimerPath != null) {
      _manualTimerRef = _root.child(manualTimerPath);
    }
    _startListening();
  }

  void _startListening() {
    // Sensor PV/SV
    _sensorSub = _sensorRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        final pvRaw = data['artesis${number}_pv'];
        final presetRaw = data['artesis${number}_preset'];
        if (pvRaw is num) {
          _pvController.add(pvRaw.toDouble());
        }
        if (presetRaw is num) {
          _presetController.add(presetRaw.toDouble());
        }
      }
    });

    // Manual toggle (1/0)
    _manualSub = _manualRef.onValue.listen((event) {
      final v = event.snapshot.value;
      final on = (v == 1) || (v == true) || (v == '1');
      _manualController.add(on);
    });
  }

  // ============ Commands ============
  void setPreset(double value) {
    // Catatan: backend kamu membaca *10 — tetap dipertahankan
    _root.child('commands/artesis${number}_preset_set').set(value * 10);
  }

  void triggerReset() {
    _root.child('commands/artesis${number}_reset').set(1);
    // kalau butuh auto-clear bisa aktifkan lagi:
    // Future.delayed(const Duration(seconds: 1), () {
    //   _root.child('commands/artesis${number}_reset').set(0);
    // });
  }

  Future<bool> fetchInitialManual() async {
    try {
      final snap = await _manualRef.get();
      final v = snap.value;
      return (v == 1) || (v == true) || (v == '1');
    } catch (_) {
      return false;
    }
  }

  Future<void> setManual(bool on) async {
    await _manualRef.set(on ? 1 : 0);
  }

  /// ON dengan durasi menit (opsional menulis ke path durasi jika diset).
  Future<void> setManualWithDuration(int minutes) async {
    await _manualRef.set(1);
    if (_manualTimerRef != null) {
      await _manualTimerRef!.set(minutes);
    }
  }

  void dispose() {
    _sensorSub?.cancel();
    _manualSub?.cancel();
    _pvController.close();
    _presetController.close();
    _manualController.close();
  }
}

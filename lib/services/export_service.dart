import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

class ExportService {
  Future<void> requestStoragePermission(BuildContext context) async {
    if (await Permission.manageExternalStorage.isGranted) return;
    await Permission.manageExternalStorage.request();
  }

  Future<String?> openSAFPicker(BuildContext context) async {
    try {
      final status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Izin ditolak, tidak dapat akses folder')),
        );
        return null;
      }
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder dipilih: $result')),
        );
        return result;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pemilihan folder dibatalkan.')),
        );
        return null;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
      return null;
    }
  }

  Future<void> exportDataToExcel(
    BuildContext context, {
    required DateTime startDate,
    required DateTime endDate,
    String? targetDirectory,
  }) async {
    await requestStoragePermission(context);

    final sensorDataBox = Hive.isBoxOpen('sensorDataBox')
        ? Hive.box('sensorDataBox')
        : await Hive.openBox('sensorDataBox');
    final alarmHistoryBox = Hive.isBoxOpen('alarmHistoryBox')
        ? Hive.box('alarmHistoryBox')
        : await Hive.openBox('alarmHistoryBox');

    final List<dynamic> sensorDataList = (sensorDataBox
        .get('sensorDataList', defaultValue: <dynamic>[])) as List<dynamic>;

    final excel = Excel.createExcel();
    if (excel.getDefaultSheet() != null) {
      excel.delete(excel.getDefaultSheet()!);
    }

    // Vent Filter (tanpa status)
    final vent = excel['Vent Filter'];
    vent.appendRow(<String>['Timestamp', 'Tk201', 'Tk202', 'Tk103']);

    // LBENG04
    final lb = excel['LBENG04'];
    lb.appendRow(<String>['Timestamp', 'Temp_AHU_04LB', 'RH_AHU_04LB']);

    // M800
    final m800 = excel['M800'];
    m800.appendRow(<String>[
      'Timestamp',
      'TOC (ppb)',
      'Temp (°C)',
      'Conduct (uS/cm)',
      'Lamp Hours'
    ]);

    // Alarm
    final alarmSheet = excel['Alarm History'];
    alarmSheet.appendRow(<String>['Timestamp', 'Alarm Name', 'Sensor Value']);

    DateTime? _parseTs(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      final s = raw.toString();
      try {
        return DateFormat('dd/MM/yy HH:mm').parse(s);
      } catch (_) {
        for (final f in ['dd/MM/yyyy HH:mm', 'yyyy-MM-dd HH:mm:ss']) {
          try {
            return DateFormat(f).parse(s);
          } catch (_) {}
        }
        return null;
      }
    }

    bool _inRange(DateTime ts) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
      return !ts.isBefore(start) && !ts.isAfter(end);
    }

    // ==== isi Vent/LB/M800 dari sensorDataList ====
    for (final item in sensorDataList) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item as Map);

      final ts = _parseTs(map['timestamp']);
      if (ts == null || !_inRange(ts)) continue;

      vent.appendRow([
        DateFormat('dd/MM/yyyy HH:mm').format(ts),
        (map['tk201'] as num?)?.toDouble(),
        (map['tk202'] as num?)?.toDouble(),
        (map['tk103'] as num?)?.toDouble(),
      ]);

      lb.appendRow([
        DateFormat('dd/MM/yyyy HH:mm').format(ts),
        (map['temp_ahu04lb'] as num?)?.toDouble(),
        (map['rh_ahu04lb'] as num?)?.toDouble(),
      ]);

      final hasM800 = map.containsKey('m800_toc') ||
          map.containsKey('m800_temp') ||
          map.containsKey('m800_conduct') ||
          map.containsKey('m800_lamp');

      if (hasM800) {
        m800.appendRow([
          DateFormat('dd/MM/yyyy HH:mm').format(ts),
          (map['m800_toc'] as num?)?.toDouble(),
          (map['m800_temp'] as num?)?.toDouble(),
          (map['m800_conduct'] as num?)?.toDouble(),
          (map['m800_lamp'] as num?)?.toInt(),
        ]);
      }
    }

    // ==== isi Alarm History ====
    for (final alarm in alarmHistoryBox.values) {
      if (alarm is! Map) continue;
      final a = Map<String, dynamic>.from(alarm as Map);
      final ts = _parseTs(a['timestamp']) ??
          (a['timestamp'] is DateTime ? a['timestamp'] as DateTime : null);
      if (ts == null || !_inRange(ts)) continue;

      alarmSheet.appendRow([
        DateFormat('dd/MM/yyyy HH:mm').format(ts),
        a['alarmName']?.toString() ?? '-',
        a['sensorValue'],
      ]);
    }

    // ==== simpan file ====
    try {
      final nowStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'export_$nowStr.xlsx';

      final dirPath =
          targetDirectory ?? '/storage/emulated/0/Download/combiphar';
      final directory = Directory(dirPath);
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      final filePath = '${directory.path}/$fileName';
      final bytes = excel.encode();
      if (bytes == null) throw 'Excel encode() mengembalikan null';

      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data berhasil diekspor ke $filePath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor data: $e')),
      );
    }
  }
}

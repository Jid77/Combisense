import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

class ExportService {
  // Fungsi untuk meminta izin penyimpanan menggunakan SAF
  Future<void> requestStoragePermission(BuildContext context) async {
    if (await Permission.manageExternalStorage.isGranted) {
      // Izin sudah diberikan
      return;
    } else {
      // Tampilkan prompt untuk meminta izin MANAGE_EXTERNAL_STORAGE
      await Permission.manageExternalStorage.request();
    }
  }

  // Fungsi untuk membuka SAF dan memilih folder
  Future<void> openSAFPicker(BuildContext context) async {
    try {
      var status = await Permission.manageExternalStorage.status;
      if (status.isGranted) {
        // Anda dapat langsung menggunakan intent untuk membuka pengelola file
        var result = await FilePicker.platform.getDirectoryPath();
        if (result != null) {
          // Lanjutkan dengan path yang dipilih pengguna
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Folder dipilih: $result')),
          );
        } else {
          // Pengguna membatalkan pemilihan folder
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Pemilihan folder dibatalkan.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Izin ditolak, tidak dapat mengakses folder.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    }
  }

  // Fungsi untuk export data ke Excel
  Future<void> exportDataToExcel(BuildContext context,
      {required DateTime startDate, required DateTime endDate}) async {
    await requestStoragePermission(context);

    final sensorDataBox = await Hive.box('sensorDataBox');
    final sensorDataList =
        sensorDataBox.get('sensorDataList', defaultValue: []);

    var excel = Excel.createExcel();
    Sheet sensorSheet = excel['Sensor Data'];
    Sheet alarmSheet = excel['Alarm History'];

    List<String> sensorHeaders = [
      'Timestamp',
      'Tk201',
      'Tk202',
      'Tk103',
      'PWG',
      'P_OFDA'
    ];
    sensorSheet.appendRow(sensorHeaders);

    List<String> alarmHeaders = ['Timestamp', 'Alarm Name', 'Sensor Value'];
    alarmSheet.appendRow(alarmHeaders);

    // Mengisi data sensor
    for (var data in sensorDataList) {
      String timestampString = data['timestamp'];
      DateTime? timestamp;

      try {
        timestamp = DateFormat('dd/MM/yy HH:mm').parse(timestampString);
      } catch (e) {
        continue; // Skip if parsing fails
      }

      if (timestamp.isAfter(startDate) &&
          timestamp.isBefore(endDate.add(Duration(days: 1)))) {
        List<dynamic> row = [
          DateFormat('dd/MM/yyyy HH:mm').format(timestamp),
          data['tk201'],
          data['tk202'],
          data['tk103'],
          data['pwg'],
          data['p_ofda'],
        ];
        sensorSheet.appendRow(row);
      }
    }

    // Mengisi data alarm history
    final alarmHistoryBox = await Hive.box('alarmHistoryBox');
    List<dynamic> alarmHistoryList =
        alarmHistoryBox.values.toList(); // Mengambil semua nilai di box

    for (var alarm in alarmHistoryList) {
      String alarmTimestampString =
          DateFormat('dd/MM/yyyy HH:mm').format(alarm['timestamp']);
      String alarmName = alarm['alarmName'];
      dynamic sensorValue = alarm['sensorValue'];

      alarmSheet.appendRow([alarmTimestampString, alarmName, sensorValue]);
    }

    // Simpan file Excel
    try {
      final directory = Directory('/storage/emulated/0/Download/combiphar');
      final filePath = '${directory.path}/exported_data.xlsx';

      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

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

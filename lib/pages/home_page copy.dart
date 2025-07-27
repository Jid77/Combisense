import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:async';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:combisense/services/background_task_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:combisense/widgets/background_wave.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:combisense/services/export_service.dart';
import 'package:combisense/widgets/tank_level_widget.dart';
import '../widgets/circular_value.dart';
import '../widgets/status_text.dart';
import '../widgets/legend_dot.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final dataService = DataService();
  final PageStorageBucket _bucket = PageStorageBucket();

  final List<FlSpot> _tk201Data = [];
  final List<FlSpot> _tk202Data = [];
  final List<FlSpot> _tk103Data = [];
  final List<FlSpot> _temp_ahu04lbData = [];
  final List<FlSpot> _rh_ahu04lbData = [];

  // late Timer _timer;
  late Box _sensorDataBox;
  late Box _alarmHistoryBox;
  final DateFormat formatter = DateFormat('HH:mm');

  final PageController _pageController = PageController();

  bool _isLoading = true;
  int _selectedIndex = 0;

  // data
  // int boiler = 0;
  // int chiller = 0;
  // int ofda = 0;
  double tk201 = 0;
  double tk202 = 0;
  double tk103 = 0;
  double temp_ahu04lb = 0;
  double rh_ahu04lb = 0;
  // int uf = 0;
  // int faultPump = 0;
  // int highSurfaceTank = 0;
  // int lowSurfaceTank = 0;
  // State untuk mengontrol status alarm
  bool isTask1On = false;
  bool isTask2On = false;
  bool isTask3On = false;
  bool isTask4On = false;
  bool isTask5On = false;
  bool isTask6On = false;
  bool isTask7On = false;
  bool isTask8On = false; // UF
  bool isTask9On = false; // Fault Pump
  bool isTask10On = false; // Surface Tank (high & low)
  //  excel - timestamp
  DateTimeRange? selectedDateRange;

  late final Stream<int> _highStream;
  late final Stream<int> _lowStream;

  @override
  void initState() {
    super.initState();
    _highStream = dataService.highSurfaceTankStream;
    _lowStream = dataService.lowSurfaceTankStream;
    // if (!_isListenerStarted) {
    //   _isListenerStarted = true;
    // }
    _sensorDataBox = Hive.box('sensorDataBox');
    _alarmHistoryBox = Hive.box('alarmHistoryBox');
    // _initHive(); // Inisialisasi Hive sebelum digunakan
    _loadSwitchState();
    executeFetchData();
    // _startListening();
    printAlarmHistory();
    // Menambahkan listener untuk update UI saat data Hive berubah
    // _sensorDataBox.listenable().addListener(() {
    //   setState(() {}); // Memicu pembaruan UI
    // });
    // Timer.periodic(const Duration(minutes: 1), (timer) async {
    //   // _startListening();
    //   await executeFetchData();
    //   // await dataService.checkAlarmCondition(
    //   //     tk201, tk202, tk103, boiler, ofda, chiller, DateTime.now());
    //   // printAlarmHistory();

    //   //   // _loadDataFromHive();
    //   //   // print("Isi Hive periodic: ${_sensorDataBox.toMap()}");
    // });
    _isLoading = false;
  }

  Future<void> _initHive() async {
    await Hive.openBox(
        'sensorDataBox'); // Buka Hive Box bernama 'sensorDataBox'
    await Hive.openBox('alarmHistoryBox');
  }

// Fungsi untuk memuat data terbaru dari Hive di awal aplikasi
  Future<void> _loadInitialData() async {
    final latestData = _sensorDataBox.get('sensorDataList', defaultValue: []);
    if (latestData.isNotEmpty) {
      final data = latestData.last;
      setState(() {
        tk201 = data['tk201'];
        tk202 = data['tk202'];
        tk103 = data['tk103'];
        temp_ahu04lb = data['temp_ahu04lb'];
        rh_ahu04lb = data['rh_ahu04lb'];
        // boiler = data['boiler'];
        // chiller = data['chiller'];
        // ofda = data['ofda'];
        // uf = data['uf'] ?? 0;
        // faultPump = data['fault_pump'] ?? 0;
        // highSurfaceTank = data['high_surface_tank'] ?? 0;
        // lowSurfaceTank = data['low_surface_tank'] ?? 0;
      });
    } else {
      await executeFetchData();
    }
  }

// Fungsi untuk menjalankan fetchData dari DataService
  Future<void> executeFetchData() async {
    List<FlSpot> tk201Data = [];
    List<FlSpot> tk202Data = [];
    List<FlSpot> tk103Data = [];
    List<FlSpot> temp_ahu04lbData = [];
    List<FlSpot> rh_ahu04lbData = [];
    List<String> timestamps = [];
    DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');

    // Callback untuk update data setelah fetch
    void updateCallback(
      int newBoiler,
      int newChiller,
      int newOfda,
      double newTk201,
      double newTk202,
      double newTk103,
      double newTemp_ahu04lb,
      double newRh_ahu04lb,
      int newUf,
      int newFaultPump,
      int newHighSurfaceTank,
      int newLowSurfaceTank,
    ) {
      setState(() {
        // boiler = newBoiler;
        // chiller = newChiller;
        // ofda = newOfda;
        tk201 = newTk201;
        tk202 = newTk202;
        tk103 = newTk103;
        temp_ahu04lb = newTemp_ahu04lb;
        rh_ahu04lb = newRh_ahu04lb;
        // uf = newUf;
        // faultPump = newFaultPump;
        // highSurfaceTank = newHighSurfaceTank;
        // lowSurfaceTank = newLowSurfaceTank;
      });

      print(
          "Data updated:TK201: $tk201, TK202: $tk202, TK103: $tk103, temp_ahu04lb: $temp_ahu04lb, RH_AHU: $rh_ahu04lb");
    }

    await dataService.fetchData(
      0,
      tk201Data,
      tk202Data,
      tk103Data,
      temp_ahu04lbData,
      rh_ahu04lbData,
      timestamps,
      formatter,
      updateCallback,
    );
  }

  Future<void> _saveDataToHive(Map<dynamic, dynamic> data) async {
    final sensorDataBox = await Hive.box('sensorDataBox');
    List<dynamic> sensorDataList =
        sensorDataBox.get('sensorDataList', defaultValue: []);
    final sensorData = {
      'tk201': data['tk201'],
      'tk202': data['tk202'],
      'tk103': data['tk103'],
      'temp_ahu04lb': data['temp_ahu04lb'],
      'rh_ahu04lb': data['rh_ahu04lb'],
      'timestamp': DateTime.now().toIso8601String(),
    };
    sensorDataList.add(sensorData); // Append data baru ke dalam list
    await sensorDataBox.put(
        'sensorDataList', sensorDataList); // Simpan list baru
  }

  Future<void> _loadSwitchState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isTask1On = prefs.getBool("task1") ?? false;
      isTask2On = prefs.getBool("task2") ?? false;
      isTask3On = prefs.getBool("task3") ?? false;
      isTask4On = prefs.getBool("task4") ?? false;
      isTask5On = prefs.getBool("task5") ?? false;
      isTask6On = prefs.getBool("task6") ?? false;
      isTask7On = prefs.getBool("task7") ?? false;
      isTask8On = prefs.getBool("task8") ?? false;
      isTask9On = prefs.getBool("task9") ?? false;
      isTask10On = prefs.getBool("task10") ?? false;
    });
  }

  void updateServiceData() {
    FlutterBackgroundService().invoke("updateData", {
      "task1": isTask1On,
      "task2": isTask2On,
      "task3": isTask3On,
      "task4": isTask4On,
      "task5": isTask5On,
      "task6": isTask6On,
      "task7": isTask7On,
      "task8": isTask8On,
      "task9": isTask9On,
      "task10": isTask10On,
    });
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    // _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("Is loading: $_isLoading");
    return PageStorage(
      bucket: _bucket,
      child: Scaffold(
        body: Stack(
          children: [
            // Menempatkan Custom AppBar di belakang konten
            ClipPath(
              clipper: BackgroundWaveClipper(),
              child: Container(
                height: 210,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF532F8F), Color(0xFF532F8F)],
                  ),
                ),
                child: const Center(),
              ),
            ),
            // Konten utama
            const Positioned(
              top: 100,
              left: 10,
              right: 0,
              child: Center(
                child: Row(
                  // mainAxisAlignment: MainAxisAlignment.center,
                  // crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Utility Monitoring Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    // SizedBox(width: 5), // Jarak antara teks dan gambar
                    // Image.asset(
                    //   'assets/images/combiwhite.png', // Ganti dengan path gambar Anda
                    //   height: 35, // Atur tinggi gambar sesuai kebutuhan
                    // ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 94,
              left: 345,
              right: 0,
              child: Center(
                child: Row(
                  // mainAxisAlignment: MainAxisAlignment.center,
                  // crossAxisAlignment: CrossAxisAlignment.,
                  children: [
                    Image.asset(
                      'assets/images/combiwhite.png', // Ganti dengan path gambar Anda
                      height: 35, // Atur tinggi gambar sesuai kebutuhan
                    ),
                  ],
                ),
              ),
            ),
            // Konten berdasarkan indeks yang dipilih
            IndexedStack(
              index: _selectedIndex,
              children: [
                _buildHomeContent(),
                _buildHistoryContent(),
                _buildAlarmSwitchContent(),
              ],
            ),
          ],
        ),
        bottomNavigationBar: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(35),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onBottomNavTapped,
            items: [
              BottomNavigationBarItem(
                icon: SvgPicture.asset(
                  'assets/images/homefull.svg',
                  color: _selectedIndex == 0
                      ? const Color(0xFF532F8F)
                      : Colors.black54,
                  width: 20,
                  height: 20,
                ),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.history_sharp, size: 26),
                label: 'History',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.settings, size: 26),
                label: 'Setting',
              ),
            ],
            selectedItemColor: const Color(0xFF532F8F),
            unselectedItemColor: Colors.black54,
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
          ),
        ),
      ),
    );
  }

  Widget _buildAlarmSwitchContent() {
    return Padding(
      padding: const EdgeInsets.only(top: 185.0, left: 16, right: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(
              thickness: 2,
              color: Colors.black,
              indent: 0,
              endIndent: 300,
            ),
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  DateTimeRange? dateRange = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2022),
                    lastDate: DateTime.now(),
                    helpText: 'Pilih Rentang Tanggal',
                  );
                  if (dateRange != null) {
                    final exportService = ExportService();
                    await exportService.exportDataToExcel(
                      context,
                      startDate: dateRange.start,
                      endDate: dateRange.end,
                    );
                  }
                },
                icon: const Icon(Icons.download, size: 24),
                label: const Text(
                  'Export data sensor',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF8547b0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  shadowColor: Colors.grey.withOpacity(0.5),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Satu Card untuk semua switch
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
              color: const Color.fromARGB(255, 255, 255, 255),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  children: [
                    _buildAlarmSwitch(
                      title: 'Boiler Notification',
                      value: isTask1On,
                      onChanged: (value) {
                        setState(() {
                          isTask1On = value;
                          updateServiceData();
                        });
                        _saveSwitchState("task1", value);
                      },
                    ),
                    _buildAlarmSwitch(
                      title: 'OFDA Notification',
                      value: isTask2On,
                      onChanged: (value) {
                        setState(() {
                          isTask2On = value;
                          updateServiceData();
                        });
                        _saveSwitchState("task2", value);
                      },
                    ),
                    _buildAlarmSwitch(
                      title: 'Chiller Notification',
                      value: isTask3On,
                      onChanged: (value) {
                        setState(() {
                          isTask3On = value;
                          updateServiceData();
                        });
                        _saveSwitchState("task3", value);
                      },
                    ),
                    _buildAlarmSwitch(
                      title: 'Tk201 Notification',
                      value: isTask4On,
                      onChanged: (value) {
                        setState(() {
                          isTask4On = value;
                          updateServiceData();
                        });
                        _saveSwitchState("task4", value);
                      },
                    ),
                    _buildAlarmSwitch(
                      title: 'Tk202 Notification',
                      value: isTask5On,
                      onChanged: (value) {
                        setState(() {
                          isTask5On = value;
                          updateServiceData();
                        });
                        _saveSwitchState("task5", value);
                      },
                    ),
                    _buildAlarmSwitch(
                      title: 'Tk103 Notification',
                      value: isTask6On,
                      onChanged: (value) {
                        setState(() {
                          isTask6On = value;
                          updateServiceData();
                        });
                        _saveSwitchState("task6", value);
                      },
                    ),
                    _buildAlarmSwitch(
                      title: 'AHU LB Notification',
                      value: isTask7On,
                      onChanged: (value) {
                        setState(() {
                          isTask7On = value;
                          updateServiceData();
                        });
                        _saveSwitchState("task7", value);
                      },
                    ),
                    // ...existing code...
                    _buildAlarmSwitch(
                      title: 'UF Notification',
                      value: isTask8On,
                      onChanged: (value) {
                        setState(() {
                          isTask8On = value;
                          updateServiceData();
                        });
                        _saveSwitchState("task8", value);
                      },
                    ),
                    _buildAlarmSwitch(
                      title: 'Fault Pump Notification',
                      value: isTask9On,
                      onChanged: (value) {
                        setState(() {
                          isTask9On = value;
                          updateServiceData();
                        });
                        _saveSwitchState("task9", value);
                      },
                    ),
                    _buildAlarmSwitch(
                      title: 'Surface Tank Notification',
                      value: isTask10On,
                      onChanged: (value) {
                        setState(() {
                          isTask10On = value;
                          updateServiceData();
                        });
                        _saveSwitchState("task10", value);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmSwitch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF532F8F),
            inactiveTrackColor: const Color(0xFFFF6B6B),
            inactiveThumbColor: const Color.fromARGB(255, 219, 6, 6),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  void printAlarmHistory() {
    final box = Hive.box('alarmHistoryBox');
    final alarmEntries = box.toMap();

    alarmEntries.forEach((key, value) {
      print('Key: $key');
      print('Alarm Entry: $value');
    });
  }

  Widget _buildHistoryContent() {
    return Padding(
      padding:
          const EdgeInsets.only(top: 185.0), // Sesuaikan dengan tinggi app bar
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Align ke kiri
          children: [
            // Menambahkan judul halaman
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0), // Jarak dari tepi
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Align teks ke kiri
                children: [
                  Text(
                    'Alarm History', // Judul halaman
                    style: const TextStyle(
                      fontSize: 20, // Ukuran font untuk judul
                      fontWeight:
                          FontWeight.bold, // Membuat judul menjadi tebal
                      color: Color.fromARGB(255, 0, 0, 0), // Warna judul
                    ),
                  ),
                  Divider(
                    thickness: 2, // Ketebalan garis
                    color: Colors.black, // Warna garis
                    indent: 0, // Jarak dari tepi kiri
                    endIndent: 280, // Jarak dari tepi kanan
                  ),
                ],
              ),
            ),

            // List alarm
            // Padding(
            //   padding: const EdgeInsets.only(
            //       bottom: 68.0), // Padding bottom untuk setiap item
            ValueListenableBuilder(
              valueListenable: _alarmHistoryBox.listenable(),
              builder: (context, Box box, _) {
                final alarmEntries = box.toMap().entries.toList();
                print(
                    'Updated alarm entries: ${alarmEntries.length}'); // Debug print

                if (alarmEntries.isEmpty) {
                  return Center(
                    child: Text(
                      'No alarm history found.', // Pesan placeholder
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                // Fungsi untuk memformat atau memparsing timestamp
                DateTime parseTimestamp(dynamic timestamp) {
                  if (timestamp is DateTime) {
                    return timestamp;
                  } else if (timestamp is String) {
                    try {
                      return DateFormat('yyyy-MM-dd HH:mm:ss').parse(timestamp);
                    } catch (e) {
                      print('Error parsing timestamp: $e');
                      return DateTime.now(); // Atau nilai default
                    }
                  } else {
                    return DateTime.now();
                  }
                }

                // Mengurutkan alarm berdasarkan timestamp, terbaru di atas
                alarmEntries.sort((a, b) {
                  DateTime timestampA = parseTimestamp(a.value['timestamp']);
                  DateTime timestampB = parseTimestamp(b.value['timestamp']);
                  return timestampB.compareTo(timestampA);
                });

                // Membuat daftar alarm
                return Column(
                  children: alarmEntries.map((entry) {
                    final key = entry.key; // Mengambil kunci dari item

                    // Melakukan casting ke Map<String, dynamic>
                    final Map<String, dynamic> alarm =
                        Map<String, dynamic>.from(entry.value);

                    // Format timestamp ke string sederhana
                    DateTime timestamp = parseTimestamp(alarm['timestamp']);
                    String formattedTimestamp =
                        DateFormat('MMMM dd, yyyy HH:mm WIB').format(timestamp);

                    // Menampilkan nama alarm dan nilai sensor di judul
                    String title = _buildAlarmTitle(alarm);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 16),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(35), // Rounded corners
                      ),
                      color: const Color.fromARGB(255, 255, 255, 255),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        ),
                        subtitle: Text(
                          formattedTimestamp,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete,
                              color: Color(0xFF532F8F)),
                          onPressed: () {
                            box.delete(key);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            // ),
          ],
        ),
      ),
    );
  }

// Fungsi untuk memparsing timestamp dari alarm
  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is DateTime) {
      // Jika sudah DateTime, langsung dikembalikan
      return timestamp;
    } else if (timestamp is String) {
      // Jika String, coba parsing
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return DateTime
            .now(); // Jika gagal, gunakan waktu sekarang sebagai fallback
      }
    } else {
      // Fallback jika format tidak valid
      return DateTime.now();
    }
  }

// Fungsi untuk memformat timestamp ke format yang diinginkan
  String _formatTimestamp(dynamic timestamp) {
    DateTime date =
        _parseTimestamp(timestamp); // Pastikan timestamp sudah di-parse
    return DateFormat('MMMM dd, yyyy HH:mm WIB')
        .format(date); // Format menjadi string
  }

// Fungsi untuk membuat judul alarm
  String _buildAlarmTitle(Map<String, dynamic> alarm) {
    String alarmName = alarm['alarmName'] ?? 'Unknown Alarm';
    if (alarmName == 'boiler' ||
        alarmName == 'chiller' ||
        alarmName == 'ofda') {
      return alarmName; // Hanya menampilkan nama alarm
    } else {
      String sensorValue = alarm['sensorValue']?.toString() ?? 'N/A';
      return '$alarmName - $sensorValue°'; // Menampilkan nama alarm dan nilai sensor
    }
  }

  Widget _buildHomeContent() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.only(top: 178.0),
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    children: [
                      // Halaman pertama: Boiler, Chiller, OFDA, dst
                      Padding(
                        key: const PageStorageKey('page1'),
                        padding: const EdgeInsets.all(8.0),
                        child: RawScrollbar(
                          thumbVisibility: true,
                          thickness: 3,
                          radius: const Radius.circular(10),
                          thumbColor: const Color(0xFF532F8F).withOpacity(0.8),
                          fadeDuration: const Duration(milliseconds: 500),
                          pressDuration: const Duration(milliseconds: 100),
                          child: SingleChildScrollView(
                            primary: false,
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  // Card utama: Tank + Domestic Pump
                                  Card(
                                    elevation: 5,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    color: Colors.white,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 24, horizontal: 18),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          // Tampilkan tank pakai StreamBuilder juga
                                          StreamBuilder<int>(
                                            stream: _highStream,
                                            builder: (context, highSnapshot) {
                                              return StreamBuilder<int>(
                                                stream: _lowStream,
                                                builder:
                                                    (context, lowSnapshot) {
                                                  final high =
                                                      highSnapshot.data ?? 0;
                                                  final low =
                                                      lowSnapshot.data ?? 0;

                                                  return TankLevelWidget(
                                                    high: high,
                                                    low: low,
                                                    width: 100,
                                                    height: 160,
                                                    label: "Domestic Tank",
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 15),

                                          // Domestic Pump
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Image.asset(
                                                  'assets/images/waterpump.png',
                                                  width: 60,
                                                  height: 60,
                                                  fit: BoxFit.contain,
                                                ),
                                                const SizedBox(height: 8),
                                                const Text(
                                                  'Domestic Pump',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                  maxLines: 2,
                                                  softWrap: true,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 8),

                                                // Pakai StreamBuilder untuk faultPump
                                                StreamBuilder<int>(
                                                  stream: dataService
                                                      .faultPumpStream,
                                                  builder: (context, snapshot) {
                                                    final status =
                                                        snapshot.data ?? 0;

                                                    return Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 4,
                                                          horizontal: 12),
                                                      decoration: BoxDecoration(
                                                        color: status == 0
                                                            ? const Color(
                                                                0xFF6FCF97) // Normal (Hijau)
                                                            : const Color(
                                                                0xFFFF6B6B), // Fault (Merah)
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8.0),
                                                      ),
                                                      child: Text(
                                                        status == 0
                                                            ? "Normal"
                                                            : "Abnormal",
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // const SizedBox(height: 24),
                                  // Grid kecil untuk status lain
                                  GridView.count(
                                    crossAxisCount: 2,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: 1.3,
                                    children: [
                                      StreamBuilder<int>(
                                        stream: dataService.boilerStream,
                                        builder: (context, snapshot) {
                                          int boiler = snapshot.data ?? 0;
                                          return _buildStatusWidget(
                                            'Boiler',
                                            boiler,
                                            'assets/images/3dboiler.png',
                                            60,
                                            78,
                                          );
                                        },
                                      ),
                                      StreamBuilder<int>(
                                        stream: dataService.ofdaStream,
                                        builder: (context, snapshot) {
                                          final status = snapshot.data ?? 0;
                                          return _buildStatusWidget(
                                            'OFDA',
                                            status,
                                            'assets/images/3dofda.png',
                                            60,
                                            118,
                                          );
                                        },
                                      ),
                                      StreamBuilder<int>(
                                        stream: dataService.chillerStream,
                                        builder: (context, snapshot) {
                                          final status = snapshot.data ?? 0;
                                          return _buildStatusWidget(
                                            'Chiller',
                                            status,
                                            'assets/images/3dchiller.png',
                                            60,
                                            78,
                                          );
                                        },
                                      ),
                                      StreamBuilder<int>(
                                        stream: dataService.ufStream,
                                        builder: (context, snapshot) {
                                          final status = snapshot.data ?? 0;
                                          return _buildStatusWidget(
                                            'UF',
                                            status,
                                            'assets/images/UF.png', // ganti dengan gambar UF
                                            60,
                                            118,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Halaman kedua: Current Temperature dan Graphic Temperature
                      Padding(
                        key: const PageStorageKey('page2'),
                        padding: const EdgeInsets.only(
                            top: 25.0, left: 16, right: 30, bottom: 16),
                        child: SingleChildScrollView(
                          primary: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8.0, horizontal: 16.0),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Vent Filter",
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                      textAlign: TextAlign.start,
                                    ),
                                    SizedBox(
                                        height:
                                            4), // Jarak antara teks dan garis
                                    Divider(
                                      thickness: 2, // Ketebalan garis
                                      color: Colors.black, // Warna garis
                                      indent: 0, // Jarak dari tepi kiri
                                      endIndent: 150, // Jarak dari tepi kanan
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Container for Current Temperature display
                              Container(
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.3),
                                      spreadRadius: 2,
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Current Temperature",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildCircularValue('Tk201', tk201),
                                        _buildCircularValue('Tk202', tk202),
                                        _buildCircularValue('Tk103', tk103),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Title and Chart
                              const Text(
                                "Graphic Temperature",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildChartVentFilter(),
                            ],
                          ),
                        ),
                      ),

                      // Halaman Ketigaa: temp_ahu04lb - Hot LOOP
                      Padding(
                        key: const PageStorageKey('page3'),
                        padding: const EdgeInsets.only(
                            top: 25.0, left: 16, right: 16, bottom: 16),
                        child: SingleChildScrollView(
                          primary: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8.0, horizontal: 16.0),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "LBENG-AHU-04",
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                      textAlign: TextAlign.start,
                                    ),
                                    SizedBox(
                                        height:
                                            4), // Jarak antara teks dan garis
                                    Divider(
                                      thickness: 2, // Ketebalan garis
                                      color: Colors.black, // Warna garis
                                      indent: 0, // Jarak dari tepi kiri
                                      endIndent: 150, // Jarak dari tepi kanan
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Container for Current Temperature display
                              Container(
                                width: 5,
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.3),
                                      spreadRadius: 2,
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Current Status",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildCircularValueTempAhu(
                                            'Temperature', temp_ahu04lb),
                                        _buildCircularValueRhAhu(
                                            'Humidity', rh_ahu04lb),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Title and Chart
                              const Text(
                                "Graphic Temperature & Humidity",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildChart_ahu04lb(),
                            ],
                          ),
                        ),
                      ),

                      // Halaman Keempat: Ofda
                      // Padding(
                      //   padding: const EdgeInsets.only(
                      //       top: 25.0, left: 16, right: 16, bottom: 16),
                      //   child: SingleChildScrollView(
                      //     child: Column(
                      //       crossAxisAlignment: CrossAxisAlignment.stretch,
                      //       children: [
                      //         Container(
                      //           padding: const EdgeInsets.symmetric(
                      //               vertical: 8.0, horizontal: 16.0),
                      //           child: const Column(
                      //             crossAxisAlignment: CrossAxisAlignment.start,
                      //             children: [
                      //               Text(
                      //                 "Pressure Ofda",
                      //                 style: TextStyle(
                      //                   fontSize: 18,
                      //                   fontWeight: FontWeight.bold,
                      //                   color: Colors.black,
                      //                 ),
                      //                 textAlign: TextAlign.start,
                      //               ),
                      //               SizedBox(
                      //                   height:
                      //                       4), // Jarak antara teks dan garis
                      //               Divider(
                      //                 thickness: 2, // Ketebalan garis
                      //                 color: Colors.black, // Warna garis
                      //                 indent: 0, // Jarak dari tepi kiri
                      //                 endIndent: 150, // Jarak dari tepi kanan
                      //               ),
                      //             ],
                      //           ),
                      //         ),
                      //         const SizedBox(height: 10),

                      //         // Container for Current Temperature display
                      //         Container(
                      //           width: 5,
                      //           padding: const EdgeInsets.all(16.0),
                      //           decoration: BoxDecoration(
                      //             color: Colors.white,
                      //             borderRadius: BorderRadius.circular(12.0),
                      //             boxShadow: [
                      //               BoxShadow(
                      //                 color: Colors.grey.withOpacity(0.3),
                      //                 spreadRadius: 2,
                      //                 blurRadius: 8,
                      //                 offset: const Offset(0, 3),
                      //               ),
                      //             ],
                      //           ),
                      //           child: Column(
                      //             crossAxisAlignment: CrossAxisAlignment.start,
                      //             children: [
                      //               const Text(
                      //                 "Current Pressure",
                      //                 style: TextStyle(
                      //                   fontSize: 16,
                      //                   fontWeight: FontWeight.bold,
                      //                 ),
                      //               ),
                      //               const SizedBox(height: 16),
                      //               Row(
                      //                 mainAxisAlignment:
                      //                     MainAxisAlignment.spaceAround,
                      //                 children: [
                      //                   _buildCircularValueOfda('', rh_ahu04lb),
                      //                   _buildStatusTextOfda(rh_ahu04lb, ofda)
                      //                 ],
                      //               ),
                      //             ],
                      //           ),
                      //         ),
                      //         const SizedBox(height: 16),

                      //         // Title and Chart
                      //         const Text(
                      //           "Graphic Temperature",
                      //           style: TextStyle(
                      //             fontSize: 16,
                      //             fontWeight: FontWeight.bold,
                      //           ),
                      //         ),
                      //         const SizedBox(height: 16),
                      //         _buildChartOfda(),
                      //       ],
                      //     ),
                      //   ),
                      // )
                    ],
                  ),
                ),
                // Smooth Page Indicator
                Padding(
                  padding: const EdgeInsets.only(
                      bottom: 2.0), // Atur jarak sesuai kebutuhan
                  child: SmoothPageIndicator(
                    controller: _pageController,
                    count: 3, // Jumlah halaman yang ada di PageView
                    effect: WormEffect(
                      dotHeight: 8.0,
                      dotWidth: 8.0,
                      activeDotColor: const Color(0xFF532F8F),
                      dotColor: Colors.grey.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          );
  }

  // Widget _buildStatusWidget(
  //   String label,
  //   int status,
  //   String assetImage,
  //   double imageWidth,
  //   double imageHeight,
  // ) {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(14),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.grey.withOpacity(0.12),
  //           blurRadius: 4,
  //           offset: const Offset(0, 2),
  //         ),
  //       ],
  //     ),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.center,
  //       children: [
  //         Image.asset(
  //           assetImage,
  //           width: imageWidth,
  //           height: imageHeight,
  //           fit: BoxFit.contain,
  //         ),
  //         const SizedBox(width: 12),
  //         Expanded(
  //           child: Column(
  //             mainAxisAlignment: MainAxisAlignment.center,
  //             crossAxisAlignment: CrossAxisAlignment.center,
  //             children: [
  //               Text(
  //                 label,
  //                 style: const TextStyle(
  //                   fontSize: 13,
  //                   fontWeight: FontWeight.w600,
  //                   color: Colors.black87,
  //                 ),
  //                 textAlign: TextAlign.center,
  //                 maxLines: 2, // Maksimal 2 baris
  //                 softWrap: true, // Boleh wrap
  //                 overflow: TextOverflow.ellipsis,
  //               ),
  //               const SizedBox(height: 10),
  //               Container(
  //                 width: 22,
  //                 height: 22,
  //                 decoration: BoxDecoration(
  //                   color: status == 1
  //                       ? const Color(0xFF6FCF97)
  //                       : const Color(0xFFFF6B6B),
  //                   shape: BoxShape.circle,
  //                   border: Border.all(
  //                     color: Colors.black12,
  //                     width: 2,
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  Widget _buildStatusWidget(
    String label,
    int status,
    String assetImage,
    double imageWidth,
    double imageHeight,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            assetImage,
            width: imageWidth,
            height: imageHeight,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),

                // ✅ Tampilkan status teks, bukan bulat lagi
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  decoration: BoxDecoration(
                    color: status == 1
                        ? const Color(0xFF6FCF97) // Hijau: Normal
                        : const Color(0xFFFF6B6B), // Merah: Abnormal
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    status == 1 ? "Normal" : "Abnormal",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Widget untuk menampilkan grafik
  Widget _buildChartVentFilter() {
    return ValueListenableBuilder(
      valueListenable: Hive.box('sensorDataBox').listenable(),
      builder: (context, Box box, _) {
        if (!box.containsKey('sensorDataList')) {
          return Center(child: Text("No sensor data available"));
        }

        final sensorDataList = box.get('sensorDataList') as List;

        // // Clear previous data
        _tk201Data.clear();
        _tk202Data.clear();
        _tk103Data.clear();

        // Tentukan rentang X untuk menampilkan 10 data terbaru
        int range = 10;
        int totalDataLength = sensorDataList.length;
        int start = (totalDataLength > range) ? totalDataLength - range : 0;
        double minX = 0;
        double maxX =
            (totalDataLength > range) ? range - 1 : totalDataLength - 1;

        List<String> timeLabels = [];
        // Batasan untuk rentang Y
        double minY = 60;
        double maxY = 85;

        // Loop dari data terbaru ke terlama, mulai dari index start
        for (int i = start; i < totalDataLength; i++) {
          final sensorData = sensorDataList[i];

          // Cek nilai sebelum menambahkannya
          double tk201Value = sensorData['tk201']?.toDouble() ?? 0;
          double tk202Value = sensorData['tk202']?.toDouble() ?? 0;
          double tk103Value = sensorData['tk103']?.toDouble() ?? 0;

          var timestampValue = sensorData['timestamp'];

          // Pastikan nilai tetap dalam batas minY dan maxY
          tk201Value = tk201Value.clamp(minY, maxY);
          tk202Value = tk202Value.clamp(minY, maxY);
          tk103Value = tk103Value.clamp(minY, maxY);

          if (!tk201Value.isNaN && !tk201Value.isInfinite) {
            _tk201Data.add(FlSpot((i - start).toDouble(), tk201Value));
          }
          if (!tk202Value.isNaN && !tk202Value.isInfinite) {
            _tk202Data.add(FlSpot((i - start).toDouble(), tk202Value));
          }
          if (!tk103Value.isNaN && !tk103Value.isInfinite) {
            _tk103Data.add(FlSpot((i - start).toDouble(), tk103Value));
          }

          // Menyimpan timestamp sebagai label waktu
          if (timestampValue is String) {
            try {
              DateTime timestamp =
                  DateFormat('dd/MM/yyyy HH:mm').parse(timestampValue);
              timeLabels.add(DateFormat('HH:mm').format(timestamp));
            } catch (e) {
              print('Error parsing timestamp: $timestampValue'); // Debugging
            }
          }
        }

        return Container(
          height: 300, // Tinggi kontainer grafik
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: 2.0), // Menambahkan padding horizontal

          child: Column(
            children: [
              Expanded(
                flex: 8,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                  top: 50, left: 10, bottom: 45),
                              child: Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                    color: Colors.black, fontSize: 12),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, // Tampilkan label sumbu bawah
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            // Pastikan indeks tidak melebihi jumlah data
                            if (value.toInt() < timeLabels.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 15),
                                child: Text(
                                  timeLabels[value.toInt()],
                                  style: const TextStyle(
                                      color: Colors.black, fontSize: 10),
                                ),
                              );
                            } else {
                              return const SizedBox();
                            }
                          },
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    minX: minX,
                    maxX: maxX,
                    minY: minY,
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _tk201Data,
                        isCurved: false,
                        curveSmoothness: 0.2,
                        color: const Color(0xFFed4d9b),
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                      LineChartBarData(
                        spots: _tk202Data,
                        isCurved: false,
                        curveSmoothness: 0.2,
                        color: const Color.fromARGB(255, 77, 237, 184),
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                      LineChartBarData(
                        spots: _tk103Data,
                        isCurved: false,
                        curveSmoothness: 0.2,
                        color: const Color(0xFFC6849B),
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLegend(color: const Color(0xFFed4d9b), label: 'Tk201'),
                  _buildLegend(
                      color: const Color.fromARGB(255, 77, 237, 184),
                      label: 'Tk202'),
                  _buildLegend(color: const Color(0xFFC6849B), label: 'Tk103'),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

// Widget untuk menampilkan grafik
  Widget _buildChart_ahu04lb() {
    return ValueListenableBuilder(
      valueListenable: Hive.box('sensorDataBox').listenable(),
      builder: (context, Box box, _) {
        if (!box.containsKey('sensorDataList')) {
          return Center(child: Text("No sensor data available"));
        }

        final sensorDataList = box.get('sensorDataList') as List;

        // // Clear previous data
        _temp_ahu04lbData.clear();
        _rh_ahu04lbData.clear();

        // Tentukan rentang X untuk menampilkan 10 data terbaru
        int range = 10;
        int totalDataLength = sensorDataList.length;
        int start = (totalDataLength > range) ? totalDataLength - range : 0;
        double minX = 0;
        double maxX =
            (totalDataLength > range) ? range - 1 : totalDataLength - 1;

        List<String> timeLabels = [];
        // Batasan untuk rentang Y
        double minY = 15;
        double maxY = 70;

        // Loop dari data terbaru ke terlama, mulai dari index start
        for (int i = start; i < totalDataLength; i++) {
          final sensorData = sensorDataList[i];

          // Cek nilai sebelum menambahkannya
          double temp_ahu04lbValue =
              sensorData['temp_ahu04lb']?.toDouble() ?? 0;
          double rh_ahu04lbValue = sensorData['rh_ahu04lb']?.toDouble() ?? 0;

          var timestampValue = sensorData['timestamp'];

          // Pastikan nilai tetap dalam batas minY dan maxY
          temp_ahu04lbValue = temp_ahu04lbValue.clamp(minY, maxY);
          rh_ahu04lbValue = rh_ahu04lbValue.clamp(minY, maxY);

          if (!temp_ahu04lbValue.isNaN && !temp_ahu04lbValue.isInfinite) {
            _temp_ahu04lbData
                .add(FlSpot((i - start).toDouble(), temp_ahu04lbValue));
          }
          if (!rh_ahu04lbValue.isNaN && !rh_ahu04lbValue.isInfinite) {
            _rh_ahu04lbData
                .add(FlSpot((i - start).toDouble(), rh_ahu04lbValue));
          }

          // Menyimpan timestamp sebagai label waktu
          if (timestampValue is String) {
            try {
              DateTime timestamp =
                  DateFormat('dd/MM/yyyy HH:mm').parse(timestampValue);
              timeLabels.add(DateFormat('HH:mm').format(timestamp));
            } catch (e) {
              print('Error parsing timestamp: $timestampValue'); // Debugging
            }
          }
        }

        return Container(
          height: 300, // Tinggi kontainer grafik
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: 2.0), // Menambahkan padding horizontal

          child: Column(
            children: [
              Expanded(
                flex: 8,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                  top: 50, left: 10, bottom: 45),
                              child: Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                    color: Colors.black, fontSize: 12),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, // Tampilkan label sumbu bawah
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            // Pastikan indeks tidak melebihi jumlah data
                            if (value.toInt() < timeLabels.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 15),
                                child: Text(
                                  timeLabels[value.toInt()],
                                  style: const TextStyle(
                                      color: Colors.black, fontSize: 10),
                                ),
                              );
                            } else {
                              return const SizedBox();
                            }
                          },
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    minX: minX,
                    maxX: maxX,
                    minY: minY,
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _temp_ahu04lbData,
                        isCurved: false,
                        curveSmoothness: 0.2,
                        color: const Color(0xFFed4d9b),
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                      LineChartBarData(
                        spots: _rh_ahu04lbData,
                        isCurved: false,
                        curveSmoothness: 0.2,
                        color: const Color.fromARGB(255, 77, 237, 184),
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLegend(
                      color: const Color(0xFFed4d9b), label: 'Temperature'),
                  _buildLegend(
                      color: const Color.fromARGB(255, 77, 237, 184),
                      label: 'Humidity'),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildValueWidget(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularValue(String label, double value) {
    Color color = value < 65 || value > 80
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF8547b0);
    return CircularValue(
      label: label,
      valueText: '${value.toInt()}°C',
      color: color,
    );
  }

  Widget _buildCircularValueTempAhu(String label, double value) {
    Color color = value < 18 || value > 27
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF8547b0);
    return CircularValue(
      label: label,
      valueText: '${value.toInt()}°C',
      color: color,
    );
  }

  Widget _buildCircularValueRhAhu(String label, double value) {
    Color color = value < 55 || value > 70
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF8547b0);
    return CircularValue(
      label: label,
      valueText: '${value.toInt()}%',
      color: color,
    );
  }

  Widget _buildCircularValueOfda(String label, double value) {
    Color color = value < 5.0 || value > 8.0
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF8547b0);
    return CircularValue(
      label: label,
      valueText: '${value.toStringAsFixed(1)} bar',
      color: color,
    );
  }

  Widget _buildStatusTexttemp_ahu04lb(double value) {
    String status = (value < 18 || value > 27) ? "Abnormal" : "Normal";
    Color backgroundColor = (value < 18 || value > 27)
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF6FCF97);
    return StatusText(status: status, backgroundColor: backgroundColor);
  }

  Widget _buildStatusTextOfda(double value, int value_on) {
    String status = (value < 5 || value_on == 0) ? "Abnormal" : "Normal";
    Color backgroundColor = (value < 5 || value_on == 0)
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF6FCF97);
    return StatusText(status: status, backgroundColor: backgroundColor);
  }

  Widget _buildLegend({required Color color, required String label}) {
    return LegendDot(color: color, label: label);
  }

  Future<void> _saveSwitchState(String key, bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}

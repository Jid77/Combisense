import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:async';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:aplikasitest1/services/background_task_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:aplikasitest1/widgets/background_wave.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aplikasitest1/services/export_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static final GlobalKey<_HomePageState> _key = GlobalKey<_HomePageState>();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  // Deklarasikan _dataService sebagai variabel instance
  final DataService _dataService = DataService();

  final List<FlSpot> _tk201Data = [];
  final List<FlSpot> _tk202Data = [];
  final List<FlSpot> _tk103Data = [];
  final List<FlSpot> _pwgData = [];
  final List<FlSpot> _p_ofdaData = [];
  int _boilerStatus = 0;
  int _ofdaStatus = 0;
  int _oilessStatus = 0;
  final List<String> _timestamps = [];
  int _index = 0;

  late Timer _timer;
  late Box _sensorDataBox;
  late Box _alarmHistoryBox;
  final DateFormat formatter = DateFormat('HH:mm');

  final PageController _pageController = PageController();

  bool _isLoading = true;
  int _selectedIndex = 0;

  // data
  int boiler = 0;
  int oiless = 0;
  int ofda = 0;
  double tk201 = 0;
  double tk202 = 0;
  double tk103 = 0;
  double pwg = 0;
  double p_ofda = 0;

  // State untuk mengontrol status alarm
  bool isTask1On = false;
  bool isTask2On = false;
  bool isTask3On = false;
  bool isTask4On = false;
  bool isTask5On = false;
  bool isTask6On = false;
  bool isTask7On = false;

  //  excel - timestamp
  final ExportService _exportService = ExportService();
  DateTimeRange? selectedDateRange;
  @override
  void initState() {
    super.initState();
    // _sensorDataBox = Hive.box('sensorDataBox');
    _alarmHistoryBox = Hive.box('alarmHistoryBox');
    _initHive(); // Inisialisasi Hive sebelum digunakan
    _loadSwitchState();
    _startListening();
    printAlarmHistory();
    // Timer.periodic(const Duration(seconds: 27), (timer) {
    //   // _loadDataFromHive();
    //   // print("Isi Hive periodic: ${_sensorDataBox.toMap()}");
    // });
    _isLoading = false;
  }

  Future<void> _initHive() async {
    await Hive.openBox(
        'sensorDataBox'); // Buka Hive Box bernama 'sensorDataBox'
    await Hive.openBox('alarmHistoryBox');
  }

  Future<void> _loadData() async {
    await _dataService.fetchData(
      0,
      [],
      [],
      [],
      [],
      [],
      [],
      DateFormat('yyyy-MM-dd HH:mm:ss'),
      (newBoiler, newOiless, newOfda, newTk201, newTk202, newTk103, newPwg,
          newP_ofda) {
        setState(() {
          boiler = newBoiler;
          oiless = newOiless;
          ofda = newOfda;
          tk201 = newTk201;
          tk202 = newTk202;
          tk103 = newTk103;
          pwg = newPwg;
          p_ofda = newP_ofda;
        });
      },
    );
  }

  void _startListening() {
    _database.child('sensor_data').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>;

      // Ambil data terbaru
      setState(() {
        boiler = data['boiler'] ?? 0;
        oiless = data['oiless'] ?? 0;
        ofda = data['ofda'] ?? 0;
        tk201 = (data['tk201']?.toDouble() ?? 0);
        tk202 = (data['tk202']?.toDouble() ?? 0);
        tk103 = (data['tk103']?.toDouble() ?? 0);
        pwg = (data['pwg']?.toDouble() ?? 0);
        p_ofda = (data['p_ofda']?.toDouble() ?? 0);
      });

      // Simpan data ke Hive
      _saveDataToHive(data);
    });
  }

  Future<void> _saveDataToHive(Map<dynamic, dynamic> data) async {
    final sensorDataBox = await Hive.box('sensorDataBox');
    List<dynamic> sensorDataList =
        sensorDataBox.get('sensorDataList', defaultValue: []);
    final sensorData = {
      'tk201': data['tk201'],
      'tk202': data['tk202'],
      'tk103': data['tk103'],
      'pwg': data['pwg'],
      'p_ofda': data['p_ofda'],
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
    });
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("Is loading: $_isLoading");
    return Scaffold(
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
          _selectedIndex == 0
              ? _buildHomeContent()
              : _selectedIndex == 1
                  ? _buildHistoryContent()
                  : _buildAlarmSwitchContent(),
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
    );
  }

  Widget _buildAlarmSwitchContent() {
    return Padding(
      padding: const EdgeInsets.only(top: 185.0, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Divider(
            thickness: 2, // Ketebalan garis
            color: Colors.black, // Warna garis
            indent: 0, // Jarak dari tepi kiri
            endIndent: 300, // Jarak dari tepi kanan
          ),
          // const SizedBox(height: 10),
          Center(
            child: ElevatedButton.icon(
              onPressed: () async {
                // Tampilkan dialog untuk memilih rentang waktu
                DateTimeRange? dateRange = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2022), // Tanggal awal yang dapat dipilih
                  lastDate: DateTime.now(), // Tanggal akhir yang dapat dipilih
                  helpText: 'Pilih Rentang Tanggal',
                );

                if (dateRange != null) {
                  final exportService = ExportService();
                  // Panggil fungsi exportDataToExcel dengan rentang waktu yang dipilih
                  await exportService.exportDataToExcel(
                    context,
                    startDate: dateRange.start,
                    endDate: dateRange.end,
                  );
                }
              },
              icon: const Icon(Icons.download, size: 24), // Icon download
              label: const Text(
                'Export data sensor',
                style: TextStyle(fontSize: 16), // Ukuran font
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF8547b0), // Warna teks
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12), // Padding tombol
                elevation: 5, // Elevasi untuk efek bayangan
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32), // Sudut melengkung
                ),
                shadowColor: Colors.grey.withOpacity(0.5), // Warna bayangan
              ),
            ),
          ),
          const SizedBox(height: 10), // Space between button and switches
          _buildAlarmSwitch(
            title: 'Boiler Notification',
            value: isTask1On,
            onChanged: (value) {
              setState(() {
                isTask1On = value;
                updateServiceData(); // Update data ke background service
              });
            },
          ),
          _buildAlarmSwitch(
            title: 'OFDA Notification',
            value: isTask2On,
            onChanged: (value) {
              setState(() {
                isTask2On = value;
                updateServiceData(); // Update data ke background service
              });
            },
          ),
          _buildAlarmSwitch(
            title: 'Oiless Notification',
            value: isTask3On,
            onChanged: (value) {
              setState(() {
                isTask3On = value;
                updateServiceData(); // Update data ke background service
              });
            },
          ),
          _buildAlarmSwitch(
            title: 'PWG Hotloop Tank ',
            value: isTask7On,
            onChanged: (value) {
              setState(() {
                isTask7On = value;
                updateServiceData(); // Update data ke background service
              });
            },
          ),
          _buildAlarmSwitch(
            title: 'Vent Filter Tk 201 ',
            value: isTask4On,
            onChanged: (value) {
              setState(() {
                isTask4On = value;
                updateServiceData(); // Update data ke background service
              });
            },
          ),
          _buildAlarmSwitch(
            title: 'Vent Filter Tk 202 ',
            value: isTask5On,
            onChanged: (value) {
              setState(() {
                isTask5On = value;
                updateServiceData(); // Update data ke background service
              });
            },
          ),
          _buildAlarmSwitch(
            title: 'Vent Filter Tk103 ',
            value: isTask6On,
            onChanged: (value) {
              setState(() {
                isTask6On = value;
                updateServiceData(); // Update data ke background service
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmSwitch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      elevation: 3, // Bayangan kotak
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32), // Sudut yang membulat
      ),
      color: const Color.fromARGB(255, 255, 255, 255),

      margin: const EdgeInsets.symmetric(vertical: 2), // Jarak antar switch
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
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
              // activeColor: const Color(0xFF6FCF97),
              activeColor: const Color(0xFF532F8F),
              inactiveTrackColor: const Color(0xFFFF6B6B),
              inactiveThumbColor: const Color.fromARGB(
                  255, 219, 6, 6), // Warna dot saat inactive
              materialTapTargetSize: MaterialTapTargetSize
                  .shrinkWrap, // Opsional, agar switch lebih kecil
            ),
          ],
        ),
      ),
    );
  }

  void printAlarmHistory() {
    final box =
        Hive.box('alarmHistoryBox'); // Ganti dengan nama box yang sesuai
    final alarmEntries = box.toMap(); // Mengambil semua data dalam bentuk map

    // Mencetak setiap entri di box
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
    if (alarmName == 'boiler' || alarmName == 'oiless' || alarmName == 'ofda') {
      return alarmName; // Hanya menampilkan nama alarm
    } else {
      String sensorValue = alarm['sensorValue']?.toString() ?? 'N/A';
      return '$alarmName - $sensorValue°'; // Menampilkan nama alarm dan nilai sensor
    }
  }

  Widget _buildHomeContent() {
    return _isLoading
        ? const Center(
            child:
                CircularProgressIndicator(), // Display loading indicator when fetching data
          )
        : Padding(
            padding: const EdgeInsets.only(
                top: 150.0), // Sesuaikan dengan tinggi app bar
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    children: [
                      // Halaman pertama: Boiler,Oiless
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SingleChildScrollView(
                          // Tambahkan SingleChildScrollView di sini
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              // Box untuk status Boiler
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(16.0),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          40.0),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.grey
                                                          .withOpacity(0.3),
                                                      spreadRadius: 2,
                                                      blurRadius: 8,
                                                      offset:
                                                          const Offset(0, 3),
                                                    ),
                                                  ],
                                                ),
                                                child: _buildStatusWidget(
                                                    'Boiler',
                                                    boiler,
                                                    'assets/images/boiler.png',
                                                    125,
                                                    200), // Menambahkan assetImage
                                              ),
                                              const SizedBox(
                                                  height:
                                                      36), // Spasi antar box
                                              // Box untuk status Oiless
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(16.0),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          40.0),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.grey
                                                          .withOpacity(0.3),
                                                      spreadRadius: 2,
                                                      blurRadius: 8,
                                                      offset:
                                                          const Offset(0, 3),
                                                    ),
                                                  ],
                                                ),
                                                child: _buildStatusWidget(
                                                    'Oiless',
                                                    oiless,
                                                    'assets/images/air-compressor.png',
                                                    115,
                                                    140), // Menambahkan assetImage
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Halaman kedua: Current Temperature dan Graphic Temperature
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 25.0, left: 16, right: 16, bottom: 16),
                        child: SingleChildScrollView(
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
                                      "Temperature Vent Filter",
                                      style: TextStyle(
                                        fontSize: 18,
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

                      // Halaman Ketigaa: PWG - Hot LOOP
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 25.0, left: 16, right: 16, bottom: 16),
                        child: SingleChildScrollView(
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
                                      "Temperature Hot Loop",
                                      style: TextStyle(
                                        fontSize: 18,
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
                                        _buildCircularValue('', pwg),
                                        _buildStatusTextPwg(pwg)
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
                              _buildChartPwg(),
                            ],
                          ),
                        ),
                      ),

                      // Halaman Keempat: Ofda
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 25.0, left: 16, right: 16, bottom: 16),
                        child: SingleChildScrollView(
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
                                      "Pressure Ofda",
                                      style: TextStyle(
                                        fontSize: 18,
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
                                      "Current Pressure",
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
                                        _buildCircularValueOfda('', p_ofda),
                                        _buildStatusTextOfda(p_ofda, ofda)
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
                              _buildChartOfda(),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                // Smooth Page Indicator
                Padding(
                  padding: const EdgeInsets.only(
                      bottom: 2.0), // Atur jarak sesuai kebutuhan
                  child: SmoothPageIndicator(
                    controller: _pageController,
                    count: 4, // Jumlah halaman yang ada di PageView
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

  Widget _buildStatusWidget(String label, int status, String assetImage,
      double imageWidth, double imageHeight) {
    return Container(
      width: 110, // Increased width for better readability
      height: 200,
      padding: const EdgeInsets.all(10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Gambar di sebelah kiri
          Image.asset(
            assetImage, // Menggunakan parameter untuk path gambar
            width: imageWidth, // Ukuran gambar boiler
            height: imageHeight,
          ),
          const SizedBox(width: 10), // Jarak antara gambar dan teks
          // Teks di sebelah kanan
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Memusatkan teks secara vertikal
              crossAxisAlignment: CrossAxisAlignment
                  .center, // Memposisikan teks di sebelah kiri
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: status == 1
                        ? const Color(
                            0xFF6FCF97) // Warna hijau untuk status normal
                        : const Color(
                            0xFFFF6B6B), // Warna merah untuk status abnormal
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    status == 1 ? "Normal" : "Abnormal", // Teks status
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
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
        int range = 15;
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
                        curveSmoothness: 0.1,
                        color: const Color(0xFFed4d9b),
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                      LineChartBarData(
                        spots: _tk202Data,
                        isCurved: false,
                        curveSmoothness: 0.1,
                        color: const Color.fromARGB(255, 77, 237, 184),
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                      LineChartBarData(
                        spots: _tk103Data,
                        isCurved: false,
                        curveSmoothness: 0.1,
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
  Widget _buildChartPwg() {
    return ValueListenableBuilder(
      valueListenable: Hive.box('sensorDataBox').listenable(),
      builder: (context, Box box, _) {
        if (!box.containsKey('sensorDataList')) {
          return Center(child: Text("No sensor data available"));
        }

        final sensorDataList = box.get('sensorDataList') as List;

        // // Clear previous data
        _pwgData.clear();

        // Tentukan rentang X untuk menampilkan 10 data terbaru
        int range = 15;
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
          double pwgValue = sensorData['pwg']?.toDouble() ?? 0;

          var timestampValue = sensorData['timestamp'];

          // Pastikan nilai tetap dalam batas minY dan maxY
          pwgValue = pwgValue.clamp(minY, maxY);

          if (!pwgValue.isNaN && !pwgValue.isInfinite) {
            _pwgData.add(FlSpot((i - start).toDouble(), pwgValue));
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
                        spots: _pwgData,
                        isCurved: false,
                        curveSmoothness: 0.1,
                        color: const Color(0xFFed4d9b),
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
                      color: const Color(0xFFed4d9b), label: 'Hot Loop Tank'),
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

  Widget _buildChartOfda() {
    return ValueListenableBuilder(
      valueListenable: Hive.box('sensorDataBox').listenable(),
      builder: (context, Box box, _) {
        if (!box.containsKey('sensorDataList')) {
          return Center(child: Text("No sensor data available"));
        }

        final sensorDataList = box.get('sensorDataList') as List;

        // // Clear previous data
        _p_ofdaData.clear();

        // Tentukan rentang X untuk menampilkan 10 data terbaru
        int range = 15;
        int totalDataLength = sensorDataList.length;
        int start = (totalDataLength > range) ? totalDataLength - range : 0;
        double minX = 0;
        double maxX =
            (totalDataLength > range) ? range - 1 : totalDataLength - 1;

        List<String> timeLabels = [];
        // Batasan untuk rentang Y
        double minY = 4;
        double maxY = 8;

        // Loop dari data terbaru ke terlama, mulai dari index start
        for (int i = start; i < totalDataLength; i++) {
          final sensorData = sensorDataList[i];

          // Cek nilai sebelum menambahkannya
          double ofdaValue = sensorData['p_ofda']?.toDouble() ?? 0;

          // double tk201Value = sensorData['tk201']?.toDouble() ?? 0;
          // double tk202Value = sensorData['tk202']?.toDouble() ?? 0;
          // double tk103Value = sensorData['tk103']?.toDouble() ?? 0;

          var timestampValue = sensorData['timestamp'];

          // Pastikan nilai tetap dalam batas minY dan maxY
          ofdaValue = ofdaValue.clamp(minY, maxY);
          // tk201Value = tk201Value.clamp(minY, maxY);
          // tk202Value = tk202Value.clamp(minY, maxY);
          // tk103Value = tk103Value.clamp(minY, maxY);

          if (!ofdaValue.isNaN && !ofdaValue.isInfinite) {
            _p_ofdaData.add(FlSpot((i - start).toDouble(), ofdaValue));
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
                        spots: _p_ofdaData,
                        isCurved: false,
                        curveSmoothness: 0.1,
                        color: const Color(0xFFed4d9b),
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
                      color: const Color(0xFFed4d9b), label: 'Pressure Ofda'),
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
    Color circleColor = value < 65 || value > 80
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF8547b0);
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: circleColor, // Ganti warna sesuai kebutuhan
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${value.toInt()}°C',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCircularValueOfda(String label, double value) {
// Membagi value dengan 10 untuk mendapatkan nilai yang benar
    // double valueP = value / 10;

    // Mengatur warna lingkaran berdasarkan nilai valueP
    Color circleColor = value < 5.0 || value > 8.0
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF8547b0);
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: circleColor, // Ganti warna sesuai kebutuhan
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${value.toStringAsFixed(1)} bar',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

// Fungsi untuk menampilkan status Normal/Abnormal
  Widget _buildStatusTextPwg(double value) {
    // Logika menentukan status berdasarkan nilai value (pwg)
    String status = (value < 65 || value > 80) ? "Abnormal" : "Normal";
    Color backgroundColor = (value < 65 || value > 80)
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF6FCF97);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              vertical: 8.0, horizontal: 16.0), // Menambahkan padding dalam box
          decoration: BoxDecoration(
            color: backgroundColor, // Warna background berubah sesuai status
            borderRadius:
                BorderRadius.circular(10.0), // Membuat sudut box melengkung
          ),
          child: Text(
            status,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white, // Teks selalu berwarna putih
            ),
          ),
        ),
        const SizedBox(height: 16), // Memberi jarak di bawah box
      ],
    );
  }

// Fungsi untuk menampilkan status Normal/Abnormal
  Widget _buildStatusTextOfda(double value, int value_on) {
    // Logika menentukan status berdasarkan nilai value (pwg)
    String status = (value < 5 || value_on == 0) ? "Abnormal" : "Normal";
    Color backgroundColor = (value < 5 || value_on == 0)
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF6FCF97);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              vertical: 8.0, horizontal: 16.0), // Menambahkan padding dalam box
          decoration: BoxDecoration(
            color: backgroundColor, // Warna background berubah sesuai status
            borderRadius:
                BorderRadius.circular(10.0), // Membuat sudut box melengkung
          ),
          child: Text(
            status,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white, // Teks selalu berwarna putih
            ),
          ),
        ),
        const SizedBox(height: 16), // Memberi jarak di bawah box
      ],
    );
  }

  Widget _buildLegend({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

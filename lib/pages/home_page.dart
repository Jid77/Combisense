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
import '../widgets/circular_value.dart';
import '../widgets/status_text.dart';
import '../widgets/legend_dot.dart';
import 'indikator_page.dart';
import 'lbeng04_page.dart';
import 'vent_filter_page.dart';
import 'package:combisense/pages/artesis_timer_card.dart';
import 'package:combisense/pages/m800_page.dart';
import 'package:rxdart/rxdart.dart';
import 'package:combisense/services/tf3_service.dart';

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
  final _tf3Service = Tf3Service(name: 'tf3');
  StreamSubscription? _alarmUpdateSub;
  Timer? _reloadDebounce;
  bool _reloading = false;
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

// Alarm Title
  final _num1 = NumberFormat("0.0");
  final _num2 = NumberFormat("0.00");
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
  bool isTask11On = false; //m800
  //  excel - timestamp
  DateTimeRange? selectedDateRange;

  final BehaviorSubject<int> _boilerSubject = BehaviorSubject<int>();
  final BehaviorSubject<int> _ofdaSubject = BehaviorSubject<int>();
  final BehaviorSubject<int> _chillerSubject = BehaviorSubject<int>();
  final BehaviorSubject<int> _ufSubject = BehaviorSubject<int>();
  final BehaviorSubject<int> _faultPumpSubject = BehaviorSubject<int>();
  final BehaviorSubject<int> _highSubject = BehaviorSubject<int>();
  final BehaviorSubject<int> _lowSubject = BehaviorSubject<int>();

  late StreamSubscription<int> _boilerSubscription;
  late StreamSubscription<int> _ofdaSubscription;
  late StreamSubscription<int> _chillerSubscription;
  late StreamSubscription<int> _ufSubscription;
  late StreamSubscription<int> _faultPumpSubscription;
  late StreamSubscription<int> _highSubscription;
  late StreamSubscription<int> _lowSubscription;

  @override
  void initState() {
    super.initState();
    _boilerSubscription = dataService.boilerStream.listen(_boilerSubject.add);
    _ofdaSubscription = dataService.ofdaStream.listen(_ofdaSubject.add);
    _chillerSubscription =
        dataService.chillerStream.listen(_chillerSubject.add);
    _ufSubscription = dataService.ufStream.listen(_ufSubject.add);
    _faultPumpSubscription =
        dataService.faultPumpStream.listen(_faultPumpSubject.add);
    _highSubscription =
        dataService.highSurfaceTankStream.listen(_highSubject.add);
    _lowSubscription = dataService.lowSurfaceTankStream.listen(_lowSubject.add);

    _sensorDataBox = Hive.box('sensorDataBox');
    _alarmHistoryBox = Hive.box('alarmHistoryBox');
    // Dengar sinyal dari background saat ada alarm baru
    _alarmUpdateSub =
        FlutterBackgroundService().on('alarm_update').listen((_) async {
      await _reloadAlarmBox();
    });
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
    _boot();
  }

  Future<void> _boot() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      // pastikan Hive box kebuka di release
      if (!Hive.isBoxOpen('sensorDataBox')) {
        _sensorDataBox = await Hive.openBox('sensorDataBox');
      } else {
        _sensorDataBox = Hive.box('sensorDataBox');
      }
      if (!Hive.isBoxOpen('alarmHistoryBox')) {
        _alarmHistoryBox = await Hive.openBox('alarmHistoryBox');
      } else {
        _alarmHistoryBox = Hive.box('alarmHistoryBox');
      }

      // listener alarm dari background
      _alarmUpdateSub =
          FlutterBackgroundService().on('alarm_update').listen((_) async {
        await _reloadAlarmBox();
      });

      // state switch/checkbox alarm, dsb
      await _loadSwitchState();

      // fetch awal (nggak usah ditunggu pun boleh)
      await executeFetchData();

      // Optional: kalau mau set nilai awal dari Hive
      // await _loadInitialData();
    } catch (e, st) {
      debugPrint('BOOT FAILED: $e\n$st');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false); // ← ini kuncinya
    }
  }

  Future<void> _reloadAlarmBox() async {
    // debounce singkat agar tidak close/open bertubi-tubi
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 250), () async {
      if (_reloading) return;
      _reloading = true;
      try {
        if (Hive.isBoxOpen('alarmHistoryBox')) {
          await _alarmHistoryBox.close();
        }
        _alarmHistoryBox = await Hive.openBox('alarmHistoryBox');
        if (mounted) setState(() {});
      } finally {
        _reloading = false;
      }
    });
  }

  Future<void> _initHive() async {
    await Hive.openBox('sensorDataBox');
    await Hive.openBox('alarmHistoryBox');
  }

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
      isTask11On = prefs.getBool("task11") ?? false;
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
      "task11": isTask11On,
    });
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _boilerSubscription.cancel();
    _ofdaSubscription.cancel();
    _chillerSubscription.cancel();
    _ufSubscription.cancel();
    _faultPumpSubscription.cancel();
    _highSubscription.cancel();
    _lowSubscription.cancel();

    _boilerSubject.close();
    _ofdaSubject.close();
    _chillerSubject.close();
    _ufSubject.close();
    _faultPumpSubject.close();
    _highSubject.close();
    _lowSubject.close();
    // _timer.cancel();
    _reloadDebounce?.cancel();
    _alarmUpdateSub?.cancel();
    _tf3Service.dispose();
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
            Padding(
              padding: const EdgeInsets.only(top: 100, left: 16, right: 16),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Utility Center',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(
                      width: 8), // Jarak kecil antara teks dan gambar
                  Image.asset(
                    'assets/images/combiwhite.png',
                    height: 35,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),

            // Konten berdasarkan indeks yang dipilih
            IndexedStack(
              index: _selectedIndex,
              children: [
                _buildHomeContent(),
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: _buildHistoryContent(context),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: _buildAlarmSwitchContent(context),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: Container(
          margin: const EdgeInsets.only(left: 10, right: 10, bottom: 6, top: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 5,
                offset: Offset(0, 3),
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
          Flexible(
            child: Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
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

  // Konten utama dengan semua tombol switch dan tombol ekspor
  Widget _buildAlarmSwitchContent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: EdgeInsets.only(top: screenWidth * 0.35, left: 16, right: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Divider(
              thickness: 2,
              color: Colors.black,
              endIndent: screenWidth * 0.6,
            ),
            const SizedBox(height: 12),

            // Tombol export
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
                icon: const Icon(Icons.download),
                label: const Text('Export data sensor'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF8547b0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Switch Panel
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6.0),
              padding: const EdgeInsets.all(16.0),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== Header + underline (sepanjang teks) =====
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IntrinsicWidth(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            "Alarm Notification",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(children: [
                          _buildAlarmSwitch(
                            title: 'Boiler',
                            value: isTask1On,
                            onChanged: (v) {
                              setState(() {
                                isTask1On = v;
                                updateServiceData();
                              });
                              _saveSwitchState("task1", v);
                            },
                          ),
                          _buildAlarmSwitch(
                            title: 'OFDA',
                            value: isTask2On,
                            onChanged: (v) {
                              setState(() {
                                isTask2On = v;
                                updateServiceData();
                              });
                              _saveSwitchState("task2", v);
                            },
                          ),
                          _buildAlarmSwitch(
                            title: 'Chiller',
                            value: isTask3On,
                            onChanged: (v) {
                              setState(() {
                                isTask3On = v;
                                updateServiceData();
                              });
                              _saveSwitchState("task3", v);
                            },
                          ),
                          _buildAlarmSwitch(
                              title: 'M800',
                              value: isTask11On,
                              onChanged: (v) {
                                setState(() {
                                  isTask11On = v;
                                  updateServiceData();
                                });
                                _saveSwitchState("task11", v);
                              }),
                          _buildAlarmSwitch(
                            title: 'Vent Tk 201',
                            value: isTask4On,
                            onChanged: (v) {
                              setState(() {
                                isTask4On = v;
                                updateServiceData();
                              });
                              _saveSwitchState("task4", v);
                            },
                          ),
                          _buildAlarmSwitch(
                            title: 'Vent Tk 202',
                            value: isTask5On,
                            onChanged: (v) {
                              setState(() {
                                isTask5On = v;
                                updateServiceData();
                              });
                              _saveSwitchState("task5", v);
                            },
                          ),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(children: [
                          _buildAlarmSwitch(
                              title: 'Vent Tk 103',
                              value: isTask6On,
                              onChanged: (v) {
                                setState(() {
                                  isTask6On = v;
                                  updateServiceData();
                                });
                                _saveSwitchState("task6", v);
                              }),
                          _buildAlarmSwitch(
                              title: 'LBENG-AHU-04',
                              value: isTask7On,
                              onChanged: (v) {
                                setState(() {
                                  isTask7On = v;
                                  updateServiceData();
                                });
                                _saveSwitchState("task7", v);
                              }),
                          _buildAlarmSwitch(
                              title: 'UF',
                              value: isTask8On,
                              onChanged: (v) {
                                setState(() {
                                  isTask8On = v;
                                  updateServiceData();
                                });
                                _saveSwitchState("task8", v);
                              }),
                          _buildAlarmSwitch(
                              title: 'Domestic Pump',
                              value: isTask9On,
                              onChanged: (v) {
                                setState(() {
                                  isTask9On = v;
                                  updateServiceData();
                                });
                                _saveSwitchState("task9", v);
                              }),
                          _buildAlarmSwitch(
                              title: 'Domestic Tank',
                              value: isTask10On,
                              onChanged: (v) {
                                setState(() {
                                  isTask10On = v;
                                  updateServiceData();
                                });
                                _saveSwitchState("task10", v);
                              }),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Combisense © 2025 — Developed by Utitech Team',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenWidth * 0.03,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
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

  Widget _buildHistoryContent(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;

    // hitung tinggi area scroll supaya tidak perlu Expanded (menghindari ParentData error)
    final topPad = screenWidth * 0.35;
    // perkiraan ruang lain (judul, divider, spacing, padding bawah)
    final reserved = 140.0;
    final available =
        size.height - topPad - reserved - MediaQuery.of(context).padding.bottom;
    final scrollHeight =
        available < 220 ? 220.0 : available; // minimal biar bisa di-scroll

    return Padding(
      // parent (IndexedStack) sudah kasih top: 60, jadi cukup kiri/kanan
      padding: EdgeInsets.only(top: topPad, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alarm History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              // IconButton(
              //   icon: Icon(Icons.refresh, color: Color(0xFF532F8F)),
              //   tooltip: 'Reload',
              //   onPressed: _reloadAlarmBox,
              // ),
            ],
          ),
          Divider(
            thickness: 2,
            color: Colors.black,
            endIndent: screenWidth * 0.6,
          ),
          // const SizedBox(height: 12),

          // === AREA SCROLL SAJA UNTUK LIST ===
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reloadAlarmBox,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: ValueListenableBuilder(
                        valueListenable: _alarmHistoryBox.listenable(),
                        builder: (context, Box box, _) {
                          final alarmEntries = box.toMap().entries.toList();

                          DateTime parseTimestamp(dynamic ts) {
                            if (ts is DateTime) return ts;
                            final s = ts?.toString() ?? '';
                            try {
                              return DateFormat('yyyy-MM-dd HH:mm:ss').parse(s);
                            } catch (_) {
                              try {
                                return DateTime.parse(s);
                              } catch (_) {
                                return DateTime.now();
                              }
                            }
                          }

                          alarmEntries.sort((a, b) =>
                              parseTimestamp(b.value['timestamp']).compareTo(
                                  parseTimestamp(a.value['timestamp'])));

                          // bangun isi list
                          final children = <Widget>[];

                          if (alarmEntries.isEmpty) {
                            children.addAll(const [
                              SizedBox(height: 160),
                              Center(
                                child: Text(
                                  'No alarm history found.',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey),
                                ),
                              ),
                            ]);
                          } else {
                            children.addAll(
                              alarmEntries.map((entry) {
                                final alarm =
                                    Map<String, dynamic>.from(entry.value);
                                final key = entry.key;
                                final ts = parseTimestamp(alarm['timestamp']);
                                final formatted =
                                    DateFormat('MMMM dd, yyyy HH:mm WIB')
                                        .format(ts);
                                final title = _buildAlarmTitle(alarm);

                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  elevation: 3,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    title: Text(
                                      title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    subtitle: Text(
                                      formatted,
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Color(0xFF532F8F)),
                                      onPressed: () async {
                                        await box.delete(key);
                                        _reloadAlarmBox(); // sinkron setelah delete
                                      },
                                    ),
                                  ),
                                );
                              }),
                            );
                          }

                          // TARUH SPASI BAWAH DI DALAM SCROLL (bukan di bawah Expanded)
                          children.add(const SizedBox(height: 24));

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: children,
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // HAPUS SizedBox(height: 24) yang tadinya di bawah Expanded — penyebab overflow
        ],
      ),
    );
  }

//parsing timestamp dari alarm
  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is DateTime) {
      return timestamp;
    } else if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return DateTime.now();
      }
    } else {
      // Fallback jika format tidak valid
      return DateTime.now();
    }
  }

// Fungsi untuk memformat timestamp ke format yang diinginkan
  String _formatTimestamp(dynamic timestamp) {
    DateTime date = _parseTimestamp(timestamp);
    return DateFormat('MMMM dd, yyyy HH:mm WIB').format(date);
  }

  String _buildAlarmTitle(Map<String, dynamic> alarm) {
    final String name = alarm['alarmName']?.toString() ?? 'Unknown Alarm';
    final dynamic value = alarm['sensorValue'];

    // Alarm yang emang nggak butuh nilai tampil
    const noValueNames = {
      'Boiler System Abnormal',
      'Chiller System Abnormal',
      'OFDA System Abnormal',
      'UF System Abnormal',
      'Fault Domestic Pump',
      'Low Domestic Tank',
    };
    if (noValueNames.contains(name) || value == null) return name;

    // Khusus yang value berupa MAP (biar nggak muncul {…})
    if (value is Map) {
      return _formatMapValue(name, Map<String, dynamic>.from(value));
    }

    // Angka tunggal (tk201, tk202, tk103, dll)
    if (value is num) {
      final unit = _unitForSingleValue(name);
      return '$name — ${_fmtNum(value, name)}${unit ?? ''}';
    }

    // fallback ke string biasa
    return '$name — $value';
  }

  String? _unitForSingleValue(String alarmName) {
    // Mapping unit buat angka tunggal
    // TK* kita asumsikan suhu (°C). Kalau beda, tinggal ganti sini.
    const tempAlarms = {'tk201', 'tk202', 'tk103'};
    final key = alarmName.toLowerCase();
    if (tempAlarms.any((t) => key.contains(t))) return '°C';
    return null; // default tanpa unit
  }

  String _fmtNum(num v, String alarmName) {
    // Pilih 1 atau 2 desimal sesuai kebutuhan
    final key = alarmName.toLowerCase();
    if (key.contains('conduct')) return _num2.format(v);
    return _num1.format(v);
  }

  String _formatMapValue(String alarmName, Map<String, dynamic> m) {
    final key = alarmName.toLowerCase();

    // Ahu 04 LB: {'tempAhu': x, 'rhAhu': y}
    if (key.contains('ahu')) {
      final temp = m['tempAhu'];
      final rh = m['rhAhu'];
      final parts = <String>[];
      if (temp is num) parts.add('Temp ${_num1.format(temp)}°C');
      if (rh is num) parts.add('RH ${_num1.format(rh)}%');
      return parts.isEmpty ? alarmName : '$alarmName — ${parts.join(', ')}';
    }

    if (key.contains('m800')) {
      final toc = m['toc'];
      final temp = m['temp'];
      final conduct = m['conduct'];
      final lamp = m['lamp'];

      final parts = <String>[];
      if (toc is num) parts.add('TOC ${_num1.format(toc)}');
      if (temp is num) parts.add('Temp ${_num1.format(temp)}°C');
      if (conduct is num) parts.add('Conduct ${_num2.format(conduct)}');
      if (lamp is num) parts.add('Lamp ${lamp.toInt()} h');

      return parts.isEmpty ? alarmName : '$alarmName — ${parts.join(', ')}';
    }

    final parts = m.entries.map((e) {
      final k = e.key.toString();
      final v = e.value;
      if (v is num) {
        // heuristik kecil: temp/rh/cond → kasih unit
        if (k.toLowerCase().contains('temp')) return '$k ${_num1.format(v)}°C';
        if (k.toLowerCase().contains('rh')) return '$k ${_num1.format(v)}%';
        if (k.toLowerCase().contains('conduct')) return '$k ${_num2.format(v)}';
        if (k.contains('lamp')) return '${e.key} ${v.toInt()} h';
        return '$k ${_num1.format(v)}';
      }
      return '$k $v';
    }).toList();

    return parts.isEmpty ? alarmName : '$alarmName — ${parts.join(', ')}';
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
                      indikatorPage(
                        key: const PageStorageKey('Digital Indikator'),
                        highStream: _highSubject.stream,
                        lowStream: _lowSubject.stream,
                        faultPumpStream: _faultPumpSubject.stream,
                        boilerStream: _boilerSubject.stream,
                        ofdaStream: _ofdaSubject.stream,
                        chillerStream: _chillerSubject.stream,
                        ufStream: _ufSubject.stream,
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 8.0),
                        child: Column(
                          children: const [
                            // SizedBox(height: 12),
                            // ArtesisTimerCard(number: 1, label: 'Artesis 1'),
                            SizedBox(height: 12),
                            ArtesisTimerCard(number: 2, label: 'Artesis 2'),
                            SizedBox(height: 12),
                            // ArtesisTimerCard(number: 3, label: 'Artesis 3'),
                            // SizedBox(height: 12),
                            ArtesisTimerCard(number: 4, label: 'Artesis 4'),
                            SizedBox(height: 12),
                          ],
                        ),
                      ),
                      const M800Page(key: PageStorageKey('M800')),
                      VentFilterPage(
                        key: const PageStorageKey('VentFilter'),
                        tk201: tk201,
                        tk202: tk202,
                        tk103: tk103,
                      ),
                      lbeng04Page(
                        key: const PageStorageKey('LBENG-AHU-004'),
                        tempAhu04lb: temp_ahu04lb,
                        rhAhu04lb: rh_ahu04lb,
                        // chartWidget: _buildChart_ahu04lb(),
                        tf3Service: _tf3Service,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 0, bottom: 8),
                  child: Center(
                    child: SmoothPageIndicator(
                      controller: _pageController,
                      count: 5,
                      effect: WormEffect(
                        dotHeight: 8.0,
                        dotWidth: 8.0,
                        activeDotColor: Color(0xFF532F8F),
                        dotColor: Colors.grey.withOpacity(0.5),
                      ),
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
                        curveSmoothness: 0.3,
                        color: const Color(0xFFed4d9b),
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                      LineChartBarData(
                        spots: _tk202Data,
                        isCurved: false,
                        curveSmoothness: 0.3,
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

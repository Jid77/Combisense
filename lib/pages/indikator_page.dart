import 'package:combisense/widgets/tank_level_widget.dart';
import 'package:flutter/material.dart';

class indikatorPage extends StatelessWidget {
  final Stream<int> highStream;
  final Stream<int> lowStream;
  final Stream<int> faultPumpStream;
  final Stream<int> boilerStream;
  final Stream<int> ofdaStream;
  final Stream<int> chillerStream;
  final Stream<int> ufStream;

  const indikatorPage({
    super.key,
    required this.highStream,
    required this.lowStream,
    required this.faultPumpStream,
    required this.boilerStream,
    required this.ofdaStream,
    required this.chillerStream,
    required this.ufStream,
  });

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController.none(
      child: Padding(
        key: const PageStorageKey('page1'),
        padding: const EdgeInsets.all(8.0),
        child: RawScrollbar(
          thumbVisibility: false,
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
                  // === Card: Domestic Tank & Pump ===
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          StreamBuilder<int>(
                            stream: highStream,
                            builder: (context, highSnapshot) {
                              return StreamBuilder<int>(
                                stream: lowStream,
                                builder: (context, lowSnapshot) {
                                  final high = highSnapshot.data ?? 0;
                                  final low = lowSnapshot.data ?? 0;

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
                          Expanded(
                            flex: 3,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                StreamBuilder<int>(
                                  stream: faultPumpStream,
                                  builder: (context, snapshot) {
                                    final status = snapshot.data ?? 0;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: status == 0
                                            ? const Color(0xFF6FCF97)
                                            : const Color(0xFFFF6B6B),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      child: Text(
                                        status == 0 ? "Normal" : "Abnormal",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
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
                  // const SizedBox(height: 4),

                  // === Grid Status Boiler, OFDA, Chiller, UF ===
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.3,
                    children: [
                      StreamBuilder<int>(
                        stream: boilerStream,
                        builder: (context, snapshot) {
                          final status = snapshot.data ?? 0;
                          return _buildStatusWidget0(
                            'Boiler',
                            status,
                            'assets/images/3dboiler.png',
                            60,
                            78,
                          );
                        },
                      ),
                      StreamBuilder<int>(
                        stream: ofdaStream,
                        builder: (context, snapshot) {
                          final status = snapshot.data ?? 0;
                          return _buildStatusWidget0(
                            'OFDA',
                            status,
                            'assets/images/3dofda.png',
                            60,
                            118,
                          );
                        },
                      ),
                      StreamBuilder<int>(
                        stream: chillerStream,
                        builder: (context, snapshot) {
                          final status = snapshot.data ?? 0;
                          return _buildStatusWidget1(
                            'Chiller',
                            status,
                            'assets/images/3dchiller.png',
                            60,
                            78,
                          );
                        },
                      ),
                      StreamBuilder<int>(
                        stream: ufStream,
                        builder: (context, snapshot) {
                          final status = snapshot.data ?? 0;
                          return _buildStatusWidget0(
                            'UF',
                            status,
                            'assets/images/UF.png',
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
    );
  }

  Widget _buildStatusWidget1(
    String label,
    int status,
    String assetImage,
    double imageWidth,
    double imageHeight,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth, // ikuti lebar parent
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 12),
                      decoration: BoxDecoration(
                        color: status == 1
                            ? const Color(0xFF6FCF97)
                            : const Color(0xFFFF6B6B),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          status == 1 ? "Normal" : "Abnormal",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _buildStatusWidget0(
  String label,
  int status,
  String assetImage,
  double imageWidth,
  double imageHeight,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return Container(
        width: constraints.maxWidth,
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                    decoration: BoxDecoration(
                      color: status == 0
                          ? const Color(0xFF6FCF97)
                          : const Color(0xFFFF6B6B),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        status == 0 ? "Normal" : "Abnormal",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

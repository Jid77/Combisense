import 'package:flutter/material.dart';

class lbeng04Page extends StatelessWidget {
  final double tempAhu04lb;
  final double rhAhu04lb;
  final Widget chartWidget;
  final Widget Function(String, double) buildTempWidget;
  final Widget Function(String, double) buildHumidityWidget;

  const lbeng04Page({
    Key? key,
    required this.tempAhu04lb,
    required this.rhAhu04lb,
    required this.chartWidget,
    required this.buildTempWidget,
    required this.buildHumidityWidget,
  }) : super(key: key);

  @override
  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController.none(
      child: Padding(
        key: const PageStorageKey('page3'),
        padding:
            const EdgeInsets.only(top: 25.0, left: 16, right: 16, bottom: 16),
        child: SingleChildScrollView(
          primary: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Judul
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
                    ),
                    SizedBox(height: 4),
                    Divider(
                      thickness: 2,
                      color: Colors.black,
                      indent: 0,
                      endIndent: 150,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Current Temperature
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
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        buildTempWidget('Temperature', tempAhu04lb),
                        buildHumidityWidget('Humidity', rhAhu04lb),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                "Graphic Temperature & Humidity",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              chartWidget,
            ],
          ),
        ),
      ),
    );
  }
}

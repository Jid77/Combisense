import 'package:flutter/material.dart';

class VentFilterPage extends StatelessWidget {
  final Widget Function(String, double) buildCircularValue;
  final Widget chartWidget;
  final double tk201;
  final double tk202;
  final double tk103;

  const VentFilterPage({
    Key? key,
    required this.tk201,
    required this.tk202,
    required this.tk103,
    required this.buildCircularValue,
    required this.chartWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController.none(
      child: Padding(
        key: const PageStorageKey('page2'),
        padding:
            const EdgeInsets.only(top: 25.0, left: 16, right: 30, bottom: 16),
        child: SingleChildScrollView(
          primary: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        buildCircularValue('Tk201', tk201),
                        buildCircularValue('Tk202', tk202),
                        buildCircularValue('Tk103', tk103),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Graphic Temperature",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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

import 'package:flutter/material.dart';
import 'package:combisense/services/tf3_service.dart';
import 'package:combisense/utils/auth_helper.dart';

class lbeng04Page extends StatefulWidget {
  final double tempAhu04lb;
  final double rhAhu04lb;
  final Widget chartWidget;
  final Tf3Service tf3Service;

  const lbeng04Page({
    Key? key,
    required this.tempAhu04lb,
    required this.rhAhu04lb,
    required this.chartWidget,
    required this.tf3Service,
  }) : super(key: key);

  @override
  State<lbeng04Page> createState() => _lbeng04PageState();
}

class _lbeng04PageState extends State<lbeng04Page> {
  final Tf3Service _tf3Service = Tf3Service(name: 'tf3');

  @override
  void dispose() {
    _tf3Service.dispose();
    super.dispose();
  }

  Widget _buildSP(Stream<double> stream) {
    return StreamBuilder<double>(
      stream: stream,
      builder: (context, snapshot) {
        final sp = snapshot.data?.toStringAsFixed(1) ?? '--';
        return Text(
          "SV: $sp°C",
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        );
      },
    );
  }

  Widget _buildPV(Stream<double> stream, Tf3Service service) {
    return StreamBuilder<double>(
      stream: stream,
      builder: (context, snapshot) {
        final pv = snapshot.data?.toStringAsFixed(1) ?? '--';
        final value = snapshot.data ?? 0.0;
        final color = value < 18 || value > 28
            ? const Color(0xFFFF6B6B)
            : const Color(0xFF8547b0);
        return GestureDetector(
          onTap: () async {
            if (await AuthHelper.verifyPassword(context)) {
              final controller = TextEditingController();
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Set Preset untuk AHU04LB"),
                  content: TextField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: "Contoh: 23.5"),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Batal"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final val = double.tryParse(controller.text);
                        if (val != null && val > 0) {
                          service.setPreset(val);
                          Navigator.pop(context);
                          AuthHelper.showTopNotification(
                              context, "Preset AHU04LB diatur: $val°C");
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8547b0),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Kirim"),
                    ),
                  ],
                ),
              );
            }
          },
          child: _CircularValue(
            label: 'TF3 Sensor',
            valueText: '$pv°C',
            color: color,
          ),
        );
      },
    );
  }

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
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "LBENG-AHU-004",
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
                        Column(
                          children: [
                            _buildPV(_tf3Service.pvStream, _tf3Service),
                            const SizedBox(height: 6),
                            _buildSP(_tf3Service.spStream),
                          ],
                        ),
                        Column(
                          children: [
                            _CircularValue(
                              label: "Temperature",
                              valueText:
                                  '${widget.tempAhu04lb.toStringAsFixed(1)}°C',
                              color: const Color(0xFF00B8D4),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            _CircularValue(
                              label: "Humidity",
                              valueText:
                                  '${widget.rhAhu04lb.toStringAsFixed(1)}%',
                              color: const Color(0xFF00B8D4),
                            ),
                          ],
                        )
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
              widget.chartWidget,
            ],
          ),
        ),
      ),
    );
  }
}

class _CircularValue extends StatelessWidget {
  final String label;
  final String valueText;
  final Color color;

  const _CircularValue({
    required this.label,
    required this.valueText,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: Center(
            child: Text(
              valueText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

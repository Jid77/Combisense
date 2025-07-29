import 'package:flutter/material.dart';
import 'package:combisense/services/vent_filter_service.dart';
import 'package:combisense/utils/auth_helper.dart';

class VentFilterPage extends StatefulWidget {
  final Widget chartWidget;
  final double tk201;
  final double tk202;
  final double tk103;

  const VentFilterPage({
    Key? key,
    required this.tk201,
    required this.tk202,
    required this.tk103,
    required this.chartWidget,
  }) : super(key: key);

  @override
  State<VentFilterPage> createState() => _VentFilterPageState();
}

class _VentFilterPageState extends State<VentFilterPage> {
  final _tk201Service = VentFilterService(name: 'tk201');
  final _tk202Service = VentFilterService(name: 'tk202');
  final _tk103Service = VentFilterService(name: 'tk103');

  @override
  void dispose() {
    _tk201Service.dispose();
    _tk202Service.dispose();
    _tk103Service.dispose();
    super.dispose();
  }

  Widget _buildSP(Stream<double> stream) {
    return StreamBuilder<double>(
      stream: stream,
      builder: (context, snapshot) {
        final sp = snapshot.data?.toStringAsFixed(0) ?? '--';
        return Text(
          "SV: $sp",
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        );
      },
    );
  }

  Widget _buildCircularWithTap(
      String label, double value, VentFilterService service) {
    Color color = value < 65 || value > 80
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF8547b0);

    return GestureDetector(
      onTap: () async {
        if (await AuthHelper.verifyPassword(context)) {
          final controller = TextEditingController();
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text("Set Preset untuk $label"),
              content: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Contoh: 70"),
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
                          context, "Preset $label diatur: $val");
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
        label: label,
        valueText: '${value.toInt()}°C',
        color: color,
      ),
    );
  }

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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            _buildCircularWithTap(
                                'Tk201', widget.tk201, _tk201Service),
                            const SizedBox(height: 6),
                            _buildSP(_tk201Service.spStream),
                          ],
                        ),
                        Column(
                          children: [
                            _buildCircularWithTap(
                                'Tk202', widget.tk202, _tk202Service),
                            const SizedBox(height: 6),
                            _buildSP(_tk202Service.spStream),
                          ],
                        ),
                        Column(
                          children: [
                            _buildCircularWithTap(
                                'Tk103', widget.tk103, _tk103Service),
                            const SizedBox(height: 6),
                            _buildSP(_tk103Service.spStream),
                          ],
                        ),
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
              widget.chartWidget,
            ],
          ),
        ),
      ),
    );
  }
}

// 👇 Circular Widget Custom
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
            color: color, // ✅ FULL fill warna tanpa border
          ),
          child: Center(
            child: Text(
              valueText,
              style: const TextStyle(
                color: Colors.white, // ✅ Tulisan putih
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

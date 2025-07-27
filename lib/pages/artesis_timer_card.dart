import 'package:flutter/material.dart';
import 'package:combisense/services/artesis_timer_service.dart';

class ArtesisTimerCard extends StatefulWidget {
  final int number;
  final String label;

  const ArtesisTimerCard({
    super.key,
    required this.number,
    required this.label,
  });

  @override
  State<ArtesisTimerCard> createState() => _ArtesisTimerCardState();
}

class _ArtesisTimerCardState extends State<ArtesisTimerCard> {
  late final ArtesisTimerService _service;
  double _pv = 0.0;
  double _preset = 0.0;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = ArtesisTimerService(number: widget.number);
    _service.pvStream.listen((val) => setState(() => _pv = val));
    _service.presetStream.listen((val) => setState(() => _preset = val));
  }

  @override
  void dispose() {
    _controller.dispose();
    _service.dispose();
    super.dispose();
  }

  void _setPreset() {
    final val = double.tryParse(_controller.text);
    if (val != null && val > 0) {
      _service.setPreset(val);
      _controller.clear();
      showCustomTopNotification(context, "Preset telah diatur ke $val jam");
    }
  }

  void _resetTimer() {
    _service.triggerReset();
    showCustomTopNotification(context, "Timer telah direset!");
  }

  void showCustomTopNotification(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 80,
        left: 60,
        right: 60,
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(bottom: 500), // sesuai permintaanmu
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    // Auto-dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 1), () {
      entry.remove();
    });
  }

  Future<bool> _verifyPassword(BuildContext context) async {
    final TextEditingController _pwController = TextEditingController();
    bool result = false;
    bool isPasswordVisible = false;

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text("Masukkan Password"),
            content: TextField(
              controller: _pwController,
              obscureText: !isPasswordVisible,
              decoration: InputDecoration(
                labelText: "Password",
                suffixIcon: IconButton(
                  icon: Icon(
                    isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      isPasswordVisible = !isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Batal"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_pwController.text == "combi123") {
                    result = true;
                    Navigator.pop(context);
                  } else {
                    showCustomTopNotification(context, "Password salah!");
                  }
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      },
    );

    return result;
  }

  Widget _buildTimerValue(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "${value.toStringAsFixed(2)} jam",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
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
          // Label dan nilai PV + SP
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildTimerValue("PV", _pv),
                    const SizedBox(width: 20),
                    _buildTimerValue("SP", _preset),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Tombol reset dan setting
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () async {
                  if (await _verifyPassword(context)) {
                    _resetTimer();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                child: const Text("Reset"),
              ),
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: () async {
                  if (await _verifyPassword(context)) {
                    showDialog(
                      context: context,
                      builder: (_) {
                        return AlertDialog(
                          title: const Text("Set Preset (jam)"),
                          content: TextField(
                            controller: _controller,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: "Contoh: 1.5",
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Batal"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _setPreset();
                                Navigator.pop(context);
                              },
                              child: const Text("Kirim"),
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8547b0),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                child: const Text("Setting"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

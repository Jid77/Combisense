import 'dart:async';
import 'package:flutter/material.dart';
import 'package:combisense/services/artesis_timer_service.dart';
import 'package:combisense/utils/auth_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' show FontFeature;

class ArtesisTimerCard extends StatefulWidget {
  final int number; // contoh: 2 (artesis 2), 3 (artesis 3)
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

  bool _manualOn = false;
  bool _busyToggle = false;
  Timer? _countdown;
  DateTime? _target;
  Duration _remaining = Duration.zero;

  static const int _minMinutes = 1;
  static const int _maxMinutes = 120;

  final TextEditingController _controller = TextEditingController();

  String get _prefKey => 'artesis_${widget.number}_manual_until';

  @override
  void initState() {
    super.initState();
    _service = ArtesisTimerService(number: widget.number);

    // Listen PV/SV
    _service.pvStream.listen((val) {
      if (!mounted) return;
      setState(() => _pv = val);
    });
    _service.presetStream.listen((val) {
      if (!mounted) return;
      setState(() => _preset = val);
    });

    // Listen manual toggle dari Firebase
    _service.manualStream.listen((on) async {
      if (!mounted) return;
      setState(() => _manualOn = on);
      if (!on) {
        _stopCountdown();
        await _clearCountdownTarget();
      } else {
        // Kalau manual ON, coba restore countdown dari local pref
        await _restoreCountdownIfAny();
      }
    });

    // Ambil state awal manual
    _service.fetchInitialManual().then((on) async {
      if (!mounted) return;
      setState(() => _manualOn = on);
      if (on) {
        await _restoreCountdownIfAny();
      } else {
        await _clearCountdownTarget();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _stopCountdown();
    _service.dispose();
    super.dispose();
  }

  // ===== Responsive font-size helper =====
  double _fs(BuildContext ctx, double px) {
    final mq = MediaQuery.of(ctx);
    final base = (mq.size.width / 390.0).clamp(0.85, 1.12);
    final user = mq.textScaleFactor.clamp(0.9, 1.25);
    return px * base * user;
  }

  // ===== Pref helpers (persist target end time) =====
  Future<void> _saveCountdownTarget(DateTime end) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_prefKey, end.millisecondsSinceEpoch);
  }

  Future<DateTime?> _loadCountdownTarget() async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt(_prefKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _clearCountdownTarget() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_prefKey);
  }

  Future<void> _restoreCountdownIfAny() async {
    final end = await _loadCountdownTarget();
    if (end == null) return;
    final remain = end.difference(DateTime.now());
    if (remain > Duration.zero && _manualOn) {
      _startCountdown(remain, fromRestore: true);
    } else {
      await _clearCountdownTarget();
    }
  }

  // ===== Actions: set preset & reset =====
  void _setPreset() {
    final val = double.tryParse(_controller.text);
    if (val != null && val > 0) {
      _service.setPreset(val);
      _controller.clear();
      AuthHelper.showTopNotificationSuccess(
        context,
        "Preset diatur ke $val jam",
      );
    }
  }

  void _resetTimer() {
    _service.triggerReset();
    AuthHelper.showTopNotificationSuccess(
      context,
      "Timer akan direset dalam beberapa saat!",
    );
  }

  // ===== PV/SV tile (anti kepotong) =====
  Widget _valueTile({
    required String label,
    required String valueText,
    required TextStyle labelStyle,
    required TextStyle valueStyle,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valueText, style: valueStyle),
          ),
        ],
      ),
    );
  }

  // ===== Manual by timer helpers =====
  Future<int?> _askMinutes() async {
    final textCtrl = TextEditingController(text: '5');
    return showDialog<int?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Durasi ON (menit)"),
        content: TextField(
          controller: textCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          decoration: InputDecoration(
            hintText: 'Misal: 5',
            helperText: 'Batas $_minMinutes–$_maxMinutes menit',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              final m = int.tryParse(textCtrl.text.trim());
              if (m == null || m < _minMinutes || m > _maxMinutes) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Masukkan $_minMinutes–$_maxMinutes menit',
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(context, m);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _startCountdown(Duration d, {bool fromRestore = false}) {
    _countdown?.cancel();
    _target = DateTime.now().add(d);
    _remaining = d;

    _countdown = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (_target == null) {
        _stopCountdown();
        return;
      }
      final remain = _target!.difference(DateTime.now());
      if (!mounted) return;
      setState(() => _remaining = remain.isNegative ? Duration.zero : remain);
      if (remain <= Duration.zero) {
        _stopCountdown();
        try {
          await _service.setManual(false);
          await _clearCountdownTarget();
          if (!mounted) return;
          setState(() => _manualOn = false);
          AuthHelper.showTopNotificationFail(
            context,
            "Artesis OFF (timer selesai)",
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mematikan: $e')),
          );
        }
      }
    });

    // Saat mulai baru (bukan restore), simpan end time ke pref
    if (!fromRestore) {
      _saveCountdownTarget(_target!);
    }
  }

  void _stopCountdown() {
    _countdown?.cancel();
    _countdown = null;
    _target = null;
    if (mounted) setState(() => _remaining = Duration.zero);
  }

  String _fmt(Duration d) {
    final hh = d.inHours;
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hh > 0 ? '$hh:$mm:$ss' : '$mm:$ss';
  }

  Future<void> _handleTurnOn() async {
    if (_busyToggle) return;
    setState(() => _busyToggle = true);
    try {
      final ok = await AuthHelper.verifyPassword(context);
      if (!ok) {
        setState(() => _manualOn = false);
        return;
      }
      final minutes = await _askMinutes();
      if (minutes == null) {
        setState(() => _manualOn = false);
        return;
      }
      await _service.setManualWithDuration(minutes);
      _startCountdown(Duration(minutes: minutes)); // auto _saveCountdownTarget
      AuthHelper.showTopNotificationSuccess(
        context,
        "Artesis ON selama $minutes menit",
      );
    } catch (e) {
      setState(() => _manualOn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghidupkan: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyToggle = false);
    }
  }

  Future<void> _handleTurnOff() async {
    if (_busyToggle) return;
    setState(() => _busyToggle = true);
    try {
      _stopCountdown();
      await _service.setManual(false);
      await _clearCountdownTarget();
      AuthHelper.showTopNotificationFail(context, "Artesis OFF");
    } catch (e) {
      setState(() => _manualOn = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mematikan: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyToggle = false);
    }
  }

  // ====== UI potongan kontrol inline ======
  Widget _manualText(
      BuildContext context, TextStyle miniStyle, double statusW) {
    final miniMono = miniStyle.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()], // digit lebar sama
    );

    return SizedBox(
      width: statusW, // <- kunci lebar area teks “Manual” & status
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Manual',
              style: miniMono, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            _manualOn && _countdown != null
                ? 'ON • ${_fmt(_remaining)}'
                : (_manualOn ? 'ON' : 'OFF'),
            style: miniMono.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.clip, // hindari meluber bikin reflow
            softWrap: false,
          ),
        ],
      ),
    );
  }

  Widget _inlineSwitch(double scale) {
    return Transform.scale(
      scale: scale,
      child: AbsorbPointer(
        absorbing: _busyToggle,
        child: Switch.adaptive(
          value: _manualOn,
          onChanged: (val) async {
            setState(() => _manualOn = val);
            if (val) {
              await _handleTurnOn();
            } else {
              await _handleTurnOff();
            }
          },
        ),
      ),
    );
  }

  Widget _controlsInline(
    BuildContext context,
    TextStyle miniStyle,
    TextStyle btnText,
  ) {
    final fs = (double px) => _fs(context, px);
    final isNarrow = MediaQuery.of(context).size.width < 360;
    final switchScale = isNarrow ? 0.88 : 0.95;

    // Lebar tetap untuk blok teks “Manual + status” (silakan atur)
    final double statusW = fs(60);

    // Lebar/tinggi tombol kecil
    final double btnW = fs(72);
    final double btnH = fs(36);

    final btnStyleRed = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFFF6B6B),
      foregroundColor: Colors.white,
      minimumSize: Size(btnW, btnH),
      padding: EdgeInsets.symmetric(horizontal: fs(8), vertical: fs(6)),
      textStyle: btnText,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
    );

    final btnStylePurple = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF8547b0),
      foregroundColor: Colors.white,
      minimumSize: Size(btnW, btnH),
      padding: EdgeInsets.symmetric(horizontal: fs(8), vertical: fs(6)),
      textStyle: btnText,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
    );

    return LayoutBuilder(
      builder: (ctx, cons) {
        return Wrap(
          spacing: fs(10),
          runSpacing: fs(6),
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.start,
          children: [
            // <- sekarang fixed width, jadi nggak goyang saat countdown berubah
            _manualText(context, miniStyle, statusW),

            _inlineSwitch(switchScale),

            SizedBox(
              width: btnW,
              child: ElevatedButton(
                onPressed: () async {
                  if (await AuthHelper.verifyPassword(context)) {
                    _resetTimer();
                  }
                },
                style: btnStyleRed,
                child: const Text('Reset', overflow: TextOverflow.ellipsis),
              ),
            ),
            SizedBox(
              width: btnW,
              child: ElevatedButton(
                onPressed: () async {
                  if (await AuthHelper.verifyPassword(context)) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Set Preset (jam)"),
                        content: TextField(
                          controller: _controller,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: "Contoh: 1.5"),
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
                      ),
                    );
                  }
                },
                style: btnStylePurple,
                child: const Text('Setting', overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = (double px) => _fs(context, px);

    final titleStyle = TextStyle(
        fontSize: fs(14), fontWeight: FontWeight.w600, color: Colors.black87);
    final labelStyle = TextStyle(
        fontSize: fs(12), fontWeight: FontWeight.w500, color: Colors.grey);
    final valueStyle = TextStyle(
        fontSize: fs(18), fontWeight: FontWeight.bold, color: Colors.black);
    final miniStyle = TextStyle(
        fontSize: fs(11), color: Colors.black54, fontWeight: FontWeight.w600);
    final btnText = TextStyle(fontSize: fs(12), fontWeight: FontWeight.bold);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      padding: EdgeInsets.symmetric(vertical: fs(10), horizontal: fs(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.12),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Judul
          Text(widget.label,
              style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(height: fs(8)),

          // PV & SV
          Row(
            children: [
              Expanded(
                child: _valueTile(
                  label: 'PV',
                  valueText: "${_pv.toStringAsFixed(2)} jam",
                  labelStyle: labelStyle,
                  valueStyle: valueStyle,
                  padding: EdgeInsets.only(right: fs(6)),
                ),
              ),
              Expanded(
                child: _valueTile(
                  label: 'SV',
                  valueText: "${_preset.toStringAsFixed(2)} jam",
                  labelStyle: labelStyle,
                  valueStyle: valueStyle,
                  padding: EdgeInsets.only(left: fs(6)),
                ),
              ),
            ],
          ),

          SizedBox(height: fs(12)),

          // Kontrol inline: Manual + status → Toggle → Reset → Setting
          _controlsInline(context, miniStyle, btnText),
        ],
      ),
    );
  }
}

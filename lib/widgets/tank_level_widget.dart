import 'dart:math';
import 'package:flutter/material.dart';

enum TankLevel { full, medium, low }

TankLevel getTankLevel(int high, int low) {
  if (high == 1 && low == 0) return TankLevel.full;
  if (high == 0 && low == 0) return TankLevel.medium;
  if (high == 0 && low == 1) return TankLevel.low;
  return TankLevel.low;
}

class TankLevelWidget extends StatefulWidget {
  final int high;
  final int low;
  final double width;
  final double height;
  final String label;

  const TankLevelWidget({
    Key? key,
    required this.high,
    required this.low,
    this.width = 100,
    this.height = 160,
    this.label = "Domestic Tank",
  }) : super(key: key);

  @override
  State<TankLevelWidget> createState() => _TankLevelWidgetState();
}

class _TankLevelWidgetState extends State<TankLevelWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_BubbleSeed> _seeds;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(); // phase 0..1

    // Seed gelembung acak tapi stabil per instance
    final rnd = Random();
    const count = 20; // jumlah gelembung
    _seeds = List.generate(count, (i) {
      return _BubbleSeed(
        sx: rnd.nextDouble(), // posisi X awal (0..1)
        radius: 1.2 + rnd.nextDouble() * 2.8, // 1.2..4.0
        opacity: 0.28 + rnd.nextDouble() * 0.4, // 0.28..0.68
        drift: (rnd.nextDouble() - 0.5) * 9.0, // -4.5..4.5
        jitterFreq: 1.0 + rnd.nextDouble() * 2.0, // 1..3
        jitterPhase: rnd.nextDouble() * 2 * pi, // 0..2π
        phaseOffset: rnd.nextDouble(), // 0..1
        gamma: 0.8 + rnd.nextDouble() * 0.8, // 0.8..1.6 (easing vertikal)
        warpAmp: rnd.nextDouble() * 0.07, // 0..0.15 (skew kecepatan periodik)
        warpPhase: rnd.nextDouble() * 2 * pi, // 0..2π
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _targetFill(TankLevel level) {
    switch (level) {
      case TankLevel.full:
        return 1.0;
      case TankLevel.medium:
        return 0.50;
      case TankLevel.low:
      default:
        return 0.20;
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = getTankLevel(widget.high, widget.low);
    final targetFill = _targetFill(level);

    final baseColor = switch (level) {
      TankLevel.full => const Color(0xFF42A5F5),
      TankLevel.medium => const Color(0xFF64B5F6),
      TankLevel.low => const Color(0xFF90CAF9),
    };
    final levelLabel = switch (level) {
      TankLevel.full => "Full",
      TankLevel.medium => "Medium",
      TankLevel.low => "Low",
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          child: TweenAnimationBuilder<double>(
            // ketinggian air halus saat status berubah
            tween: Tween<double>(begin: 0, end: targetFill),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
            builder: (context, animatedFill, _) {
              return AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(widget.width, widget.height),
                    painter: _WaveTankPainter(
                      fill: animatedFill.clamp(0.0, 1.0),
                      phase: _ctrl.value, // 0..1
                      color: baseColor,
                      borderRadius: 16,
                      waveHeight: 3.5, // bentuk gelombang seperti kode lama
                      seeds: _seeds,
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          levelLabel,
          style: TextStyle(
            color: baseColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _BubbleSeed {
  final double sx;
  final double radius;
  final double opacity;
  final double drift;
  final double jitterFreq;
  final double jitterPhase;
  final double phaseOffset;
  final double gamma; // easing vertikal (0.8..1.6)
  final double warpAmp; // 0..0.15
  final double warpPhase;

  const _BubbleSeed({
    required this.sx,
    required this.radius,
    required this.opacity,
    required this.drift,
    required this.jitterFreq,
    required this.jitterPhase,
    required this.phaseOffset,
    required this.gamma,
    required this.warpAmp,
    required this.warpPhase,
  });
}

class _WaveTankPainter extends CustomPainter {
  final double fill; // 0..1
  final double phase; // 0..1
  final Color color;
  final double borderRadius;
  final double waveHeight; // H dari rumus lama
  final List<_BubbleSeed> seeds;

  _WaveTankPainter({
    required this.fill,
    required this.phase,
    required this.color,
    required this.borderRadius,
    required this.waveHeight,
    required this.seeds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );

    // Clip ke bentuk tank
    canvas.save();
    canvas.clipRRect(rrect.deflate(1.2));

    final w = size.width;
    final h = size.height;
    final waterTop = h * (1 - fill);

    // Gradien air
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withOpacity(0.85), color.withOpacity(0.96)],
    ).createShader(Rect.fromLTWH(0, waterTop, w, h - waterTop));

    // ===== Gelombang: bentuk sama seperti kode lama =====
    // y_local = H*sin(2π*base*1.2 + t)
    //         + 0.5H*sin(2π*base*3 + 2t)
    //         + H + 2
    // Looping mulus: waktu kelipatan integer (t & 2t)
    final t = phase * 2 * pi; // 0..2π
    final t2 = 2 * t;

    double yLocalAt(double base, {double time = 0, double time2 = 0}) {
      return waveHeight * sin(2 * pi * base * 1.2 + time) +
          waveHeight * 0.5 * sin(2 * pi * base * 3 + time2) +
          waveHeight +
          2;
    }

    // Back wave (solid)
    final back = Path()
      ..moveTo(0, (waterTop + yLocalAt(0, time: t, time2: t2)).clamp(0.0, h));
    final step = max(0.8, w / 160);
    for (double x = 0; x <= w; x += step) {
      final base = x / w;
      final y = (waterTop + yLocalAt(base, time: t, time2: t2)).clamp(0.0, h);
      back.lineTo(x, y);
    }
    back.lineTo(w, h);
    back.lineTo(0, h);
    back.close();

    // Front wave (parallax) — fase geser konstan, tetap integer multiple waktunya
    const phi = pi / 3;
    final front = Path()
      ..moveTo(
          0,
          (waterTop +
                  1.2 +
                  yLocalAt(0, time: -2 * t + phi, time2: -4 * t + 2 * phi))
              .clamp(0.0, h));
    for (double x = 0; x <= w; x += step) {
      final base = x / w;
      final y = (waterTop +
              1.2 +
              yLocalAt(base, time: -2 * t + phi, time2: -4 * t + 2 * phi))
          .clamp(0.0, h);
      front.lineTo(x, y);
    }
    front.lineTo(w, h);
    front.lineTo(0, h);
    front.close();

    // Draw water
    final paintWater = Paint()..shader = shader;
    canvas.drawPath(back, paintWater);

    // Front wave overlay: tint lembut (hindari garis putih tajam)
    final frontPaint = Paint()
      ..color = color.withOpacity(0.10) // pakai warna air, bukan putih murni
      ..blendMode = BlendMode.srcOver
      ..isAntiAlias = true;
    canvas.drawPath(front, frontPaint);

    // Gelembung (random tapi loop mulus)
    _drawBubbles(canvas, size, waterTop, t);

    // (Hapus surface highlight line untuk hilangkan “garis putih”)
    // Sisi kiri highlight halus
    final sideHighlight = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white.withOpacity(0.14), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, w * 0.22, h));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w * 0.20, h),
        Radius.circular(borderRadius),
      ),
      sideHighlight,
    );

    canvas.restore();

    // Border tangki
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF263238);
    canvas.drawRRect(rrect, borderPaint);
  }

  void _drawBubbles(Canvas canvas, Size size, double waterTop, double t) {
    final w = size.width;
    final h = size.height;

    for (final s in seeds) {
      // phase dasar 0..1
      final baseTau = (t / (2 * pi) + s.phaseOffset) % 1.0;

      // warp kecepatan periodik (tetap 1-periodic → seamless)
      final tau =
          (baseTau + s.warpAmp * sin(2 * pi * baseTau + s.warpPhase)) % 1.0;

      // easing vertikal (random gamma, tetap 0..1)
      final prog = pow(tau, s.gamma).toDouble();

      // posisi
      final y = h - prog * (h - waterTop - 6);
      if (y < waterTop || y > h) continue;

      final jitter = sin(2 * pi * tau * s.jitterFreq + s.jitterPhase) * s.drift;
      final x = (s.sx * w + jitter).clamp(2.0, w - 2.0);

      // variasi ukuran ringan (denyut) tapi periodik
      final r =
          s.radius * (0.92 + 0.08 * sin(2 * pi * tau * 2 + s.phaseOffset));

      final stroke = Paint()
        ..color = Colors.white.withOpacity(s.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..isAntiAlias = true;
      final fill = Paint()
        ..color = Colors.white.withOpacity(s.opacity * 0.55)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      canvas.drawCircle(Offset(x, y), r, stroke);
      // highlight kecil di kiri-atas gelembung
      canvas.drawCircle(Offset(x - r * 0.35, y - r * 0.35), r * 0.18, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveTankPainter old) {
    return old.fill != fill ||
        old.phase != phase ||
        old.color != color ||
        old.borderRadius != borderRadius ||
        old.waveHeight != waveHeight;
  }
}

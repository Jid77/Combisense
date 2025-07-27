import 'dart:math';
import 'package:flutter/material.dart';

enum TankLevel { full, medium, low }

TankLevel getTankLevel(int high, int low) {
  if (high == 1 && low == 0) {
    return TankLevel.full;
  } else if (high == 0 && low == 0) {
    return TankLevel.medium;
  } else if (high == 0 && low == 1) {
    return TankLevel.low;
  } else {
    return TankLevel.low; // fallback jika data tidak valid
  }
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
    this.width = 80,
    this.height = 100,
    this.label = "Domestic Tank",
  }) : super(key: key);

  @override
  State<TankLevelWidget> createState() => _TankLevelWidgetState();
}

class _TankLevelWidgetState extends State<TankLevelWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = getTankLevel(widget.high, widget.low);

    double fillPercent;
    Color fillColor;
    String levelLabel;

    switch (level) {
      case TankLevel.full:
        fillPercent = 1.0;
        fillColor = Colors.blue[400]!;
        levelLabel = "Full";
        break;
      case TankLevel.medium:
        fillPercent = 0.5;
        fillColor = Colors.blue[300]!;
        levelLabel = "Medium";
        break;
      case TankLevel.low:
      default:
        fillPercent = 0.2;
        fillColor = Colors.blue[200]!;
        levelLabel = "Low";
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Air (wave) di bawah
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16), // Lebih bulat
                  child: CustomPaint(
                    size: Size(widget.width, widget.height * fillPercent),
                    painter: WavePainter(
                      color: fillColor,
                      waveHeight: 3.5,
                      waveSpeed: _controller.value,
                    ),
                  ),
                );
              },
            ),
            // Border tanki di atas
            Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.blueGrey[900]!, // Lebih gelap
                  width: 2, // Lebih tebal
                ),
                borderRadius: BorderRadius.circular(16),
                color: Colors.transparent,
              ),
            ),
          ],
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
            color: fillColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class WavePainter extends CustomPainter {
  final Color color;
  final double waveHeight;
  final double waveSpeed;

  WavePainter({
    required this.color,
    required this.waveHeight,
    required this.waveSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();

    path.moveTo(0, 0);

    // Gunakan phase agar looping seamless
    double phase = waveSpeed * 2 * pi;

    for (double x = 0; x <= size.width; x += 0.5) {
      double base = x / size.width;
      double y = waveHeight * sin(2 * pi * base * 1.2 + phase) +
          waveHeight * 0.5 * sin(2 * pi * base * 3 + phase * 2) +
          waveHeight +
          2;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.waveSpeed != waveSpeed || oldDelegate.color != color;
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'weather_data.dart';

class WeatherPalette {
  const WeatherPalette(this.top, this.bottom, this.panel);

  factory WeatherPalette.forConditions(WeatherScene scene, bool night) {
    if (night) {
      return scene == WeatherScene.clear || scene == WeatherScene.cloudy
          ? const WeatherPalette(
              Color(0xFF081329),
              Color(0xFF34456C),
              Color(0xFF172746),
            )
          : const WeatherPalette(
              Color(0xFF111C2A),
              Color(0xFF3D5466),
              Color(0xFF172D40),
            );
    }
    return switch (scene) {
      WeatherScene.clear => const WeatherPalette(
        Color(0xFF237FC0),
        Color(0xFF88BDD2),
        Color(0xFF225D83),
      ),
      WeatherScene.cloudy => const WeatherPalette(
        Color(0xFF4B738E),
        Color(0xFFAABDC8),
        Color(0xFF344E68),
      ),
      WeatherScene.rain => const WeatherPalette(
        Color(0xFF344A5D),
        Color(0xFF7A909C),
        Color(0xFF283F53),
      ),
      WeatherScene.storm => const WeatherPalette(
        Color(0xFF202F41),
        Color(0xFF576B7D),
        Color(0xFF203448),
      ),
      WeatherScene.snow => const WeatherPalette(
        Color(0xFF657D95),
        Color(0xFFBDCFD9),
        Color(0xFF3A526D),
      ),
      WeatherScene.mist => const WeatherPalette(
        Color(0xFF738793),
        Color(0xFFB7C6CA),
        Color(0xFF3D5668),
      ),
    };
  }

  final Color top, bottom, panel;
}

// Draw the sky locally so the scene works without downloaded artwork.
class WeatherBackdrop extends StatefulWidget {
  const WeatherBackdrop({
    super.key,
    required this.scene,
    required this.night,
    this.cloudCover = 50,
  });

  final WeatherScene scene;
  final bool night;
  final double cloudCover;

  @override
  State<WeatherBackdrop> createState() => _WeatherBackdropState();
}

class _WeatherBackdropState extends State<WeatherBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _motion.stop();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _SkyPainter(
          widget.scene,
          widget.night,
          widget.cloudCover,
          _motion,
        ),
        size: Size.infinite,
      ),
    ),
  );
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.scene, this.night, this.cloudCover, this.motion)
    : super(repaint: motion);

  final WeatherScene scene;
  final bool night;
  final double cloudCover;
  final Animation<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = WeatherPalette.forConditions(scene, night);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.top, palette.bottom],
        ).createShader(rect),
    );
    final t = motion.value;
    final wet = scene == WeatherScene.rain || scene == WeatherScene.storm;
    if (night && !wet && scene != WeatherScene.mist) {
      for (var i = 0; i < 65; i++) {
        final x = ((i * 73 + 19) % 101) / 101 * size.width;
        final y = ((i * 43 + 7) % 97) / 97 * size.height * 0.58;
        final brightness = 0.22 + (math.sin(t * math.pi * 2 + i) + 1) * 0.22;
        canvas.drawCircle(
          Offset(x, y),
          i % 6 == 0 ? 1.4 : 0.8,
          Paint()..color = Colors.white.withValues(alpha: brightness),
        );
      }
    }
    if (!wet && scene != WeatherScene.mist && scene != WeatherScene.snow) {
      final center = Offset(
        size.width * 0.80,
        math.min(size.height * 0.20, 170),
      );
      final radius = math.min(size.width * 0.065, 48.0);
      canvas.drawCircle(
        center,
        radius * 4.8,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFF2C7).withValues(alpha: night ? 0.09 : 0.30),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 4.8)),
      );
      if (night) {
        final moon = Path()
          ..addOval(Rect.fromCircle(center: center, radius: radius));
        final cutout = Path()
          ..addOval(
            Rect.fromCircle(
              center: center + Offset(radius * 0.52, -radius * 0.30),
              radius: radius * 0.92,
            ),
          );
        canvas.drawPath(
          Path.combine(PathOperation.difference, moon, cutout),
          Paint()..color = const Color(0xFFE5EDFF),
        );
      } else {
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..shader = const RadialGradient(
              colors: [Color(0xFFFFFDE2), Color(0xFFFFDD88)],
            ).createShader(Rect.fromCircle(center: center, radius: radius)),
        );
      }
    }
    final cloudCount = scene == WeatherScene.clear
        ? 1
        : scene == WeatherScene.cloudy
        ? (cloudCover <= 25
              ? 3
              : cloudCover < 65
              ? 5
              : 7)
        : 7;
    if (scene != WeatherScene.mist) {
      for (var i = 0; i < cloudCount; i++) {
        final drift = math.sin(t * math.pi * 2 + i) * 30;
        final x = size.width * (((i * 29 + 11) % 100) / 100) + drift;
        final y = size.height * (0.055 + ((i * 17) % 23) / 100);
        final width = size.width * (0.24 + (i % 3) * 0.08);
        final opacity = scene == WeatherScene.clear
            ? 0.12
            : night
            ? 0.09
            : 0.16;
        _cloud(
          canvas,
          Offset(x, y),
          width,
          Colors.white.withValues(alpha: opacity),
        );
      }
    }
    // Distant ridges ground the scene without competing with the readings.
    for (var layer = 0; layer < 3; layer++) {
      final y = size.height * (0.80 + layer * 0.065);
      final ridge = Path()..moveTo(0, y + 28);
      ridge.cubicTo(
        size.width * 0.18,
        y - 60,
        size.width * 0.32,
        y + 44,
        size.width * 0.55,
        y,
      );
      ridge.cubicTo(
        size.width * 0.72,
        y - 55,
        size.width * 0.86,
        y - 65,
        size.width,
        y + 18,
      );
      ridge.lineTo(size.width, size.height);
      ridge.lineTo(0, size.height);
      ridge.close();
      canvas.drawPath(
        ridge,
        Paint()..color = palette.top.withValues(alpha: 0.13 + layer * 0.12),
      );
    }
    if (wet) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.24)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 95; i++) {
        final x = ((i * 67 + 13) % 103) / 103 * (size.width + 80) - 40;
        final y = (((i * 47) / 97 + t * 18) % 1) * (size.height + 100) - 50;
        canvas.drawLine(Offset(x, y), Offset(x - 7, y + 19 + i % 13), paint);
      }
    } else if (scene == WeatherScene.snow) {
      for (var i = 0; i < 55; i++) {
        final x =
            ((i * 73) % 101) / 101 * size.width +
            math.sin(t * math.pi * 2 + i) * 18;
        final y = (((i * 31) / 97 + t * 2) % 1) * size.height;
        canvas.drawCircle(
          Offset(x, y),
          1.5 + i % 3,
          Paint()..color = Colors.white.withValues(alpha: 0.40 + i % 3 * 0.1),
        );
      }
    } else if (scene == WeatherScene.mist) {
      for (var i = 0; i < 5; i++) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(
              size.width * 0.5 + math.sin(t * math.pi * 2 + i) * 28,
              size.height * (0.18 + i * 0.14),
            ),
            width: size.width * 1.5,
            height: 65,
          ),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
        );
      }
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: night
              ? const [Color(0x08000000), Color(0x2806101F)]
              : const [Color(0x55000000), Color(0x6606101F)],
        ).createShader(rect),
    );
  }

  void _cloud(Canvas canvas, Offset origin, double width, Color color) {
    final path = Path()..moveTo(-0.5, 0.1);
    path.cubicTo(-0.58, -0.10, -0.29, -0.22, -0.20, -0.14);
    path.cubicTo(-0.18, -0.39, 0.19, -0.38, 0.25, -0.15);
    path.cubicTo(0.52, -0.20, 0.65, 0.08, 0.45, 0.14);
    path.cubicTo(0.20, 0.19, -0.25, 0.19, -0.5, 0.1);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(width);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: color.a * 0.35),
            color,
            color.withValues(alpha: color.a * 0.12),
          ],
        ).createShader(const Rect.fromLTWH(-0.6, -0.4, 1.25, 0.65))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.016),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) =>
      oldDelegate.scene != scene ||
      oldDelegate.night != night ||
      oldDelegate.cloudCover != cloudCover;
}

class WeatherSymbol extends StatelessWidget {
  const WeatherSymbol({
    super.key,
    required this.code,
    this.night = false,
    this.size = 34,
  });

  final int code;
  final bool night;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scene = weatherScene(code);
    if (scene == WeatherScene.clear) {
      return Icon(
        night ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
        color: night ? const Color(0xFFDAE5FF) : const Color(0xFFFFD77D),
        size: size,
      );
    }
    return SizedBox(
      width: size * 1.22,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (scene == WeatherScene.cloudy && code < 803)
            Positioned(
              top: 0,
              right: 0,
              child: Icon(
                night ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                color: night
                    ? const Color(0xFFDAE5FF)
                    : const Color(0xFFFFD77D),
                size: size * 0.67,
              ),
            ),
          Icon(
            switch (scene) {
              WeatherScene.storm => Icons.thunderstorm_rounded,
              WeatherScene.snow => Icons.ac_unit_rounded,
              WeatherScene.mist => Icons.blur_on_rounded,
              _ => Icons.cloud_rounded,
            },
            color: const Color(0xFFE6EDF4),
            size: size * 0.92,
          ),
          if (scene == WeatherScene.rain)
            Positioned(
              bottom: 0,
              child: Row(
                children: List.generate(
                  3,
                  (_) => Icon(
                    Icons.water_drop_rounded,
                    size: size * 0.24,
                    color: const Color(0xFF90D5FF),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

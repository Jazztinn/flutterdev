import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

TextStyle xmbTextStyle(double size) => TextStyle(
  fontFamily: 'NewRodin',
  fontWeight: FontWeight.w800,
  fontSize: size,
  color: const Color(0xFFF6F8FF),
  height: 1.25,
  letterSpacing: -0.4,
  shadows: const [
    Shadow(color: Color(0x88031431), offset: Offset(1, 2), blurRadius: 3),
    Shadow(color: Color(0x33FFFFFF), blurRadius: 2),
  ],
);

class XmbBackground extends StatelessWidget {
  const XmbBackground({super.key, required this.time});

  final ValueListenable<double> time;

  @override
  // draw the wallpaper and moving waves.
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF091637)),
        // keep wallpaper intact and leave out its taskbar.
        FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: 1920,
            height: 1032,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: 1080,
                child: Image.asset(
                  'assets/images/psp-wallpaper.png',
                  width: 1920,
                  height: 1080,
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
        ),
        RepaintBoundary(child: CustomPaint(painter: _WavePainter(time))),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.time) : super(repaint: time);
  final ValueListenable<double> time;

  @override
  // paint the moving wave layers.
  void paint(Canvas canvas, Size size) {
    for (var layer = 0; layer < 3; layer++) {
      final phase = time.value * 0.13 + layer * 1.9;
      final baseline = size.height * (0.28 + layer * 0.19);
      final amplitude = size.height * (0.055 + layer * 0.016);
      final edge = Path();
      for (var step = 0; step <= 80; step++) {
        final x = size.width * step / 80;
        final y =
            baseline + math.sin(step / 80 * math.pi * 1.55 + phase) * amplitude;
        if (step == 0) {
          edge.moveTo(x, y);
        } else {
          edge.lineTo(x, y);
        }
      }
      final fill = Path.from(edge)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader =
              LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: layer == 0 ? 0.16 : 0.09),
                  const Color(0x002FAFE4),
                ],
              ).createShader(
                Rect.fromLTWH(
                  0,
                  baseline - amplitude,
                  size.width,
                  size.height * 0.25,
                ),
              ),
      );
      canvas.drawPath(
        edge,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => oldDelegate.time != time;
}

enum XmbIconKind { info, camera, game, settings, battery, music, weather }

// draw one menu icon.
class XmbIcon extends StatelessWidget {
  const XmbIcon({
    super.key,
    required this.kind,
    required this.size,
    this.selected = false,
  });

  final XmbIconKind kind;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _IconPainter(kind, selected)),
  );
}

class _IconPainter extends CustomPainter {
  const _IconPainter(this.kind, this.selected);
  final XmbIconKind kind;
  final bool selected;

  Path _shape() {
    // build the shape for the selected icon.
    final path = Path()..fillType = PathFillType.evenOdd;
    switch (kind) {
      case XmbIconKind.game:
        path.moveTo(24, 24);
        path.cubicTo(13, 24, 10, 34, 8, 46);
        path.lineTo(3, 70);
        path.cubicTo(0, 85, 12, 91, 21, 80);
        path.lineTo(34, 64);
        path.lineTo(66, 64);
        path.lineTo(79, 80);
        path.cubicTo(88, 91, 100, 85, 97, 70);
        path.lineTo(92, 46);
        path.cubicTo(90, 34, 87, 24, 76, 24);
        path.cubicTo(66, 23, 65, 32, 56, 32);
        path.lineTo(44, 32);
        path.cubicTo(35, 32, 34, 23, 24, 24);
        path.close();
      case XmbIconKind.camera:
        path.moveTo(11, 28);
        path.lineTo(33, 28);
        path.lineTo(35, 16);
        path.quadraticBezierTo(36, 11, 42, 11);
        path.lineTo(59, 11);
        path.quadraticBezierTo(65, 11, 66, 16);
        path.lineTo(68, 28);
        path.lineTo(89, 28);
        path.quadraticBezierTo(96, 28, 96, 35);
        path.lineTo(96, 83);
        path.quadraticBezierTo(96, 90, 89, 90);
        path.lineTo(11, 90);
        path.quadraticBezierTo(4, 90, 4, 83);
        path.lineTo(4, 35);
        path.quadraticBezierTo(4, 28, 11, 28);
        path.close();
        path.addOval(const Rect.fromLTWH(29, 37, 42, 42));
        path.addOval(const Rect.fromLTWH(39, 47, 22, 22));
      case XmbIconKind.settings:
        path.addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 35, 90, 50),
            const Radius.circular(8),
          ),
        );
        path.addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(31, 17, 38, 24),
            const Radius.circular(10),
          ),
        );
        path.addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(38, 24, 24, 12),
            const Radius.circular(4),
          ),
        );
        path.addRect(const Rect.fromLTWH(5, 52, 90, 6));
        path.addRect(const Rect.fromLTWH(22, 46, 11, 18));
        path.addRect(const Rect.fromLTWH(67, 46, 11, 18));
      case XmbIconKind.info:
        path.addOval(const Rect.fromLTWH(12, 12, 76, 76));
        path.addOval(const Rect.fromLTWH(19, 19, 62, 62));
        path.addOval(const Rect.fromLTWH(45, 29, 10, 10));
        path.addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(45, 46, 10, 27),
            const Radius.circular(2),
          ),
        );
      case XmbIconKind.battery:
        path.addRect(const Rect.fromLTWH(12, 22, 85, 54));
        path.addRect(const Rect.fromLTWH(19, 29, 71, 40));
        path.addRect(const Rect.fromLTWH(3, 38, 9, 23));
        for (var i = 0; i < 3; i++) {
          path.addRect(Rect.fromLTWH(27 + i * 20, 36, 11, 26));
        }
      case XmbIconKind.music:
        final notes = Path()
          ..addOval(const Rect.fromLTWH(16, 62, 25, 18))
          ..addOval(const Rect.fromLTWH(57, 53, 25, 18));
        final stems = Path()
          ..addRect(const Rect.fromLTWH(34, 25, 7, 46))
          ..addRect(const Rect.fromLTWH(75, 15, 7, 47))
          ..moveTo(34, 24)
          ..lineTo(82, 12)
          ..lineTo(82, 24)
          ..lineTo(34, 36)
          ..close();
        return Path.combine(PathOperation.union, notes, stems);
      case XmbIconKind.weather:
        path.fillType = PathFillType.nonZero;
        path.moveTo(22, 84);
        path.cubicTo(7, 84, 4, 65, 18, 59);
        path.cubicTo(14, 43, 32, 32, 45, 42);
        path.cubicTo(57, 31, 77, 41, 77, 57);
        path.cubicTo(96, 54, 101, 79, 84, 84);
        path.close();
        const center = Offset(69, 27);
        final sun = Path()
          ..addOval(Rect.fromCircle(center: center, radius: 13));
        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          final direction = Offset(math.cos(angle), math.sin(angle));
          final normal = Offset(-direction.dy, direction.dx) * 1.7;
          final start = center + direction * 18;
          final end = center + direction * 25;
          sun.moveTo((start - normal).dx, (start - normal).dy);
          sun.lineTo((end - normal).dx, (end - normal).dy);
          sun.lineTo((end + normal).dx, (end + normal).dy);
          sun.lineTo((start + normal).dx, (start + normal).dy);
          sun.close();
        }
        return Path.combine(PathOperation.union, sun, path);
    }
    return path;
  }

  @override
  // draw the icon face and shadow.
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    final path = _shape();
    canvas.save();
    canvas.translate(1.5, 3);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x88010D26)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: selected ? 0.55 : 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, selected ? 4 : 2),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: selected
              ? const [Color(0xFFFFFFFF), Color(0xFFE8F1F8)]
              : const [Color(0xFFDCE9F4), Color(0xFFB2CCDE)],
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xBFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.selected != selected;
}

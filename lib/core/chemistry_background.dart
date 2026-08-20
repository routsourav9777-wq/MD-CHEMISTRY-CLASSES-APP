import 'dart:math';
import 'package:flutter/material.dart';
import 'theme.dart';

class ChemistryBackground extends StatefulWidget {
  final Widget child;
  const ChemistryBackground({super.key, required this.child});

  @override
  State<ChemistryBackground> createState() => _ChemistryBackgroundState();
}

class _ChemistryBackgroundState extends State<ChemistryBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  final random = Random(7);
  late final List<Offset> points;
  late final List<String> symbols;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    points = List.generate(
      35,
      (_) => Offset(random.nextDouble(), random.nextDouble()),
    );
    symbols = ['H', 'C', 'O', 'N', 'Na', 'Cl', 'Fe', 'S'];
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
        painter: _ChemistryPainter(points, symbols, controller.value),
        child: widget.child,
      ),
    );
  }
}

class _ChemistryPainter extends CustomPainter {
  final List<Offset> points;
  final List<String> symbols;
  final double t;
  _ChemistryPainter(this.points, this.symbols, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < points.length; i++) {
      final x = points[i].dx * size.width;
      final y = ((points[i].dy + t * (.015 + (i % 4) * .006)) % 1) * size.height;
      p.color = AppTheme.cyan.withOpacity(.08 + (i % 3) * .03);
      canvas.drawCircle(Offset(x, y), 1.5 + (i % 3), p);
    }

    final orbit = Offset(size.width * .78, size.height * .18);
    final r = min(size.width, size.height) * .12;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppTheme.cyan.withOpacity(.12);
    canvas.drawOval(
      Rect.fromCenter(center: orbit, width: r * 2.0, height: r * .8),
      stroke,
    );
    canvas.save();
    canvas.translate(orbit.dx, orbit.dy);
    canvas.rotate(t * 2 * pi);
    canvas.drawCircle(Offset(r, 0), 3.2, Paint()..color = AppTheme.cyan.withOpacity(.6));
    canvas.restore();

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < 12; i++) {
      final pos = Offset(
        ((i * 83.0 + t * 22) % (size.width + 80)) - 40,
        70 + ((i * 137.0) % max(size.height - 100, 1)),
      );
      textPainter.text = TextSpan(
        text: symbols[i % symbols.length],
        style: TextStyle(
          color: Colors.white.withOpacity(.045),
          fontSize: 12 + (i % 3) * 4,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, pos);
    }
  }

  @override
  bool shouldRepaint(covariant _ChemistryPainter oldDelegate) => true;
}

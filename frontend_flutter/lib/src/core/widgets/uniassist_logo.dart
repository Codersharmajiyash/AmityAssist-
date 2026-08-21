import 'package:flutter/material.dart';

import '../theme/kiosk_theme.dart';

class UniAssistLogo extends StatelessWidget {
  const UniAssistLogo({
    super.key,
    this.size = 72,
    this.showWordmark = false,
    this.wordmarkColor = AppColors.ink,
  });

  final double size;
  final bool showWordmark;
  final Color wordmarkColor;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _UniAssistMarkPainter(),
        child: Center(
          child: Text(
            'U',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.18),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UNIASSIST',
              style: TextStyle(
                color: wordmarkColor,
                fontSize: size * 0.28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            Text(
              'Student service kiosk',
              style: TextStyle(
                color: wordmarkColor.withValues(alpha: 0.72),
                fontSize: size * 0.13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UniAssistMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shield = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.24));
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.teal],
      ).createShader(rect);
    canvas.drawRRect(shield, paint);

    final accent = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.25, size.height * 0.70)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.86,
        size.width * 0.75,
        size.height * 0.70,
      );
    canvas.drawPath(path, accent);

    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.76, size.height * 0.24), size.width * 0.12, highlight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

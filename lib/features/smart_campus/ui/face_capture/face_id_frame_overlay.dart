import 'package:flutter/material.dart';

/// 证件照取景框：框外半透明遮罩 + 白色描边与四角标记。
class FaceIdFramePainter extends CustomPainter {
  FaceIdFramePainter({required this.frameRect, required this.previewSize});

  final Rect frameRect;
  final Size previewSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (frameRect == Rect.zero) return;

    final dimPath = Path()
      ..addRect(Offset.zero & previewSize)
      ..addRect(frameRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      dimPath,
      Paint()..color = const Color(0x99000000),
    );

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(frameRect, border);

    final corner = Paint()
      ..color = const Color(0xFFB68EFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const len = 18.0;
    final r = frameRect;

    canvas.drawLine(r.topLeft, r.topLeft + const Offset(len, 0), corner);
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(0, len), corner);
    canvas.drawLine(r.topRight, r.topRight + const Offset(-len, 0), corner);
    canvas.drawLine(r.topRight, r.topRight + const Offset(0, len), corner);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(len, 0), corner);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(0, -len), corner);
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(-len, 0), corner);
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(0, -len), corner);
  }

  @override
  bool shouldRepaint(covariant FaceIdFramePainter oldDelegate) {
    return oldDelegate.frameRect != frameRect ||
        oldDelegate.previewSize != previewSize;
  }
}

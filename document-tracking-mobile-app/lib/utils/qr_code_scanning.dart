import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  bool isScanCompleted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Document QR", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D0D0D),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (!isScanCompleted) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final String? code = barcode.rawValue;
                  if (code != null) {
                    setState(() => isScanCompleted = true);
                    Navigator.pop(context, code);
                  }
                }
              }
            },
          ),
          
          Center(
            child: CustomPaint(
              painter: GradientBorderPainter(),
              child: const SizedBox(
                width: 250,
                height: 250,
              ),
            ),
          ),
          
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                "Align QR code within the frame",
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// CUSTOM PAINTER
class GradientBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 4.0;
    const double radius = 15.0;
    final Rect rect = Offset.zero & size;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color.fromARGB(255, 4, 76, 69),
          Color.fromARGB(255, 119, 150, 52),
          Color.fromARGB(255, 10, 99, 56),
        ],
      ).createShader(rect);

    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(radius));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class LiveBarcodeScannerPage extends StatefulWidget {
  const LiveBarcodeScannerPage({super.key});

  @override
  State<LiveBarcodeScannerPage> createState() => _LiveBarcodeScannerPageState();
}

class _LiveBarcodeScannerPageState extends State<LiveBarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MediaQuery.of(context).orientation == Orientation.landscape
          ? null
          : AppBar(title: const Text('Scan Barcode')),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (_hasScanned) return;
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? rawValue = barcodes.first.rawValue;
            if (rawValue != null && rawValue.isNotEmpty) {
              _hasScanned = true;
              Navigator.of(context).pop(rawValue);
            }
          }
        },
      ),
    );
  }
}

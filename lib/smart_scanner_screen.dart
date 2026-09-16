import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class SmartScannerScreen extends StatefulWidget {
  const SmartScannerScreen({super.key});

  @override
  State<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends State<SmartScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanned = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isScanned) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() => _isScanned = true);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Scan Successful'),
            content: Text('Result: ${barcode.rawValue}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _isScanned = false);
                },
                child: const Text('Scan Again'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved: ${barcode.rawValue}'), backgroundColor: Colors.green),
                  );
                },
                child: const Text('Save Result'),
              ),
            ],
          ),
        );
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Scanner'),
        actions: [
          IconButton(
            icon: ListenableBuilder(
              listenable: cameraController,
              builder: (context, child) {
                final TorchState state = cameraController.value.torchState;
                return Icon(
                  state == TorchState.on ? Icons.flash_on : Icons.flash_off,
                  color: state == TorchState.on ? Colors.yellow : Colors.grey,
                );
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: ListenableBuilder(
              listenable: cameraController,
              builder: (context, child) {
                final CameraFacing direction = cameraController.value.cameraDirection;
                return Icon(direction == CameraFacing.front ? Icons.camera_front : Icons.camera_rear);
              },
            ),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: MobileScanner(
              controller: cameraController,
              onDetect: _handleBarcode,
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              alignment: Alignment.center,
              child: const Text(
                'Align package barcode or QR code within the frame to scan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

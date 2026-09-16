import 'package:flutter/material.dart';

class SmartScannerScreen extends StatelessWidget {
  const SmartScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Scanner'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Barcode / QR scanner ready for scanning package tags.',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                // Scan logic here
              },
              icon: const Icon(Icons.save),
              label: const Text('Save Scan Result'),
            ),
          ],
        ),
      ),
    );
  }
}

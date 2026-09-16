import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'database_helper.dart';

class SmartScannerScreen extends StatefulWidget {
  const SmartScannerScreen({super.key});

  @override
  State<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends State<SmartScannerScreen> {
  List<Map<String, dynamic>> _scannedItems = [];
  bool _isLoading = false;
  
  // ඔබ ලබා දුන් නිල Gemini API Key එක මෙහි ඇතුළත් කර ඇත
  static const String _apiKey = 'AQ.Ab8RN6KtDFji-auKzwCSm_LomGmK6rP0VsG1t88Xsya9Tq54Qg';

  Future<void> _takePhotoAndScan() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) return;

    setState(() {
      _isLoading = true;
      _scannedItems.clear();
    });

    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      final imageBytes = await File(image.path).readAsBytes();
      
      final prompt = TextPart('''
        Analyze this image of a delivery sheet, waybill, or printed list. 
        Extract the details of ALL parcels found in the image. 
        Return ONLY a valid JSON ARRAY of objects (even if there is only one item).
        Each object MUST have these exact keys:
        "billNumber", "itemName", "customerName", "address", "phone", "codAmount".
        If a value is not found, leave it as an empty string "".
        Do not include any conversational text or markdown formatting like ```json.
      ''');
      
      final imageParts = [DataPart('image/jpeg', imageBytes)];
      final response = await model.generateContent([Content.multi([prompt, ...imageParts])]);
      
      if (response.text != null) {
        String rawJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
        final List<dynamic> extractedData = jsonDecode(rawJson);
        
        setState(() {
          _scannedItems = extractedData.map((item) => item as Map<String, dynamic>).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('කියවීමට අපහසුයි. නැවත උත්සහ කරන්න: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAllData() async {
    if (_scannedItems.isEmpty) return;

    for (var item in _scannedItems) {
      Map<String, dynamic> deliveryData = {
        'billNumber': item['billNumber']?.toString() ?? '',
        'itemName': item['itemName']?.toString() ?? '',
        'customerName': item['customerName']?.toString() ?? 'No Name',
        'address': item['address']?.toString() ?? '',
        'phone': item['phone']?.toString() ?? '',
        'codAmount': item['codAmount']?.toString() ?? '0',
      };
      await DatabaseHelper.instance.insertDelivery(deliveryData);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('පාර්සල් ${_scannedItems.length} ක් Morning Call List එකට එකතු විය!'), backgroundColor: Colors.green),
    );

    setState(() {
      _scannedItems.clear();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _scannedItems.removeAt(index);
    });
  }

  void _showManualEntrySheet() {
    final TextEditingController billCtrl = TextEditingController();
    final TextEditingController itemCtrl = TextEditingController();
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController addressCtrl = TextEditingController();
    final TextEditingController phoneCtrl = TextEditingController();
    final TextEditingController codCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('අතින් ඇතුලත් කරන්න (Manual Entry)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: billCtrl, decoration: const InputDecoration(labelText: 'Bill Number', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: itemCtrl, decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer Name *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number *', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: codCtrl, decoration: const InputDecoration(labelText: 'COD Amount', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('නම සහ දුරකථන අංකය අනිවාර්යයි!')));
                      return;
                    }
                    Map<String, dynamic> deliveryData = {
                      'billNumber': billCtrl.text,
                      'itemName': itemCtrl.text,
                      'customerName': nameCtrl.text,
                      'address': addressCtrl.text,
                      'phone': phoneCtrl.text,
                      'codAmount': codCtrl.text.isEmpty ? '0' : codCtrl.text,
                    };
                    await DatabaseHelper.instance.insertDelivery(deliveryData);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('පාර්සලය අතින් එකතු කරන ලදී!'), backgroundColor: Colors.green));
                    }
                  },
                  child: const Text('Save Package'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Scanner & Entry')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.document_scanner, size: 28),
              label: const Text('Scan Waybills / Print List', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
              onPressed: _isLoading ? null : _takePhotoAndScan,
            ),
          ),
          
          if (_isLoading) 
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            )
          else if (_scannedItems.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('පාර්සල් ${_scannedItems.length} ක් හඳුනාගන්නා ලදී.', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _scannedItems.length,
                itemBuilder: (context, index) {
                  final item = _scannedItems[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ListTile(
                      title: Text(item['customerName'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Tel: ${item['phone']}\nCOD: ${item['codAmount']}\nItem: ${item['itemName'] ?? ''}'),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeItem(index),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: constပြင်ဆද all(16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_all),
                label: const Text('Save All to Morning List', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _saveAllData,
              ),
            ),
          ] else ...[
            const Expanded(
              child: Center(
                child: Text('කැමරාව මගින් පාර්සල් ලැයිස්තුවෙහි ඡායාරූපයක් ගන්න.', style: TextStyle(color: Colors.grey)),
              ),
            )
          ]
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showManualEntrySheet,
        icon: const Icon(Icons.edit_document),
        label: const Text('Manual Entry'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

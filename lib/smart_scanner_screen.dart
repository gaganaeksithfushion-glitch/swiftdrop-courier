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
  // කියවාගත් පාර්සල් ලැයිස්තුව තබාගන්නා තැන
  List<Map<String, dynamic>> _scannedItems = [];
  bool _isLoading = false;
  
  // TODO: Get a free key from https://aistudio.google.com/ and paste it here
  static const String _apiKey = 'YOUR_GEMINI_API_KEY_HERE';

  // ෆොටෝ එක ගෙන AI එකට යැවීම (Mass Scanner)
  Future<void> _takePhotoAndScan() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) return;

    setState(() {
      _isLoading = true;
      _scannedItems.clear(); // අලුත් ෆොටෝ එකක් ගහනකොට පරණ ලිස්ට් එක මකනවා
    });

    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      final imageBytes = await File(image.path).readAsBytes();
      
      // AI එකට දෙන අලුත් උපදෙස (Multiple Items & New Fields)
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
        
        // JSON Array එකක් ලැයිස්තුවක් (List) බවට පත් කිරීම
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

  // Preview ලිස්ට් එකේ තියෙන සියල්ල Database එකට සේව් කිරීම
  Future<void> _saveAllData() async {
    if (_scannedItems.isEmpty) return;

    for (var item in _scannedItems) {
      // AI එකෙන් ආපු දත්ත Database එකට ගැලපෙන විදියට සකස් කිරීම
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
      SnackBar(
        content: Text('පාර්සල් ${_scannedItems.length} ක් සාර්ථකව Morning Call List එකට එකතු විය!'),
        backgroundColor: Colors.green,
      ),
    );

    setState(() {
      _scannedItems.clear(); // සේව් කළාට පසු ලිස්ට් එක හිස් කිරීම
    });
  }

  // ලිස්ට් එකෙන් වැරදි එකක් අතින් මකා දැමීම (Preview එකේදී)
  void _removeItem(int index) {
    setState(() {
      _scannedItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Mass Scanner')),
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
              child: Text('පාර්සල් ${_scannedItems.length} ක් හඳුනාගන්නා ලදී. කරුණාකර පරීක්ෂා කරන්න.', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
            // AI එකෙන් කියවපු දත්ත ලැයිස්තුවක් ලෙස පෙන්වීම
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
                        onPressed: () => _removeItem(index), // වැරදියට කියවපු එකක් තිබුණොත් අයින් කරන්න
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // සියල්ල සේව් කිරීමේ බොත්තම
            Padding(
              padding: const EdgeInsets.all(16.0),
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
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'database_helper.dart';

// ==========================================================================
// ⚠️ SECURITY NOTE: මේ key එක app එකේ decompile කරලා අයින් කරන්න පුළුවන්.
// Production app එකකට නම් මේක backend server එකක් හරහා යවන්න ඕන.
// ==========================================================================
const String _geminiApiKey = 'AQ.Ab8RN6KtDFji-auKzwCSm_LomGmK6rP0VsG1t88Xsya9Tq54Qg';
const String _geminiModel = 'gemini-2.5-flash';

class ParcelEntry {
  final TextEditingController billNo = TextEditingController();
  final TextEditingController name = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController address = TextEditingController();
  final TextEditingController item = TextEditingController();
  final TextEditingController cod = TextEditingController();

  ParcelEntry.fromMap(Map<String, dynamic> map) {
    billNo.text = (map['billNumber'] ?? '').toString();
    name.text = (map['customerName'] ?? '').toString();
    phone.text = (map['phone'] ?? '').toString();
    address.text = (map['address'] ?? '').toString();
    item.text = (map['itemName'] ?? '').toString();
    cod.text = (map['codAmount'] ?? '').toString();
  }

  void dispose() {
    billNo.dispose();
    name.dispose();
    phone.dispose();
    address.dispose();
    item.dispose();
    cod.dispose();
  }
}

class SmartScannerScreen extends StatefulWidget {
  const SmartScannerScreen({super.key});

  @override
  State<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends State<SmartScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _isProcessing = false;
  String? _errorText;
  List<ParcelEntry> _parcels = [];

  @override
  void dispose() {
    for (final p in _parcels) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _scanWaybillPhoto() async {
    var status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('කැමරාවට අවසර අවශ්‍යයි!'), backgroundColor: Colors.red),
      );
      return;
    }

    final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (photo == null) return;

    setState(() {
      _imageFile = File(photo.path);
      _isProcessing = true;
      _errorText = null;
      for (final p in _parcels) {
        p.dispose();
      }
      _parcels = [];
    });

    try {
      final List<Map<String, dynamic>> extracted = await _callGeminiVision(_imageFile!);
      setState(() {
        _parcels = extracted.map((m) => ParcelEntry.fromMap(m)).toList();
      });

      if (!mounted) return;
      if (_parcels.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parcel details මොනවත් හම්බුනේ නෑ. Photo එක clear ද කියලා බලලා ආයෙත් try කරන්න.'), backgroundColor: Colors.orange),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Parcels ${_parcels.length}ක් හම්බුනා! Check කරලා Save කරන්න.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _errorText = e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gemini scan දෝෂයක්: $e'), backgroundColor: Colors.red),
      );
    }

    setState(() => _isProcessing = false);
  }

  // Gemini Vision API එකට photo එක යවලා structured JSON එකක් ලබාගැනීම
  Future<List<Map<String, dynamic>>> _callGeminiVision(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent',
    );

    const prompt = '''
You are reading a courier way-bill / parcel delivery list photo (may be printed or handwritten, may contain one or many parcel rows/entries).
Extract every parcel entry you can find and return ONLY a valid JSON array (no markdown, no explanation, no code fences), like this:
[
  {"billNumber": "", "customerName": "", "phone": "", "address": "", "itemName": "", "codAmount": ""}
]
Rules:
- phone: Sri Lankan mobile number format starting with 0 (e.g. 0771234567). If not found, use "".
- codAmount: numbers only, no "Rs." or commas. If not found, use "".
- If a field is not visible/legible, use "" for that field — never guess.
- If there is only one parcel in the photo, still return an array with one object.
- Return ONLY the JSON array, nothing else.
''';

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {
              "inline_data": {"mime_type": "image/jpeg", "data": base64Image}
            },
            {"text": prompt},
          ]
        }
      ]
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': _geminiApiKey,
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    String text = decoded['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';

    // Gemini සමහරවිට ```json ... ``` code fence එකක් දාන්න පුළුවන් - ඒක clean කරගැනීම
    text = text.trim();
    if (text.startsWith('```')) {
      text = text.replaceAll(RegExp(r'^```json'), '').replaceAll(RegExp(r'^```'), '').replaceAll(RegExp(r'```$'), '').trim();
    }

    final List<dynamic> parsed = jsonDecode(text);
    return parsed.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _saveAllToDatabase() async {
    int savedCount = 0;
    for (final p in _parcels) {
      if (p.name.text.isEmpty && p.phone.text.isEmpty) continue; // හිස් row skip
      await DatabaseHelper.instance.insertDelivery({
        'billNumber': p.billNo.text,
        'itemName': p.item.text.isEmpty ? 'Parcel' : p.item.text,
        'customerName': p.name.text,
        'address': p.address.text,
        'phone': p.phone.text,
        'codAmount': p.cod.text.isEmpty ? '0' : p.cod.text,
        'notes': '',
      });
      savedCount++;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Parcels $savedCountක් Database එකට Save විය!'), backgroundColor: Colors.green),
    );

    setState(() {
      for (final p in _parcels) {
        p.dispose();
      }
      _parcels = [];
      _imageFile = null;
    });
  }

  void _removeParcel(int index) {
    setState(() {
      _parcels[index].dispose();
      _parcels.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Scanner & Entry')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Way Bill / Parcel List එකේ Photo එකක් ගන්න (Gemini AI කියවනවා):',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isProcessing ? null : _scanWaybillPhoto,
              icon: const Icon(Icons.camera_alt),
              label: Text(_isProcessing ? 'Scanning...' : 'Take Photo & Scan with AI', style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),

            if (_isProcessing) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              const Center(child: Text('Gemini AI photo එක කියවනවා...', style: TextStyle(color: Colors.grey))),
            ],

            if (!_isProcessing && _imageFile != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_imageFile!, height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
            ],

            if (_parcels.isNotEmpty) ...[
              const Divider(thickness: 2),
              Text('හම්බුනු Parcels (${_parcels.length}) — check කරලා edit කරන්න:', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...List.generate(_parcels.length, (index) {
                final p = _parcels[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text('Parcel ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _removeParcel(index),
                              tooltip: 'මේක ඉවත් කරන්න',
                            ),
                          ],
                        ),
                        TextField(controller: p.name, decoration: const InputDecoration(labelText: 'නම (Name)', isDense: true)),
                        const SizedBox(height: 8),
                        TextField(controller: p.billNo, decoration: const InputDecoration(labelText: 'Bill No', isDense: true)),
                        const SizedBox(height: 8),
                        TextField(controller: p.phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', isDense: true)),
                        const SizedBox(height: 8),
                        TextField(controller: p.address, decoration: const InputDecoration(labelText: 'Address', isDense: true)),
                        const SizedBox(height: 8),
                        TextField(controller: p.item, decoration: const InputDecoration(labelText: 'Item', isDense: true)),
                        const SizedBox(height: 8),
                        TextField(controller: p.cod, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'COD (Rs.)', isDense: true)),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveAllToDatabase,
                icon: const Icon(Icons.save),
                label: Text('Save All (${_parcels.length}) to Database', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

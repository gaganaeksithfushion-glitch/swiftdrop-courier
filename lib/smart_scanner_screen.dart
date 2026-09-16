import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'database_helper.dart'; // Database එක මෙතනට සම්බන්ධ කර ඇත

class SmartScannerScreen extends StatefulWidget {
  const SmartScannerScreen({super.key});

  @override
  State<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends State<SmartScannerScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codController = TextEditingController();
  
  bool _isLoading = false;
  
  // TODO: Get a free key from https://aistudio.google.com/ and paste it here
  static const String _apiKey = 'YOUR_GEMINI_API_KEY_HERE';

  Future<void> _takePhotoAndScan() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      final imageBytes = await File(image.path).readAsBytes();
      
      final prompt = TextPart('''
        Analyze this handwritten delivery sheet. 
        Extract the customer details and return ONLY a valid JSON object with exact keys:
        "customerName", "address", "phone", "codAmount".
        Do not include any other conversational text or markdown.
      ''');
      
      final imageParts = [DataPart('image/jpeg', imageBytes)];
      final response = await model.generateContent([Content.multi([prompt, ...imageParts])]);
      
      if (response.text != null) {
        String rawJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
        final Map<String, dynamic> data = jsonDecode(rawJson);
        
        setState(() {
          _nameController.text = data['customerName']?.toString() ?? '';
          _addressController.text = data['address']?.toString() ?? '';
          _phoneController.text = data['phone']?.toString() ?? '';
          _codController.text = data['codAmount']?.toString() ?? '';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to read text: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // අලුතින් එකතු කළ දත්ත සේව් කිරීමේ කොටස
  Future<void> _saveData() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('කරුණාකර පාරිභෝගිකයාගේ නම සහ දුරකථන අංකය ඇතුලත් කරන්න.')),
      );
      return;
    }

    Map<String, dynamic> deliveryData = {
      'customerName': _nameController.text,
      'address': _addressController.text,
      'phone': _phoneController.text,
      'codAmount': _codController.text,
    };

    // Database එකට යැවීම
    await DatabaseHelper.instance.insertDelivery(deliveryData);

    // සාර්ථක බව දැනුම් දීම
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('දත්ත සාර්ථකව සේව් විය!'),
        backgroundColor: Colors.green,
      ),
    );

    // ඊළඟ දත්තය ඇතුලත් කරන්න ලේසි වෙන්න කොටු ටික හිස් කිරීම
    _nameController.clear();
    _addressController.clear();
    _phoneController.clear();
    _codController.clear();
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
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo & Scan Text'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
              onPressed: _isLoading ? null : _takePhotoAndScan,
            ),
            const SizedBox(height: 24),
            
            if (_isLoading) 
              const Center(child: CircularProgressIndicator())
            else ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Customer Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codController,
                decoration: const InputDecoration(labelText: 'COD Amount', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                // බොත්තම එබූ විට සේව් වීමේ කේතය ක්‍රියාත්මක වේ
                onPressed: _saveData,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Entry & Add Package'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

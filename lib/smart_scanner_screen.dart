import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class SmartScannerScreen extends StatefulWidget {
  const SmartScannerScreen({super.key});

  @override
  State<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends State<SmartScannerScreen> {
  // Controllers to manage the text inside the input fields
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

    if (image == null) return; // User canceled the camera

    setState(() {
      _isLoading = true;
    });

    try {
      // Using gemini-1.5-flash as it is lightning fast for vision tasks
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      final imageBytes = await File(image.path).readAsBytes();
      
      // We strictly instruct the AI to return JSON so our app doesn't crash trying to read it
      final prompt = TextPart('''
        Analyze this handwritten delivery sheet. 
        Extract the customer details and return ONLY a valid JSON object with exact keys:
        "customerName", "address", "phone", "codAmount".
        Do not include any other conversational text or markdown.
      ''');
      
      final imageParts = [DataPart('image/jpeg', imageBytes)];
      final response = await model.generateContent([Content.multi([prompt, ...imageParts])]);
      
      if (response.text != null) {
        // Clean up the response in case the AI wraps it in markdown (```json ... ```)
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
            
            // Show a loading spinner while the AI is thinking
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
                onPressed: () {
                  // Database save logic will go here
                },
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

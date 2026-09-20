import 'package:flutter/material.dart';
import 'database_helper.dart';

class SmartScannerScreen extends StatefulWidget {
  const SmartScannerScreen({super.key});

  @override
  State<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends State<SmartScannerScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _billNoController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _phone2Controller = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _codController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _billNoController.dispose();
    _phoneController.dispose();
    _phone2Controller.dispose();
    _addressController.dispose();
    _itemController.dispose();
    _codController.dispose();
    super.dispose();
  }

  Future<void> _saveToDatabase() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('නම සහ දුරකථන අංකය අවශ්‍යයි!'), backgroundColor: Colors.orange),
      );
      return;
    }

    await DatabaseHelper.instance.insertDelivery({
      'billNumber': _billNoController.text,
      'itemName': _itemController.text.isEmpty ? 'Parcel' : _itemController.text,
      'customerName': _nameController.text,
      'address': _addressController.text,
      'phone': _phoneController.text,
      'phone2': _phone2Controller.text,
      'codAmount': _codController.text.isEmpty ? '0' : _codController.text,
      'notes': '',
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('සාර්ථකව Database එකට Save විය!'), backgroundColor: Colors.green),
    );

    setState(() {
      _nameController.clear();
      _billNoController.clear();
      _phoneController.clear();
      _phone2Controller.clear();
      _addressController.clear();
      _itemController.clear();
      _codController.clear();
    });
  }

  void _showComingSoonMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚧 Smart AI Scan feature එක සංවර්ධනය වෙමින් පවතී (Under Development). ළඟදීම එනවා!'),
        backgroundColor: Colors.deepPurple,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Entry')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Parcel විස්තර අතින් ඇතුළත් කරන්න:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'පාරිභෝගිකයාගේ නම (Name)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _billNoController,
              decoration: const InputDecoration(labelText: 'Bill No', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'දුරකථන අංකය (Phone)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone2Controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'දුරකථන අංකය 2 (Phone 2 - Optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'ලිපිනය (Address)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _itemController,
              decoration: const InputDecoration(labelText: 'භාණ්ඩයේ නම (Item)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _codController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'COD මුදල (Rs.)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saveToDatabase,
              icon: const Icon(Icons.save),
              label: const Text('Save to Database', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            // Smart AI Scan button එකට ඉඩ ඉතුරු කරන්න
            const SizedBox(height: 80),
          ],
        ),
      ),
      // පහළ දකුණු කෙළවරේ කුඩා Smart AI Scan button එක
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showComingSoonMessage,
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: const Text('Smart Scan', style: TextStyle(color: Colors.white)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

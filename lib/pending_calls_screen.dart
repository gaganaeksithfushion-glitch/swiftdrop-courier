import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

class PendingCallsScreen extends StatefulWidget {
  const PendingCallsScreen({super.key});

  @override
  State<PendingCallsScreen> createState() => _PendingCallsScreenState();
}

class _PendingCallsScreenState extends State<PendingCallsScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> pendingCalls = [];
  bool _isLoading = true;

  final String _defaultMsg =
      "ආයුබෝවන් {name}, ඔබගේ පාර්සලය (COD: Rs.{cod}) අද දිනයේ බෙදා හැරීමට නියමිතයි. කරුණාකර ඔබගේ Location එක එවන්න.";

  @override
  void initState() {
    super.initState();
    _loadPendingCalls();
  }

  // Database එකෙන් අදට Pending/Rescheduled Calls ටික load කිරීම
  Future<void> _loadPendingCalls() async {
    setState(() => _isLoading = true);
    final data = await dbHelper.getMorningCalls();
    if (!mounted) return;
    setState(() {
      pendingCalls = data;
      _isLoading = false;
    });
  }

  // දුරකථන ඇමතුමක් ලබා දීම (Dialer)
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint('Could not launch phone call to $phoneNumber');
    }
  }

  // Settings screen එකේ Save කරපු WhatsApp Message Template එක ලබාගැනීම
  Future<String> _getMessageTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('whatsapp_template') ?? _defaultMsg;
  }

  // WhatsApp චැට් වෙත message එකක් සමග යොමු කිරීම
  Future<void> _openWhatsAppWithMessage(String phone, String message) async {
    final formattedPhone = phone.replaceAll('+', '').replaceAll(' ', '');
    final encodedMessage = Uri.encodeComponent(message);
    final Uri whatsappUri = Uri.parse('https://wa.me/$formattedPhone?text=$encodedMessage');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication, // බාහිරව WhatsApp ඇප් එක විවෘත කිරීමට මෙය අත්‍යවශ්‍යයි
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp නොමැත හෝ විවෘත කරගත නොහැක.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Manual ලෙස Chat button එකෙන් යවන WhatsApp Message එක (location ඉල්ලීමකින් තොරව)
  Future<void> _openWhatsAppManual(Map<String, dynamic> item) async {
    final template = await _getMessageTemplate();
    final message = template
        .replaceAll('{name}', (item['customerName'] ?? '').toString())
        .replaceAll('{cod}', (item['codAmount'] ?? '0').toString());
    await _openWhatsAppWithMessage((item['phone'] ?? '').toString(), message);
  }

  // Confirm කරාම Automatic ලෙස WhatsApp Message + Location Share ඉල්ලීම යැවීම
  Future<void> _sendConfirmationWithLocationRequest(Map<String, dynamic> item) async {
    final template = await _getMessageTemplate();
    String message = template
        .replaceAll('{name}', (item['customerName'] ?? '').toString())
        .replaceAll('{cod}', (item['codAmount'] ?? '0').toString());

    // Live Location share කරන්න ඉල්ලීමක් message එකට එකතු කිරීම
    message +=
        '\n\n📍 කරුණාකර ඔබගේ Live Location එක මේ WhatsApp Chat එකෙන්ම Share කරන්න:\n📎 Attach → Location → Send your current location (හෝ Live Location).';

    await _openWhatsAppWithMessage((item['phone'] ?? '').toString(), message);
  }

  Future<void> _updateStatus(Map<String, dynamic> item, String status) async {
    final id = item['id'] as int;
    final attempts = (item['callAttempts'] ?? 0) as int;
    // "No Answer" වගේ තත්වයක් නම් attempt count එක වැඩි කරනවා
    final newAttempts = status == 'pending' ? attempts + 1 : attempts;
    await dbHelper.updateDeliveryStatus(id, status, newAttempts);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('පාර්සලය $status ලෙස සටහන් විය!'),
        backgroundColor: status == 'confirmed' ? Colors.green : Colors.red,
      ),
    );

    // Confirm කරාම, WhatsApp message + location request එක auto ලෙස යැවීම
    if (status == 'confirmed') {
      await _sendConfirmationWithLocationRequest(item);
    }

    _loadPendingCalls();
  }

  // Order එකේ Details (Name/Phone/Address/Item/Price) Manual ලෙස Edit කිරීම
  Future<void> _showEditDialog(Map<String, dynamic> item) async {
    final nameController = TextEditingController(text: (item['customerName'] ?? '').toString());
    final billController = TextEditingController(text: (item['billNumber'] ?? '').toString());
    final phoneController = TextEditingController(text: (item['phone'] ?? '').toString());
    final phone2Controller = TextEditingController(text: (item['phone2'] ?? '').toString());
    final addressController = TextEditingController(text: (item['address'] ?? '').toString());
    final itemController = TextEditingController(text: (item['itemName'] ?? '').toString());
    final codController = TextEditingController(text: (item['codAmount'] ?? '').toString());

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Order Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Customer Name')),
                const SizedBox(height: 10),
                TextField(controller: billController, decoration: const InputDecoration(labelText: 'Bill No')),
                const SizedBox(height: 10),
                TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 10),
                TextField(controller: phone2Controller, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone 2 (Optional)')),
                const SizedBox(height: 10),
                TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
                const SizedBox(height: 10),
                TextField(controller: itemController, decoration: const InputDecoration(labelText: 'Item Name')),
                const SizedBox(height: 10),
                TextField(controller: codController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'COD Price (Rs.)')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await dbHelper.updateDeliveryDetails(item['id'] as int, {
                  'customerName': nameController.text,
                  'billNumber': billController.text,
                  'phone': phoneController.text,
                  'phone2': phone2Controller.text,
                  'address': addressController.text,
                  'itemName': itemController.text,
                  'codAmount': codController.text,
                });
                if (!mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Details Update විය!'), backgroundColor: Colors.green),
                );
                _loadPendingCalls();
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  // දුරකථන අංකයක් Tap කරන්න පුළුවන් Row එකක් හදන Widget එක (Dialer විදිහට)
  Widget _phoneRow(String label, String phone) {
    if (phone.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: () => _makePhoneCall(phone),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          children: [
            const Icon(Icons.phone, size: 16, color: Colors.blue),
            const SizedBox(width: 6),
            Text(
              '$label: $phone',
              style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Calls & WhatsApp'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPendingCalls, tooltip: 'Refresh'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : pendingCalls.isEmpty
              ? const Center(child: Text('Pending calls කිසිවක් නැත.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: pendingCalls.length,
                  itemBuilder: (context, index) {
                    final call = pendingCalls[index];
                    final name = (call['customerName'] ?? '').toString();
                    final phone = (call['phone'] ?? '').toString();
                    final phone2 = (call['phone2'] ?? '').toString();
                    final address = (call['address'] ?? '').toString();
                    final itemName = (call['itemName'] ?? 'Parcel').toString();
                    final codAmount = (call['codAmount'] ?? '0').toString();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                                  onPressed: () => _showEditDialog(call),
                                  tooltip: 'Edit Details',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Item: $itemName  •  Price (COD): Rs. $codAmount'),
                            Text('Address: $address'),
                            const SizedBox(height: 4),
                            // Phone number(s) - tap කරලාම call කරන්න පුළුවන් (dialer)
                            _phoneRow('Phone', phone),
                            _phoneRow('Phone 2', phone2),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chat, color: Colors.green),
                                  onPressed: () => _openWhatsAppManual(call),
                                  tooltip: 'WhatsApp Message',
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => _updateStatus(call, 'pending'),
                                  child: const Text('No Answer'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  onPressed: () => _updateStatus(call, 'confirmed'),
                                  child: const Text('Confirm'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

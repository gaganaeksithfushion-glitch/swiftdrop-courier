import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // WhatsApp චැට් වෙත කෙළින්ම යොමු කිරීම
  Future<void> _openWhatsApp(String phone, String name) async {
    final formattedPhone = phone.replaceAll('+', '').replaceAll(' ', '');
    final message = Uri.encodeComponent('ආයුබෝවන් $name, ඔබේ පාර්සලය සම්බන්ධයෙනි.');
    final Uri whatsappUri = Uri.parse('https://wa.me/$formattedPhone?text=$message');

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
    _loadPendingCalls();
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
                            Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Item: $itemName  •  Price (COD): Rs. $codAmount'),
                            Text('Address: $address'),
                            Text('Phone: $phone'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.phone, color: Colors.blue),
                                  onPressed: () => _makePhoneCall(phone),
                                  tooltip: 'Call',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chat, color: Colors.green),
                                  onPressed: () => _openWhatsApp(phone, name),
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

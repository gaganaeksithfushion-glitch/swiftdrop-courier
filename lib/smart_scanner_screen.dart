import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PendingCallsScreen extends StatefulWidget {
  const PendingCallsScreen({super.key});

  @override
  State<PendingCallsScreen> createState() => _PendingCallsScreenState();
}

class _PendingCallsScreenState extends State<PendingCallsScreen> {
  final List<Map<String, dynamic>> pendingCalls = [
    {'name': 'Nimal Perera', 'phone': '+94771234567', 'address': 'Kandy Road, Colombo', 'attempts': 1},
    {'name': 'Kamal Silva', 'phone': '+94719876543', 'address': 'Galle Road, Matara', 'attempts': 3},
  ];

  // දුරකථන ඇමතුමක් ලබා දීම (Dialer)
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint('Could not launch phone call to $phoneNumber');
    }
  }

  // WhatsApp පණිවිඩයක් යැවීම
  Future<void> _openWhatsApp(String phone, String name) async {
    final formattedPhone = phone.replaceAll('+', '');
    final message = Uri.encodeComponent('ഹലോ $name, ඔබේ පාර්සලය සම්බන්ධයෙනි.');
    final Uri whatsappUri = Uri.parse('https://wa.me/$formattedPhone?text=$message');
    
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch WhatsApp');
    }
  }

  void _updateStatus(int index, String status) {
    setState(() {
      pendingCalls.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('පාර්සලය $status ලෙස සටහන් විය!'),
        backgroundColor: status == 'Confirmed' ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Calls & Verification'),
      ),
      body: pendingCalls.isEmpty
          ? const Center(child: Text('Pending calls කිසිවක් නැත.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: pendingCalls.length,
              itemBuilder: (context, index) {
                final call = pendingCalls[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(call['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Address: ${call['address']}'),
                        Text('Phone: ${call['phone']}'),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Dialer Button
                            IconButton(
                              icon: const Icon(Icons.phone, color: Colors.blue),
                              onPressed: () => _makePhoneCall(call['phone']),
                              tooltip: 'Call Customer',
                            ),
                            // WhatsApp Button
                            IconButton(
                              icon: const Icon(Icons.chat, color: Colors.green),
                              onPressed: () => _openWhatsApp(call['phone'], call['name']),
                              tooltip: 'WhatsApp Message',
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: () => _updateStatus(index, 'Confirmed'),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Confirm'),
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

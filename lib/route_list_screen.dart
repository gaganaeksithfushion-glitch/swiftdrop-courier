import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RouteListScreen extends StatefulWidget {
  const RouteListScreen({super.key});

  @override
  State<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends State<RouteListScreen> {
  final List<Map<String, String>> deliveries = [
    {'order': 'Order #101', 'address': '45/2 Temple Road, Colombo', 'phone': '+94771234567'},
    {'order': 'Order #102', 'address': '12 Main Street, Kandy', 'phone': '+94719876543'},
  ];

  Future<void> _openMap(String address) async {
    final query = Uri.encodeComponent(address);
    final Uri mapUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(mapUri)) {
      await launchUrl(mapUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  void _markDelivered(int index) {
    setState(() => deliveries.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('සාර්ථකව Delivered ලෙස සටහන් විය!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Map & Deliveries')),
      body: deliveries.isEmpty
          ? const Center(child: Text('අදට නියමිත බෙදාහැරීම් අවසන්ය.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: deliveries.length,
              itemBuilder: (context, index) {
                final item = deliveries[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['order']!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(item['address']!),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.navigation, color: Colors.blue),
                              onPressed: () => _openMap(item['address']!),
                              tooltip: 'Navigate',
                            ),
                            IconButton(
                              icon: const Icon(Icons.phone, color: Colors.green),
                              onPressed: () => _makePhoneCall(item['phone']!),
                              tooltip: 'Call',
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () => _markDelivered(index),
                              child: const Text('Delivered'),
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

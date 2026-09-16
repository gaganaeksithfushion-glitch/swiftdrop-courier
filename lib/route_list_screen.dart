import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'database_helper.dart';

class RouteListScreen extends StatefulWidget {
  const RouteListScreen({super.key});

  @override
  State<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends State<RouteListScreen> {
  List<Map<String, dynamic>> _confirmedDeliveries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfirmedDeliveries();
  }

  Future<void> _loadConfirmedDeliveries() async {
    final data = await DatabaseHelper.instance.getConfirmedDeliveries();
    setState(() {
      _confirmedDeliveries = data;
      _isLoading = false;
    });
  }

  // 1. Google Maps විවෘත කිරීම
  Future<void> _openGoogleMaps(String address) async {
    final Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}");
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Maps විවෘත කළ නොහැක.')));
    }
  }

  // 2. Dialer එක විවෘත කිරීම (ගේට්ටුව ගාවදි කෝල් කරන්න)
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('දුරකථන ඇමතුම ලබා ගත නොහැක.')));
    }
  }

  // 3. Delivered ලෙස සටහන් කිරීම
  Future<void> _markAsDelivered(int id) async {
    // Attempts ගණන වෙනස් නොකර Status එක පමණක් වෙනස් කරයි
    await DatabaseHelper.instance.updateDeliveryStatus(id, 'delivered', 0);
    _loadConfirmedDeliveries(); // ලිස්ට් එක Refresh කිරීම
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('සාර්ථකව Delivered ලෙස සටහන් විය!', backgroundColor: Colors.green)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route List (Confirmed)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _confirmedDeliveries.isEmpty
              ? const Center(child: Text('බෙදා හැරීමට පාර්සල් නොමැත.', style: TextStyle(fontSize: 16)))
              : ListView.builder(
                  itemCount: _confirmedDeliveries.length,
                  itemBuilder: (context, index) {
                    final delivery = _confirmedDeliveries[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.green, width: 1)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(delivery['customerName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 8),
                            
                            // ලිපිනය මත Click කළ විටද Maps විවෘත වේ
                            InkWell(
                              onTap: () => _openGoogleMaps(delivery['address']),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, color: Colors.red, size: 20),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(delivery['address'], style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline))),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            Text('COD: ${delivery['codAmount']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                            if (delivery['notes'] != null && delivery['notes'].toString().isNotEmpty)
                              Text('Note: ${delivery['notes']}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                            
                            const Divider(height: 24),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Navigate Button
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.map),
                                  label: const Text('Map'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                                  onPressed: () => _openGoogleMaps(delivery['address']),
                                ),
                                // Call Button
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.call),
                                  label: const Text('Call'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                                  onPressed: () => _makePhoneCall(delivery['phone']),
                                ),
                                // Delivered Button
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.check_box),
                                  label: const Text('Delivered'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  onPressed: () => _markAsDelivered(delivery['id']),
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

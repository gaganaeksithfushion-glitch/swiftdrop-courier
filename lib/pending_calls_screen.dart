import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'database_helper.dart';
import 'smart_scanner_screen.dart';

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

  // දුරකථන ඇමතුමක් ලබා දීම (Dialer) - Phone 1 හෝ Phone 2 ඕනෑම එකකට
  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint('Could not launch phone call to $phoneNumber');
    }
  }

  Future<void> _editDelivery(Map<String, dynamic> item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SmartScannerScreen(deliveryToEdit: item)),
    );
    if (result == true) _loadPendingCalls();
  }

  // Settings එකේ Save කරපු WhatsApp Template එක Load කිරීම, {name}/{cod} Replace කිරීම
  Future<String> _buildMessage(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    String template = prefs.getString('whatsapp_template') ?? _defaultMsg;
    template = template.replaceAll('{name}', (item['customerName'] ?? '').toString());
    template = template.replaceAll('{cod}', (item['codAmount'] ?? '0').toString());
    return template;
  }

  // GPS හරහා Current Location එක ලබාගෙන Google Maps Link එකක් හදාගැනීම
  Future<String?> _getLocationLink(BuildContext dialogContext) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(content: Text('Location Services එක Off වෙලා තියෙන්නේ, කරුණාකර GPS On කරන්න!'), backgroundColor: Colors.orange),
      );
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (dialogContext.mounted) {
          ScaffoldMessenger.of(dialogContext).showSnackBar(
            const SnackBar(content: Text('Location Permission එක දෙන්න ඕන!'), backgroundColor: Colors.red),
          );
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(content: Text('Location Permission එක Settings එකෙන් On කරන්න ඕන!'), backgroundColor: Colors.red),
        );
      }
      return null;
    }

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    return 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
  }

  // Confirm Dialog එක - WhatsApp Message Preview + Location Picker සමග
  Future<void> _showConfirmDialog(Map<String, dynamic> item) async {
    final phone1 = (item['phone'] ?? '').toString();
    final phone2 = (item['phone2'] ?? '').toString();
    final messageController = TextEditingController(text: await _buildMessage(item));
    String selectedPhone = phone1;
    bool isFetchingLocation = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Confirm & Send WhatsApp'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (phone2.isNotEmpty) ...[
                      const Text('WhatsApp යවන්නේ මොන Number එකටද?', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: selectedPhone,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                        items: [phone1, phone2]
                            .where((p) => p.isNotEmpty)
                            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setDialogState(() => selectedPhone = value);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: messageController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp Message',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: isFetchingLocation
                          ? null
                          : () async {
                              setDialogState(() => isFetchingLocation = true);
                              final link = await _getLocationLink(dialogContext);
                              setDialogState(() => isFetchingLocation = false);
                              if (link != null) {
                                messageController.text = '${messageController.text}\n📍 My Location: $link';
                              }
                            },
                      icon: isFetchingLocation
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location, color: Colors.blue),
                      label: const Text('Add My Current Location'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    // WhatsApp නැතුව Confirm විතරක් කරන්න ඕන අයට
                    Navigator.pop(dialogContext);
                    await _confirmStatusOnly(item);
                  },
                  child: const Text('Skip & Just Confirm'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: selectedPhone.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);
                          await _sendWhatsAppAndConfirm(item, selectedPhone, messageController.text);
                        },
                  icon: const Icon(Icons.chat),
                  label: const Text('Send via WhatsApp'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendWhatsAppAndConfirm(Map<String, dynamic> item, String phone, String message) async {
    final formattedPhone = phone.replaceAll('+', '').replaceAll(' ', '');
    final encodedMessage = Uri.encodeComponent(message);
    final Uri whatsappUri = Uri.parse('https://wa.me/$formattedPhone?text=$encodedMessage');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp නොමැත හෝ විවෘත කරගත නොහැක.'), backgroundColor: Colors.red),
        );
      }
    }
    await _updateStatus(item, 'confirmed');
  }

  Future<void> _confirmStatusOnly(Map<String, dynamic> item) async {
    await _updateStatus(item, 'confirmed');
  }

  Future<void> _updateStatus(Map<String, dynamic> item, String status) async {
    final id = item['id'] as int;
    final attempts = (item['callAttempts'] ?? 0) as int;
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

  // Dialer-style Tappable Phone Number Row එකක්
  Widget _phoneRow(String phone, {required Color color}) {
    if (phone.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: () => _makePhoneCall(phone),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(Icons.call, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              phone,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
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
                    final phone1 = (call['phone'] ?? '').toString();
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
                                  icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                                  onPressed: () => _editDelivery(call),
                                  tooltip: 'Edit',
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Item: $itemName  •  Price (COD): Rs. $codAmount'),
                            Text('Address: $address'),
                            const SizedBox(height: 4),
                            _phoneRow(phone1, color: Colors.blue),
                            _phoneRow(phone2, color: Colors.indigo),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chat, color: Colors.green),
                                  onPressed: () async {
                                    final msg = await _buildMessage(call);
                                    await _sendWhatsAppAndConfirm(call, phone1.isNotEmpty ? phone1 : phone2, msg);
                                  },
                                  tooltip: 'Quick WhatsApp',
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => _updateStatus(call, 'pending'),
                                  child: const Text('No Answer'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  onPressed: () => _showConfirmDialog(call),
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

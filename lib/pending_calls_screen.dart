import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <--- මෙය එකතු කළා
import 'database_helper.dart';

class PendingCallsScreen extends StatefulWidget {
  const PendingCallsScreen({super.key});

  @override
  State<PendingCallsScreen> createState() => _PendingCallsScreenState();
}

class _PendingCallsScreenState extends State<PendingCallsScreen> {
  List<Map<String, dynamic>> _allDeliveries = [];
  List<Map<String, dynamic>> _filteredDeliveries = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMorningCalls();
  }

  Future<void> _loadMorningCalls() async {
    final data = await DatabaseHelper.instance.getMorningCalls();
    setState(() {
      _allDeliveries = data;
      _isLoading = false;
    });
    _runFilter(_searchController.text);
  }

  void _runFilter(String enteredKeyword) {
    List<Map<String, dynamic>> results = [];
    if (enteredKeyword.isEmpty) {
      results = _allDeliveries;
    } else {
      results = _allDeliveries.where((delivery) {
        final name = delivery['customerName'].toString().toLowerCase();
        final phone = delivery['phone'].toString().toLowerCase();
        final bill = (delivery['billNumber'] ?? '').toString().toLowerCase();
        final searchStr = enteredKeyword.toLowerCase();
        return name.contains(searchStr) || phone.contains(searchStr) || bill.contains(searchStr);
      }).toList();
    }
    setState(() {
      _filteredDeliveries = results;
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('දුරකථන ඇමතුම ලබා ගත නොහැක.')));
    }
  }

  // අලුතින් එකතු කළ WhatsApp කේතය
  Future<void> _sendWhatsApp(String phoneNumber, String name, String codAmount) async {
    final prefs = await SharedPreferences.getInstance();
    // Settings වලින් සේව් කළ පණිවිඩය ලබා ගැනීම (නැත්නම් සාමාන්‍ය පණිවිඩය යොදාගනී)
    String template = prefs.getString('whatsapp_template') ?? "ආයුබෝවන් {name}, ඔබගේ පාර්සලය (COD: Rs.{cod}) අද දිනයේ බෙදා හැරීමට නියමිතයි. කරුණාකර ඔබගේ Location එක එවන්න.";
    
    // {name} සහ {cod} වෙනුවට නියම දත්ත දැමීම
    String message = template.replaceAll('{name}', name).replaceAll('{cod}', codAmount);
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    
    final Uri whatsappUri = Uri.parse("https://wa.me/$cleanNumber?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp විවෘත කළ නොහැක.')));
    }
  }

  Future<void> _markAsConfirmed(int id, int currentAttempts) async {
    await DatabaseHelper.instance.updateDeliveryStatus(id, 'confirmed', currentAttempts);
    _loadMorningCalls();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('පාර්සලය Confirmed ලෙස සටහන් විය!', backgroundColor: Colors.green)));
  }

  Future<void> _markAsNoAnswer(int id, int currentAttempts) async {
    int newAttempts = currentAttempts + 1;
    if (newAttempts >= 4) {
      await DatabaseHelper.instance.updateDeliveryStatus(id, 'returned', newAttempts);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attempts 4ක් ඉක්මවූ බැවින් Returned ලිස්ට් එකට මාරු විය.', backgroundColor: Colors.red)));
    } else {
      await DatabaseHelper.instance.updateDeliveryStatus(id, 'pending', newAttempts);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No Answer: Attempt $newAttempts ලෙස සටහන් විය.', backgroundColor: Colors.orange)));
    }
    _loadMorningCalls();
  }

  Future<void> _rescheduleDelivery(int id) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null) {
      TextEditingController noteController = TextEditingController();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Note එකක් ඇතුලත් කරන්න'),
            content: TextField(controller: noteController, decoration: const InputDecoration(hintText: "උදා: හවස 2.30 ට පෙර ගෙනියන්න"), maxLines: 2),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  await DatabaseHelper.instance.rescheduleDelivery(id, pickedDate.millisecondsSinceEpoch, noteController.text);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
      _loadMorningCalls();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Morning Call List')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _runFilter(value),
              decoration: InputDecoration(
                labelText: 'Search (Name, Phone or Bill No)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _runFilter(''); })
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDeliveries.isEmpty
                    ? const Center(child: Text('ගැලපෙන පාර්සල් කිසිවක් නොමැත.', style: TextStyle(fontSize: 16)))
                    : ListView.builder(
                        itemCount: _filteredDeliveries.length,
                        itemBuilder: (context, index) {
                          final delivery = _filteredDeliveries[index];
                          final int attempts = delivery['callAttempts'] ?? 0;
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: attempts > 0 ? Colors.redAccent : Colors.transparent, width: 2),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(delivery['customerName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                                      ),
                                      if (attempts > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                                          child: Text('Attempts: $attempts', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (delivery['billNumber'] != null && delivery['billNumber'].toString().isNotEmpty)
                                    Text('Bill No: ${delivery['billNumber']}', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo)),
                                  if (delivery['itemName'] != null && delivery['itemName'].toString().isNotEmpty)
                                    Text('Item: ${delivery['itemName']}'),
                                  
                                  Text('COD: ${delivery['codAmount']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('Address: ${delivery['address']}', style: TextStyle(color: Colors.grey[800])),
                                  Text('Phone: ${delivery['phone']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                                  if (delivery['notes'] != null && delivery['notes'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text('Note: ${delivery['notes']}', style: const TextStyle(color: Colors.blue, fontStyle: FontStyle.italic)),
                                    ),

                                  const Divider(height: 24),

                                  // WhatsApp බොත්තම අලුතින් එකතු කර ඇත
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      IconButton(icon: const Icon(Icons.phone_in_talk, color: Colors.blue, size: 30), onPressed: () => _makePhoneCall(delivery['phone'])),
                                      IconButton(icon: const Icon(Icons.chat, color: Colors.green, size: 30), onPressed: () => _sendWhatsApp(delivery['phone'], delivery['customerName'], delivery['codAmount'])),
                                      IconButton(icon: const Icon(Icons.check_circle, color: Colors.teal, size: 30), onPressed: () => _markAsConfirmed(delivery['id'], attempts)),
                                      IconButton(icon: const Icon(Icons.calendar_month, color: Colors.orange, size: 30), onPressed: () => _rescheduleDelivery(delivery['id'])),
                                      IconButton(icon: const Icon(Icons.call_missed_outgoing, color: Colors.red, size: 30), onPressed: () => _markAsNoAnswer(delivery['id'], attempts)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'database_helper.dart';

class PendingCallsScreen extends StatefulWidget {
  const PendingCallsScreen({super.key});

  @override
  State<PendingCallsScreen> createState() => _PendingCallsScreenState();
}

class _PendingCallsScreenState extends State<PendingCallsScreen> {
  List<Map<String, dynamic>> _deliveries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMorningCalls();
  }

  // Database එකෙන් අද දවසට අදාළ කෝල් ලිස්ට් එක ලබා ගැනීම
  Future<void> _loadMorningCalls() async {
    final data = await DatabaseHelper.instance.getMorningCalls();
    setState(() {
      _deliveries = data;
      _isLoading = false;
    });
  }

  // 1. Dialer එක විවෘත කිරීම
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('දුරකථන ඇමතුම ලබා ගත නොහැක.')));
    }
  }

  // 2. Confirm කිරීම (මෙය එබූ විට Morning Call ලිස්ට් එකෙන් අයින් වී Map එකට යෑමට සූදානම් වේ)
  Future<void> _markAsConfirmed(int id, int currentAttempts) async {
    await DatabaseHelper.instance.updateDeliveryStatus(id, 'confirmed', currentAttempts);
    _loadMorningCalls(); // ලිස්ට් එක Refresh කිරීම
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('පාර්සලය Confirmed ලෙස සටහන් විය!', backgroundColor: Colors.green)));
  }

  // 3. No Answer (Attempts ගාණ වැඩි කිරීම)
  Future<void> _markAsNoAnswer(int id, int currentAttempts) async {
    int newAttempts = currentAttempts + 1;
    
    // දවස් 4ක් (Attempts 4ක්) ආන්සර් කළේ නැත්නම් ඉබේම Returned ලිස්ට් එකට යැවීම
    if (newAttempts >= 4) {
      await DatabaseHelper.instance.updateDeliveryStatus(id, 'returned', newAttempts);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attempts 4ක් ඉක්මවූ බැවින් Returned ලිස්ට් එකට මාරු විය.', backgroundColor: Colors.red)));
    } else {
      await DatabaseHelper.instance.updateDeliveryStatus(id, 'pending', newAttempts);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No Answer: Attempt $newAttempts ලෙස සටහන් විය.', backgroundColor: Colors.orange)));
    }
    _loadMorningCalls(); // ලිස්ට් එක Refresh කිරීම
  }

  // 4. Reschedule කිරීම (Date Picker සහ Note Box)
  Future<void> _rescheduleDelivery(int id) async {
    // දින දර්ශනය (Calendar) පෙන්වීම
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)), // හෙට දිනය මුලින් පෙන්වයි
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null) {
      // දිනය තේරුවාට පසුව Note එක ගහන්න පෙට්ටියක් (Dialog Box) පෙන්වීම
      TextEditingController noteController = TextEditingController();
      
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Note එකක් ඇතුලත් කරන්න'),
            content: TextField(
              controller: noteController,
              decoration: const InputDecoration(hintText: "උදා: හවස 2.30 ට පෙර ගෙනියන්න"),
              maxLines: 2,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  // දිනය සහ Note එක Database එකට සේව් කිරීම
                  await DatabaseHelper.instance.rescheduleDelivery(id, pickedDate.millisecondsSinceEpoch, noteController.text);
                  if (context.mounted) Navigator.pop(context); // Dialog එක වැසීම
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
      _loadMorningCalls(); // ලිස්ට් එක Refresh කිරීම
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Morning Call List')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deliveries.isEmpty
              ? const Center(child: Text('අද දිනයට ඇමතීමට පාර්සල් නොමැත.', style: TextStyle(fontSize: 16)))
              : ListView.builder(
                  itemCount: _deliveries.length,
                  itemBuilder: (context, index) {
                    final delivery = _deliveries[index];
                    final int attempts = delivery['callAttempts'] ?? 0;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        // Attempts 0 ට වඩා වැඩිනම් Card එකේ බෝඩරය රතු පාටින් පෙන්වයි
                        side: BorderSide(color: attempts > 0 ? Colors.redAccent : Colors.transparent, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // පාරිභෝගිකයාගේ නම සහ Attempts ගණන
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    delivery['customerName'], 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
                            
                            // පාර්සලයේ විස්තර (Item, COD, Address)
                            if (delivery['itemName'] != null && delivery['itemName'].toString().isNotEmpty)
                              Text('Item: ${delivery['itemName']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            
                            Text('COD: ${delivery['codAmount']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Address: ${delivery['address']}', style: TextStyle(color: Colors.grey[800])),
                            Text('Phone: ${delivery['phone']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                            
                            // කලින් Reschedule කළ එකක් නම් ඒ Note එක පෙන්වීම
                            if (delivery['notes'] != null && delivery['notes'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text('Note: ${delivery['notes']}', style: const TextStyle(color: Colors.blue, fontStyle: FontStyle.italic)),
                              ),

                            const Divider(height: 24),

                            // බයික් එකේ යන ගමන් ඔබන්න ලේසි Action Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Call Button (ලොකුවට)
                                IconButton(
                                  icon: const Icon(Icons.phone_in_talk, color: Colors.blue, size: 36),
                                  onPressed: () => _makePhoneCall(delivery['phone']),
                                ),
                                // Confirm Button
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.green, size: 36),
                                  onPressed: () => _markAsConfirmed(delivery['id'], attempts),
                                ),
                                // Reschedule Button
                                IconButton(
                                  icon: const Icon(Icons.calendar_month, color: Colors.orange, size: 36),
                                  onPressed: () => _rescheduleDelivery(delivery['id']),
                                ),
                                // No Answer Button
                                IconButton(
                                  icon: const Icon(Icons.call_missed_outgoing, color: Colors.red, size: 36),
                                  onPressed: () => _markAsNoAnswer(delivery['id'], attempts),
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

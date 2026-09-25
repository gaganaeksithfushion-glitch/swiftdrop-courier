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
  DateTimeRange? _selectedRange;
  bool _isLoading = true;

  // 🔍 Search Bar සඳහා
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final String _defaultMsg =
      "ආයුබෝවන් {name}, ඔබගේ පාර්සලය (COD: Rs.{cod}) අද දිනයේ බෙදා හැරීමට නියමිතයි. කරුණාකර ඔබගේ Location එක එවන්න.";

  @override
  void initState() {
    super.initState();
    _loadPendingCalls();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  // User Select කරපු Date Range එකට, සහ Search Query එකට අනුව List එක Filter කිරීම
  List<Map<String, dynamic>> get _filteredCalls {
    var list = pendingCalls;

    if (_selectedRange != null) {
      final startMs = DateTime(_selectedRange!.start.year, _selectedRange!.start.month, _selectedRange!.start.day)
          .millisecondsSinceEpoch;
      final endMs = DateTime(_selectedRange!.end.year, _selectedRange!.end.month, _selectedRange!.end.day, 23, 59, 59)
          .millisecondsSinceEpoch;
      list = list.where((c) {
        final ts = (c['timestamp'] ?? 0) as int;
        return ts >= startMs && ts <= endMs;
      }).toList();
    }

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) {
        final name = (c['customerName'] ?? '').toString().toLowerCase();
        final bill = (c['billNumber'] ?? '').toString().toLowerCase();
        final phone1 = (c['phone'] ?? '').toString().toLowerCase();
        final phone2 = (c['phone2'] ?? '').toString().toLowerCase();
        final address = (c['address'] ?? '').toString().toLowerCase();
        final item = (c['itemName'] ?? '').toString().toLowerCase();
        return name.contains(q) || bill.contains(q) || phone1.contains(q) || phone2.contains(q) || address.contains(q) || item.contains(q);
      }).toList();
    }

    return list;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: now.add(const Duration(days: 30)),
      initialDateRange: _selectedRange ?? DateTimeRange(start: now, end: now),
    );
    if (picked != null) {
      setState(() => _selectedRange = picked);
    }
  }

  void _clearDateRange() => setState(() => _selectedRange = null);

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

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

  // Sri Lankan local format (07XXXXXXXX) එක WhatsApp ට ඕන International format (94XXXXXXXXX) එකට convert කිරීම
  String _toWhatsAppFormat(String phone) {
    String p = phone.trim().replaceAll(' ', '').replaceAll('-', '');
    if (p.startsWith('+94')) return p.substring(1);
    if (p.startsWith('94') && p.length == 11) return p;
    if (p.startsWith('0')) return '94${p.substring(1)}';
    return p;
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
    String selectedPhone = phone1.isNotEmpty ? phone1 : phone2;
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
                    Navigator.pop(dialogContext);
                    await _updateStatus(item, 'confirmed');
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
    final formattedPhone = _toWhatsAppFormat(phone);
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

  // Call Attempt Note එකක් Add/Edit කිරීම - Card එකේ පහළින්ම පේනවා
  Future<void> _showNoteDialog(Map<String, dynamic> item) async {
    final noteController = TextEditingController(text: (item['notes'] ?? '').toString());

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Call Note එකතු කරන්න'),
          content: TextField(
            controller: noteController,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'උදා: නෑ, Phone එක Off, හෙට Call කරන්න කිව්වා...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await dbHelper.updateNote(item['id'] as int, noteController.text);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                _loadPendingCalls();
              },
              child: const Text('Save Note'),
            ),
          ],
        );
      },
    );
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

  // Call Attempts ගාණ අනුව Card එකේ Color එක තීරණය කිරීම
  // 1st attempt -> #FFFF00 (Yellow) | 2nd attempt -> #FFB343 (Orange) | 3rd+ attempt -> #ee6b6e (Red)
  Color _cardColorForAttempts(int attempts) {
    if (attempts >= 3) return const Color(0xFFee6b6e).withOpacity(0.2);
    if (attempts == 2) return const Color(0xFFFFB343).withOpacity(0.25);
    if (attempts == 1) return const Color(0xFFFFFF00).withOpacity(0.35);
    return Colors.white;
  }

  Color _attemptsTextColor(int attempts) {
    if (attempts >= 3) return const Color(0xFFc93b3e);
    if (attempts == 2) return const Color(0xFFd98214);
    if (attempts == 1) return const Color(0xFF998800);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final calls = _filteredCalls;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Calls & WhatsApp'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPendingCalls, tooltip: 'Refresh'),
        ],
      ),
      body: Column(
        children: [
          // 🔍 Search Bar (නම / Bill No / Phone / Address / Item)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search: නම, Bill No, Phone, Address...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        }),
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          // Date Range Filter (From - To)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(
                      _selectedRange == null
                          ? 'Date Range (From - To)'
                          : '${_formatDate(_selectedRange!.start)}  →  ${_formatDate(_selectedRange!.end)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                if (_selectedRange != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    onPressed: _clearDateRange,
                    tooltip: 'Clear Date Filter',
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : calls.isEmpty
                    ? const Center(child: Text('Pending calls කිසිවක් නැත.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: calls.length,
                        itemBuilder: (context, index) {
                          final call = calls[index];
                          final name = (call['customerName'] ?? '').toString();
                          final phone1 = (call['phone'] ?? '').toString();
                          final phone2 = (call['phone2'] ?? '').toString();
                          final address = (call['address'] ?? '').toString();
                          final itemName = (call['itemName'] ?? 'Parcel').toString();
                          final codAmount = (call['codAmount'] ?? '0').toString();
                          final attempts = (call['callAttempts'] ?? 0) as int;
                          final note = (call['notes'] ?? '').toString();

                          return Card(
                            color: _cardColorForAttempts(attempts),
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
                                      if (attempts > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _attemptsTextColor(attempts).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Attempts: $attempts',
                                            style: TextStyle(color: _attemptsTextColor(attempts), fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
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
                                  const SizedBox(height: 8),
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
                                      IconButton(
                                        icon: Icon(Icons.note_add_outlined, color: note.isNotEmpty ? Colors.deepPurple : Colors.grey),
                                        onPressed: () => _showNoteDialog(call),
                                        tooltip: 'Add Note',
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
                                  if (note.isNotEmpty) ...[
                                    const Divider(height: 16),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.sticky_note_2_outlined, size: 16, color: Colors.deepPurple),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            note,
                                            style: const TextStyle(fontSize: 13, color: Colors.deepPurple, fontStyle: FontStyle.italic),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'database_helper.dart';

class RouteListScreen extends StatefulWidget {
  const RouteListScreen({super.key});

  @override
  State<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends State<RouteListScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> deliveries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  // Database එකෙන් "Confirmed" (Route එකේ තියෙන) Deliveries ටික, User set කරපු පිළිවෙලට load කිරීම
  Future<void> _loadDeliveries() async {
    setState(() => _isLoading = true);
    final data = await dbHelper.getConfirmedDeliveries();
    if (!mounted) return;
    setState(() {
      deliveries = data;
      _isLoading = false;
    });
  }

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

  // Order එකේ Status එක Manual ලෙස වෙනස් කිරීම (Delivered / Returned / Pending ආදී)
  Future<void> _changeStatus(Map<String, dynamic> item, String newStatus) async {
    final id = item['id'] as int;
    final attempts = (item['callAttempts'] ?? 0) as int;
    await dbHelper.updateDeliveryStatus(id, newStatus, attempts);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status එක "$newStatus" ලෙස Update විය!'), backgroundColor: Colors.green),
    );
    _loadDeliveries();
  }

  // User Drag කරලා Route එකේ Order එක Manual ලෙස වෙනස් කිරීම
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final movedItem = deliveries.removeAt(oldIndex);
      deliveries.insert(newIndex, movedItem);
    });
    final orderedIds = deliveries.map((d) => d['id'] as int).toList();
    await dbHelper.updateRouteOrder(orderedIds);
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
                _loadDeliveries();
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  // "Auto Order by Location" - තාම හදලා නෑ, Premium feature එකක් විදිහට Tease කිරීම
  void _showAutoOrderComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚧 Auto Order by Location (GPS) මේක Premium version එකේ පමණයි Activate වෙන්නේ!'),
        backgroundColor: Colors.deepPurple,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Reschedule Dialog එක - Calendar (Date Picker) + Note Box එකක් සමග
  Future<void> _showRescheduleDialog(Map<String, dynamic> item) async {
    DateTime? selectedDate;
    final noteController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Reschedule Order'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${item['customerName'] ?? ''}  •  Bill: ${item['billNumber'] ?? '-'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 60)),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        selectedDate == null
                            ? 'Select Reschedule Date'
                            : 'Date: ${selectedDate.toString().split(' ')[0]}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Reschedule Note',
                        hintText: 'උදා: Customer නෑ, හෙට උදේ එවන්න කිව්වා',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
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
                    if (selectedDate == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('කරුණාකර දිනයක් Select කරන්න!'), backgroundColor: Colors.orange),
                      );
                      return;
                    }
                    await dbHelper.rescheduleDelivery(
                      item['id'] as int,
                      selectedDate!.millisecondsSinceEpoch,
                      noteController.text,
                    );
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rescheduled successfully!'), backgroundColor: Colors.green),
                    );
                    _loadDeliveries();
                  },
                  child: const Text('Save Reschedule'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Map & Deliveries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _showAutoOrderComingSoon,
            tooltip: 'Auto Order by Location',
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDeliveries, tooltip: 'Refresh'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : deliveries.isEmpty
              ? const Center(child: Text('අදට නියමිත බෙදාහැරීම් කිසිවක් නැත.'))
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.deepPurple.withOpacity(0.06),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: const Row(
                        children: [
                          Icon(Icons.drag_indicator, size: 16, color: Colors.grey),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Order එක වෙනස් කරන්න, පහළ ඉන්න drag handle එක අල්ලාගෙන Card එක ඉහළට/පහළට ඇද ගන්න.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.all(16.0),
                        itemCount: deliveries.length,
                        onReorder: _onReorder,
                        itemBuilder: (context, index) {
                          final item = deliveries[index];
                          final billNo = (item['billNumber'] ?? '').toString();
                          final itemName = (item['itemName'] ?? 'Parcel').toString();
                          final codAmount = (item['codAmount'] ?? '0').toString();
                          final address = (item['address'] ?? '').toString();
                          final phone = (item['phone'] ?? '').toString();
                          final phone2 = (item['phone2'] ?? '').toString();
                          final customerName = (item['customerName'] ?? '').toString();
                          final id = item['id'] as int;

                          return Card(
                            key: ValueKey(id),
                            margin: const EdgeInsets.only(bottom: 12.0),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Drag Handle - මේකෙන් අල්ලාගෙනයි Card එක ඇදගෙන යන්නේ
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(Icons.drag_handle, color: Colors.grey),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        width: 26,
                                        height: 26,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple, fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          customerName,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert),
                                        tooltip: 'Change Status',
                                        onSelected: (value) => _changeStatus(item, value),
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(value: 'pending', child: Text('Mark as Pending')),
                                          PopupMenuItem(value: 'confirmed', child: Text('Mark as Confirmed')),
                                          PopupMenuItem(value: 'delivered', child: Text('Mark as Delivered')),
                                          PopupMenuItem(value: 'returned', child: Text('Mark as Returned')),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (billNo.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 40),
                                      child: Text('Bill No: $billNo', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 40),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            Expanded(child: Text('Item: $itemName')),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.payments_outlined, size: 16, color: Colors.green),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Price (COD): Rs. $codAmount',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(address),
                                        const SizedBox(height: 6),
                                        // Phone number(s) - Tap කරලාම call කරන්න පුළුවන් (dialer)
                                        if (phone.isNotEmpty)
                                          InkWell(
                                            onTap: () => _makePhoneCall(phone),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.phone, size: 15, color: Colors.blue),
                                                const SizedBox(width: 6),
                                                Text('Phone: $phone', style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                                              ],
                                            ),
                                          ),
                                        if (phone2.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: InkWell(
                                              onTap: () => _makePhoneCall(phone2),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.phone, size: 15, color: Colors.blue),
                                                  const SizedBox(width: 6),
                                                  Text('Phone 2: $phone2', style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.navigation, color: Colors.blue),
                                        onPressed: () => _openMap(address),
                                        tooltip: 'Navigate',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.event_repeat, color: Colors.orange),
                                        onPressed: () => _showRescheduleDialog(item),
                                        tooltip: 'Reschedule',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.grey),
                                        onPressed: () => _showEditDialog(item),
                                        tooltip: 'Edit Details',
                                      ),
                                      const Spacer(),
                                      ElevatedButton(
                                        onPressed: () => _changeStatus(item, 'delivered'),
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
                    ),
                  ],
                ),
    );
  }
}

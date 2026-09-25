import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'smart_scanner_screen.dart';
import 'google_places_service.dart';

class RouteListScreen extends StatefulWidget {
  const RouteListScreen({super.key});

  @override
  State<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends State<RouteListScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> deliveries = [];
  DateTimeRange? _selectedRange;
  bool _isLoading = true;
  bool _isOptimizing = false;

  // 🔍 Search Bar සඳහා
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Call Center එකට යවන "No Answer" පණිවිඩයේ Default Template එක
  final String _defaultNoAnswerMsg =
      "Bill No: {bill}\nName: {name}\nItem: {item}\nPhone: {phone}\nnot responding at location.";

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  // User Select කරපු Date Range එකට, සහ Search Query එකට අනුව List එක Filter කිරීම
  List<Map<String, dynamic>> get _filteredDeliveries {
    var list = deliveries;

    if (_selectedRange != null) {
      final startMs = DateTime(_selectedRange!.start.year, _selectedRange!.start.month, _selectedRange!.start.day)
          .millisecondsSinceEpoch;
      final endMs = DateTime(_selectedRange!.end.year, _selectedRange!.end.month, _selectedRange!.end.day, 23, 59, 59)
          .millisecondsSinceEpoch;
      list = list.where((d) {
        final ts = (d['timestamp'] ?? 0) as int;
        return ts >= startMs && ts <= endMs;
      }).toList();
    }

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((d) {
        final name = (d['customerName'] ?? '').toString().toLowerCase();
        final bill = (d['billNumber'] ?? '').toString().toLowerCase();
        final phone1 = (d['phone'] ?? '').toString().toLowerCase();
        final phone2 = (d['phone2'] ?? '').toString().toLowerCase();
        final address = (d['address'] ?? '').toString().toLowerCase();
        final item = (d['itemName'] ?? '').toString().toLowerCase();
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

  Future<void> _openMap(String address) async {
    final query = Uri.encodeComponent(address);
    final Uri mapUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(mapUri)) {
      await launchUrl(mapUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  // Sri Lankan local format (07XXXXXXXX) එක WhatsApp ට ඕන International format (94XXXXXXXXX) එකට convert කිරීම
  String _toWhatsAppFormat(String phone) {
    String p = phone.trim().replaceAll(' ', '').replaceAll('-', '');
    if (p.startsWith('+94')) return p.substring(1);
    if (p.startsWith('94') && p.length == 11) return p;
    if (p.startsWith('0')) return '94${p.substring(1)}';
    return p;
  }

  // Call Center එකට "No Answer" WhatsApp Message එකක් යැවීම (Bill No, Name, Item, Phone සමග)
  Future<void> _notifyCallCenterNoAnswer(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final callCenterNumber = (prefs.getString('call_center_whatsapp') ?? '').trim();

    if (callCenterNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call Center WhatsApp Number එක Settings එකේ දාලා නෑ! කරුණාකර Settings > Call Center Number එකතු කරන්න.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    String template = prefs.getString('route_no_answer_template') ?? _defaultNoAnswerMsg;
    final bill = (item['billNumber'] ?? '-').toString();
    final name = (item['customerName'] ?? '-').toString();
    final itemName = (item['itemName'] ?? '-').toString();
    final phone1 = (item['phone'] ?? '').toString();
    final phone2 = (item['phone2'] ?? '').toString();
    final phone = phone1.isNotEmpty ? phone1 : phone2;

    template = template
        .replaceAll('{bill}', bill)
        .replaceAll('{name}', name)
        .replaceAll('{item}', itemName)
        .replaceAll('{phone}', phone.isEmpty ? '-' : phone);

    final formattedPhone = _toWhatsAppFormat(callCenterNumber);
    final encodedMessage = Uri.encodeComponent(template);
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
  }

  // "No Answer" Button එක Click කරාම: Status එක Pending කරලා (Attempt +1), Call Center එකටත් Notify කරනවා
  Future<void> _handleNoAnswer(Map<String, dynamic> item) async {
    final id = item['id'] as int;
    final attempts = (item['callAttempts'] ?? 0) as int;
    await dbHelper.updateDeliveryStatus(id, 'pending', attempts + 1);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Answer ලෙස සටහන් විය, Pending එකට මාරු විය!'), backgroundColor: Colors.orange),
      );
    }
    await _notifyCallCenterNoAnswer(item);
    _loadDeliveries();
  }

  Future<void> _editDelivery(Map<String, dynamic> item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SmartScannerScreen(deliveryToEdit: item)),
    );
    if (result == true) _loadDeliveries();
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

  // Order එකේ Status එක Manual ලෙස වෙනස් කිරීම (Delivered / Returned / Cancelled / Pending ආදී)
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
  // Date Filter එකක් Active නම්, Filtered List එකේ පෙන්නන Items ටිකේම Order එක වෙනස් කරලා,
  // ඉතුරු (Filter වුනු) Items ටික ඒ විදිහටම තියාගෙන, සම්පූර්ණ List එක නැවත සකස් කරනවා
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final visibleList = _filteredDeliveries;
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final movedItem = visibleList.removeAt(oldIndex);
      visibleList.insert(newIndex, movedItem);

      if (_selectedRange == null) {
        deliveries = visibleList;
      } else {
        final visibleIds = visibleList.map((d) => d['id']).toSet();
        final merged = <Map<String, dynamic>>[];
        int visibleIndex = 0;
        for (final d in deliveries) {
          if (visibleIds.contains(d['id'])) {
            merged.add(visibleList[visibleIndex]);
            visibleIndex++;
          } else {
            merged.add(d);
          }
        }
        deliveries = merged;
      }
    });
    final orderedIds = deliveries.map((d) => d['id'] as int).toList();
    await dbHelper.updateRouteOrder(orderedIds);
  }

  Future<Position?> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS එක Off වෙලා තියෙන්නේ, කරුණාකර On කරන්න!'), backgroundColor: Colors.orange),
        );
      }
      return null;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // Real "Auto Order by Location" - Google Directions API එකෙන් Best Route එක Calculate කිරීම
  Future<void> _autoOrderByLocation() async {
    if (!GooglePlacesService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google API Key එක Configure වෙලා නෑ. Build කරද්දි --dart-define=GOOGLE_API_KEY එකතු කරන්න.'),
          backgroundColor: Colors.deepPurple,
        ),
      );
      return;
    }

    final visibleList = _filteredDeliveries;
    final withLocation = visibleList.where((d) => d['lat'] != null && d['lng'] != null).toList();
    final withoutLocation = visibleList.where((d) => d['lat'] == null || d['lng'] == null).toList();

    if (withLocation.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('අඩුම තරමින් Location Saved Delivery 2ක්වත් ඕන. Address Autocomplete එකෙන් Address එක Select කරලා Save කරන්න.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isOptimizing = true);

    final position = await _getCurrentPosition();
    if (position == null) {
      setState(() => _isOptimizing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current Location එක ලබාගන්න බැරි උනා. Permission එක Check කරන්න.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final origin = LatLngResult(position.latitude, position.longitude);
    final waypoints = withLocation.map((d) => LatLngResult((d['lat'] as num).toDouble(), (d['lng'] as num).toDouble())).toList();

    final optimizedOrder = await GooglePlacesService.optimizeRoute(origin: origin, waypoints: waypoints);

    setState(() => _isOptimizing = false);

    if (optimizedOrder == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route Optimize කරන්න බැරි උනා. API Key එකේ Directions API Enable කරලා තියෙනවද බලන්න.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Optimized Order එක අනුව Visible List එක නැවත සකස් කිරීම, Location නැති ඒවා අන්තිමට එකතු කිරීම
    final reorderedVisible = optimizedOrder.map((i) => withLocation[i]).toList();
    reorderedVisible.addAll(withoutLocation);

    setState(() {
      if (_selectedRange == null) {
        deliveries = reorderedVisible;
      } else {
        final orderedVisibleByOriginal = _filteredDeliveries;
        final visibleIds = orderedVisibleByOriginal.map((d) => d['id']).toSet();
        final merged = <Map<String, dynamic>>[];
        int visibleIndex = 0;
        for (final d in deliveries) {
          if (visibleIds.contains(d['id'])) {
            merged.add(reorderedVisible[visibleIndex]);
            visibleIndex++;
          } else {
            merged.add(d);
          }
        }
        deliveries = merged;
      }
    });
    final orderedIds = deliveries.map((d) => d['id'] as int).toList();
    await dbHelper.updateRouteOrder(orderedIds);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Route එක GPS Location එක අනුව Auto-Arrange කළා!'), backgroundColor: Colors.green),
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
            Icon(Icons.call, size: 15, color: color),
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
    final visibleDeliveries = _filteredDeliveries;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Map & Deliveries'),
        actions: [
          IconButton(
            icon: _isOptimizing
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome),
            onPressed: _isOptimizing ? null : _autoOrderByLocation,
            tooltip: 'Auto Order by Location',
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDeliveries, tooltip: 'Refresh'),
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
                : visibleDeliveries.isEmpty
                    ? const Center(child: Text('මේ Date Range එකට බෙදාහැරීම් කිසිවක් නැත.'))
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
                                    'Order වෙනස් කරන්න - handle එක (☰) ටිකක් Hold කරලා ඇද ගන්න, හෝ ✨ Auto Order Button එක try කරන්න.',
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
                              itemCount: visibleDeliveries.length,
                              onReorder: _onReorder,
                              itemBuilder: (context, index) {
                                final item = visibleDeliveries[index];
                                final billNo = (item['billNumber'] ?? '').toString();
                                final itemName = (item['itemName'] ?? 'Parcel').toString();
                                final codAmount = (item['codAmount'] ?? '0').toString();
                                final address = (item['address'] ?? '').toString();
                                final phone1 = (item['phone'] ?? '').toString();
                                final phone2 = (item['phone2'] ?? '').toString();
                                final customerName = (item['customerName'] ?? '').toString();
                                final id = item['id'] as int;
                                final hasLocation = item['lat'] != null && item['lng'] != null;
                                final attempts = (item['callAttempts'] ?? 0) as int;

                                return Card(
                                  key: ValueKey(id),
                                  color: _cardColorForAttempts(attempts),
                                  margin: const EdgeInsets.only(bottom: 12.0),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            ReorderableDelayedDragStartListener(
                                              index: index,
                                              child: Container(
                                                width: 40,
                                                height: 40,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(Icons.drag_handle, color: Colors.grey),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
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
                                              child: Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      customerName,
                                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (hasLocation) const Padding(
                                                    padding: EdgeInsets.only(left: 4),
                                                    child: Icon(Icons.gps_fixed, size: 13, color: Colors.green),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (attempts > 0)
                                              Container(
                                                margin: const EdgeInsets.only(right: 4),
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
                                              onPressed: () => _editDelivery(item),
                                              tooltip: 'Edit',
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
                                                PopupMenuItem(value: 'cancelled', child: Text('Mark as Cancelled')),
                                              ],
                                            ),
                                          ],
                                        ),
                                        if (billNo.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 46),
                                            child: Text('Bill No: $billNo', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Padding(
                                          padding: const EdgeInsets.only(left: 46),
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
                                              _phoneRow(phone1, color: Colors.blue),
                                              _phoneRow(phone2, color: Colors.indigo),
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
                                            const Spacer(),
                                            TextButton(
                                              onPressed: () => _handleNoAnswer(item),
                                              child: const Text('No Answer'),
                                            ),
                                            const SizedBox(width: 4),
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
          ),
        ],
      ),
    );
  }
}

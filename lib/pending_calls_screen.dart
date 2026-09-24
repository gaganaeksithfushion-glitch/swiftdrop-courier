import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'database_helper.dart';
import 'smart_scanner_screen.dart';

class EndOfDayReportScreen extends StatefulWidget {
  const EndOfDayReportScreen({super.key});

  @override
  State<EndOfDayReportScreen> createState() => _EndOfDayReportScreenState();
}

class _EndOfDayReportScreenState extends State<EndOfDayReportScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

  List<Map<String, dynamic>> _allDeliveries = [];
  final Set<int> _selectedIds = {};
  String _selectedFilter = 'All';
  DateTimeRange? _selectedRange;
  bool _isLoading = true;

  // 🔍 Search Bar සඳහා
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _filters = ['All', 'Pending', 'Confirmed', 'Delivered', 'Returned', 'Cancelled', 'Rescheduled'];

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

  Future<void> _loadDeliveries() async {
    setState(() => _isLoading = true);
    final data = await dbHelper.getAllDeliveries();
    setState(() {
      _allDeliveries = data;
      _isLoading = false;
    });
  }

  Future<void> _editDelivery(Map<String, dynamic> item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SmartScannerScreen(deliveryToEdit: item)),
    );
    if (result == true) _loadDeliveries();
  }

  // Mistake එකකින් Status එක වැරදුනොත් (උදා: Pending එකක් වැරදීමකින් Delivered කරාට පස්සේ),
  // මෙතනින් ආපහු නිවැරදි Status එකට Change කරන්න පුළුවන්
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

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _selectedRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
    );
    if (picked != null) {
      setState(() => _selectedRange = picked);
    }
  }

  void _clearDateRange() {
    setState(() => _selectedRange = null);
  }

  List<Map<String, dynamic>> get _filteredDeliveries {
    var list = _allDeliveries;

    if (_selectedFilter != 'All') {
      list = list.where((d) {
        final status = (d['status'] ?? 'pending').toString().toLowerCase();
        return status == _selectedFilter.toLowerCase();
      }).toList();
    }

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

  void _toggleSelectAll(bool selectAll) {
    setState(() {
      if (selectAll) {
        _selectedIds.addAll(_filteredDeliveries.map((d) => d['id'] as int));
      } else {
        for (final d in _filteredDeliveries) {
          _selectedIds.remove(d['id']);
        }
      }
    });
  }

  bool get _allFilteredSelected =>
      _filteredDeliveries.isNotEmpty && _filteredDeliveries.every((d) => _selectedIds.contains(d['id']));

  Future<void> _generatePdf() async {
    final selectedItems = _allDeliveries.where((d) => _selectedIds.contains(d['id'])).toList();

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('කරුණාකර අවම වශයෙන් bill එකක්වත් Select කරන්න!'), backgroundColor: Colors.orange),
      );
      return;
    }

    final pdf = pw.Document();

    double totalCod = 0;
    for (final item in selectedItems) {
      final codStr = (item['codAmount'] ?? '0').toString().replaceAll(RegExp(r'[^0-9.]'), '');
      totalCod += double.tryParse(codStr) ?? 0;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ShiftDrop Report ($_selectedFilter)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date: ${DateTime.now().toLocal().toString().split(' ')[0]}', style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Selected Bills: ${selectedItems.length}   |   Total COD: Rs. ${totalCod.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: ['Bill No', 'Name', 'Phone', 'Address', 'Item', 'COD', 'Status'],
              data: selectedItems.map((d) => [
                (d['billNumber'] ?? '').toString(),
                (d['customerName'] ?? '').toString(),
                (d['phone'] ?? '').toString(),
                (d['address'] ?? '').toString(),
                (d['itemName'] ?? '').toString(),
                (d['codAmount'] ?? '').toString(),
                (d['status'] ?? 'pending').toString().toUpperCase(),
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.deepPurple),
              cellHeight: 24,
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDeliveries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Bill Selection'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDeliveries, tooltip: 'Refresh'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                // Filter chips (Status)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((filter) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: _selectedFilter == filter,
                            onSelected: (selected) {
                              setState(() => _selectedFilter = filter);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Date Range Filter (From - To)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
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

                // Select all row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _allFilteredSelected,
                        onChanged: (v) => _toggleSelectAll(v ?? false),
                      ),
                      Text('Select All ($_selectedFilter — ${filtered.length})'),
                      const Spacer(),
                      Text('${_selectedIds.length} selected', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                const Divider(),

                // Bill list
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('මේ filter එකට bills කිසිවක් නැත.'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final d = filtered[index];
                            final id = d['id'] as int;
                            final isSelected = _selectedIds.contains(id);
                            final phone2 = (d['phone2'] ?? '').toString();
                            return ListTile(
                              leading: Checkbox(
                                value: isSelected,
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedIds.add(id);
                                    } else {
                                      _selectedIds.remove(id);
                                    }
                                  });
                                },
                              ),
                              title: Text('${d['customerName'] ?? ''}  •  Bill: ${d['billNumber'] ?? '-'}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${d['address'] ?? ''}\nPhone: ${d['phone'] ?? ''}${phone2.isNotEmpty ? ', $phone2' : ''}  •  COD: Rs. ${d['codAmount'] ?? '0'}',
                              ),
                              isThreeLine: true,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _statusBadge((d['status'] ?? 'pending').toString()),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Status එක Manual ලෙස Revert/Change කරන්න - Mistake එකක් නම් මෙතනින් Fix කරගන්න
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.sync_alt, size: 18, color: Colors.grey),
                                        tooltip: 'Change Status',
                                        padding: EdgeInsets.zero,
                                        onSelected: (v) => _changeStatus(d, v),
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(value: 'pending', child: Text('Mark as Pending')),
                                          PopupMenuItem(value: 'confirmed', child: Text('Mark as Confirmed')),
                                          PopupMenuItem(value: 'delivered', child: Text('Mark as Delivered')),
                                          PopupMenuItem(value: 'returned', child: Text('Mark as Returned')),
                                          PopupMenuItem(value: 'cancelled', child: Text('Mark as Cancelled')),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _editDelivery(d),
                                        tooltip: 'Edit',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Generate PDF button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _selectedIds.isEmpty ? null : _generatePdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text('Generate PDF (${_selectedIds.length} selected)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'delivered':
        color = Colors.green;
        break;
      case 'returned':
        color = Colors.red;
        break;
      case 'cancelled':
        color = Colors.black54;
        break;
      case 'confirmed':
        color = Colors.blue;
        break;
      case 'rescheduled':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

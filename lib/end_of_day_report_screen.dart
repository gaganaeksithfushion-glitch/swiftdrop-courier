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
  bool _isLoading = true;

  final List<String> _filters = ['All', 'Pending', 'Confirmed', 'Delivered', 'Returned', 'Rescheduled'];

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
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

  List<Map<String, dynamic>> get _filteredDeliveries {
    if (_selectedFilter == 'All') return _allDeliveries;
    return _allDeliveries.where((d) {
      final status = (d['status'] ?? 'pending').toString().toLowerCase();
      return status == _selectedFilter.toLowerCase();
    }).toList();
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
                // Filter chips
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
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _editDelivery(d),
                                    tooltip: 'Edit',
                                  ),
                                ],
                              ),
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedIds.remove(id);
                                  } else {
                                    _selectedIds.add(id);
                                  }
                                });
                              },
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

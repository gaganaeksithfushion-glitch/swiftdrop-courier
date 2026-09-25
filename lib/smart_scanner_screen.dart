import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'database_helper.dart';
import 'google_places_service.dart';

class SmartScannerScreen extends StatefulWidget {
  // Edit කරන්න ආපු Delivery record එක (null නම් අලුත් Entry එකක්)
  final Map<String, dynamic>? deliveryToEdit;

  const SmartScannerScreen({super.key, this.deliveryToEdit});

  @override
  State<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends State<SmartScannerScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _billNoController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _phone2Controller = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _codController = TextEditingController();

  bool get _isEditMode => widget.deliveryToEdit != null;

  // Address Autocomplete සඳහා
  List<PlaceSuggestion> _suggestions = [];
  Timer? _debounce;
  double? _lat;
  double? _lng;
  bool _isSearchingAddress = false;
  bool _isSaving = false;
  bool _isParsingPdf = false;

  @override
  void initState() {
    super.initState();
    // Edit Mode නම්, දැනටම තියෙන Data වලින් Fields පුරවනවා
    if (_isEditMode) {
      final d = widget.deliveryToEdit!;
      _nameController.text = (d['customerName'] ?? '').toString();
      _billNoController.text = (d['billNumber'] ?? '').toString();
      _phoneController.text = (d['phone'] ?? '').toString();
      _phone2Controller.text = (d['phone2'] ?? '').toString();
      _addressController.text = (d['address'] ?? '').toString();
      _itemController.text = (d['itemName'] ?? '').toString();
      _codController.text = (d['codAmount'] ?? '').toString();
      _lat = (d['lat'] as num?)?.toDouble();
      _lng = (d['lng'] as num?)?.toDouble();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _billNoController.dispose();
    _phoneController.dispose();
    _phone2Controller.dispose();
    _addressController.dispose();
    _itemController.dispose();
    _codController.dispose();
    super.dispose();
  }

  // Report PDF එකේ, App එකට තේරෙන Exact Format එකෙන් හිස් Sample එකක් Download කර ගැනීම
  // (PDF Upload කරද්දි, මේ Format එකෙන්ම විස්තර දැම්මොත් විතරයි App එකට ඒවා කියවගන්න පුළුවන්)
  Future<void> _downloadSamplePdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('ShiftDrop Report (Sample)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(
                'Note: Meka Sample Format ekak. Mema pela pihitiwa vidiyatama, "Bill No | Name | Phone | Address | Item | COD | Status" krama anuwa obage data pela danna.',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Bill No | Name | Phone | Address | Item | COD | Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.Text('18314872 | AMAL SARANGA | 0771678423 | 283/1/2 BALUMMAHARA GAMPAHA | SHOE 2 PACK | 2590 | PENDING'),
              pw.SizedBox(height: 4),
              pw.Text('18314873 | NIMAL PERERA | 0776543210 | 45 GALLE ROAD COLOMBO | BAG 1 PACK | 1500 | PENDING'),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // PDF එකක් Upload කරලා, ඒකේ Text Content එක Extract කරලා, Sample Format එකට ගැලපෙන
  // Parcel පේළි (Rows) විස්තර, Form Fields වලට ස්වයංක්‍රීයව පුරවා ගැනීම
  Future<void> _uploadAndParsePdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;

      setState(() => _isParsingPdf = true);

      final bytes = result.files.single.bytes!;
      final document = syncfusion.PdfDocument(inputBytes: bytes);
      final fullText = syncfusion.PdfTextExtractor(document).extractText();
      document.dispose();

      final rows = _parseReportRows(fullText);

      if (!mounted) return;
      setState(() => _isParsingPdf = false);

      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'PDF එකේ Sample Format එකට ගැලපෙන Data හමු නොවුණි. "Sample PDF" බාගෙන, එම Format එකම (Bill No | Name | Phone | Address | Item | COD | Status) පාවිච්චි කරන්න.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      Map<String, String> chosen;
      if (rows.length == 1) {
        chosen = rows.first;
      } else {
        final picked = await _showRowPickerDialog(rows);
        if (picked == null) return; // User Cancel කළා
        chosen = picked;
      }

      setState(() {
        _billNoController.text = chosen['billNo'] ?? '';
        _nameController.text = chosen['name'] ?? '';
        _phoneController.text = chosen['phone'] ?? '';
        _addressController.text = chosen['address'] ?? '';
        _itemController.text = chosen['item'] ?? '';
        _codController.text = chosen['cod'] ?? '';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF එකෙන් විස්තර සාර්ථකව Load කර ගන්නා ලදි!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isParsingPdf = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF Parse කිරීමේ දෝෂයක්: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // "Bill No | Name | Phone | Address | Item | COD | Status" Format එකට ගැලපෙන
  // Data Rows විතරක් Text එකෙන් උකහාගැනීම (Title, Header, Divider ආදිය Skip කරලා)
  List<Map<String, String>> _parseReportRows(String text) {
    final rows = <Map<String, String>>[];
    final lines = text.split(RegExp(r'[\r\n]+'));
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (!line.contains('|')) continue;

      final parts = line.split('|').map((p) => p.trim()).toList();
      if (parts.length < 6) continue;

      final billNo = parts[0];
      if (billNo.isEmpty) continue;
      if (billNo.toLowerCase() == 'bill no') continue; // Header row
      if (RegExp(r'^-+$').hasMatch(billNo)) continue; // Divider line

      rows.add({
        'billNo': billNo,
        'name': parts.length > 1 ? parts[1] : '',
        'phone': parts.length > 2 ? parts[2] : '',
        'address': parts.length > 3 ? parts[3] : '',
        'item': parts.length > 4 ? parts[4] : '',
        'cod': parts.length > 5 ? parts[5].replaceAll(RegExp(r'[^0-9.]'), '') : '',
      });
    }
    return rows;
  }

  // PDF එකේ Parcel එකකට වඩා තියෙනවා නම්, එකක් තෝරගන්න Dialog එකක්
  Future<Map<String, String>?> _showRowPickerDialog(List<Map<String, String>> rows) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import කරන්න Parcel එක තෝරන්න'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = rows[i];
              return ListTile(
                leading: const Icon(Icons.description_outlined, color: Colors.indigo),
                title: Text(r['name'] ?? ''),
                subtitle: Text('Bill: ${r['billNo']}  •  ${r['phone']}'),
                onTap: () => Navigator.pop(dialogContext, r),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        ],
      ),
    );
  }

  // Address Field එකේ Type කරන විට, 400ms Debounce එකකින් Google Places Search එක Call කිරීම
  void _onAddressChanged(String value) {
    // User ආයෙත් Type කරන්න පටන්ගත්තොත් කලින් තෝරපු Location එක Invalid වෙනවා
    if (_lat != null || _lng != null) {
      setState(() {
        _lat = null;
        _lng = null;
      });
    }

    if (!GooglePlacesService.isConfigured) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (value.trim().length < 3) {
        setState(() => _suggestions = []);
        return;
      }
      setState(() => _isSearchingAddress = true);
      final results = await GooglePlacesService.autocomplete(value);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearchingAddress = false;
      });
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    setState(() {
      _addressController.text = suggestion.description;
      _suggestions = [];
      _isSearchingAddress = true;
    });
    final latLng = await GooglePlacesService.getPlaceLatLng(suggestion.placeId);
    if (!mounted) return;
    setState(() {
      _lat = latLng?.lat;
      _lng = latLng?.lng;
      _isSearchingAddress = false;
    });
  }

  // Bill No එක දැනටමත් Database එකේ තියෙනවා නම්, Save කරන්නද කියලා Confirm කරගැනීම
  Future<bool> _confirmDuplicateBillNumber(String billNo) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('⚠️ Duplicate Bill No'),
        content: Text('Bill No "$billNo" කියන එක දැනටමත් Database එකේ තියෙනවා.\n\nඑම Bill No එකම ආයෙත් Save කරන්නද?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes, Save Anyway'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _saveToDatabase() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('නම සහ දුරකථන අංකය අවශ්‍යයි!'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    final billNo = _billNoController.text.trim();
    if (billNo.isNotEmpty) {
      final excludeId = _isEditMode ? widget.deliveryToEdit!['id'] as int : null;
      final exists = await DatabaseHelper.instance.billNumberExists(billNo, excludeId: excludeId);
      if (exists) {
        setState(() => _isSaving = false);
        final proceed = await _confirmDuplicateBillNumber(billNo);
        if (!proceed) return; // User Cancel කළා - Save කරන්නේ නෑ
        setState(() => _isSaving = true);
      }
    }

    final Map<String, dynamic> data = {
      'billNumber': billNo,
      'itemName': _itemController.text.isEmpty ? 'Parcel' : _itemController.text,
      'customerName': _nameController.text,
      'address': _addressController.text,
      'phone': _phoneController.text,
      'phone2': _phone2Controller.text,
      'codAmount': _codController.text.isEmpty ? '0' : _codController.text,
      'lat': _lat,
      'lng': _lng,
    };

    if (_isEditMode) {
      // දැනටම තියෙන Record එකක් Update කිරීම
      await DatabaseHelper.instance.updateDelivery(widget.deliveryToEdit!['id'] as int, data);
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('සාර්ථකව Update විය!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true); // reload signal එකක් parent screen එකට
      return;
    }

    // අලුත් Record එකක් Insert කිරීම
    data['notes'] = '';
    await DatabaseHelper.instance.insertDelivery(data);

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('සාර්ථකව Database එකට Save විය!'), backgroundColor: Colors.green),
    );

    setState(() {
      _nameController.clear();
      _billNoController.clear();
      _phoneController.clear();
      _phone2Controller.clear();
      _addressController.clear();
      _itemController.clear();
      _codController.clear();
      _lat = null;
      _lng = null;
      _suggestions = [];
    });
  }

  void _showComingSoonMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚧 This feature activates in the premium version!'),
        backgroundColor: Colors.deepPurple,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditMode ? 'Edit Parcel' : 'Manual Entry / PDF Upload')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isEditMode) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      onPressed: _isParsingPdf ? null : _uploadAndParsePdf,
                      icon: _isParsingPdf
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: const Text('Upload PDF Report'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _downloadSamplePdf,
                    icon: const Icon(Icons.download),
                    label: const Text('Sample PDF'),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'PDF එකෙන් Upload කරන්න කලින්, "Sample PDF" බාගෙන එහි තියෙන Format එකම (Bill No | Name | Phone | Address | Item | COD | Status) ඔබේ Report එකේත් තියෙනවාද බලන්න.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              _isEditMode ? 'Parcel විස්තර Edit කරන්න:' : 'Parcel විස්තර අතින් ඇතුළත් කරන්න:',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'පාරිභෝගිකයාගේ නම (Name)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _billNoController,
              decoration: const InputDecoration(labelText: 'Bill No', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'දුරකථන අංකය 1 (Phone)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone2Controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'දුරකථන අංකය 2 (Optional)',
                hintText: 'තව අංකයක් තිබ්බොත් විතරක්',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            // Address Field + Autocomplete Suggestions
            TextField(
              controller: _addressController,
              onChanged: _onAddressChanged,
              decoration: InputDecoration(
                labelText: 'ලිපිනය (Address)',
                border: const OutlineInputBorder(),
                suffixIcon: _isSearchingAddress
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : (_lat != null && _lng != null)
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
              ),
            ),
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = _suggestions[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on_outlined, color: Colors.deepPurple),
                      title: Text(s.description, style: const TextStyle(fontSize: 13)),
                      onTap: () => _selectSuggestion(s),
                    );
                  },
                ),
              ),
            if (GooglePlacesService.isConfigured && _lat != null && _lng != null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('📍 Location Saved — Auto Route Order එකට Ready', style: TextStyle(fontSize: 11, color: Colors.green)),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _itemController,
              decoration: const InputDecoration(labelText: 'භාණ්ඩයේ නම (Item)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _codController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'COD මුදල (Rs.)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEditMode ? Colors.deepPurple : Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSaving ? null : _saveToDatabase,
              icon: _isSaving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_isEditMode ? Icons.check_circle : Icons.save),
              label: Text(
                _isEditMode ? 'Update Details' : 'Save to Database',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            // Smart AI Scan button එකට ඉඩ ඉතුරු කරන්න
            const SizedBox(height: 80),
          ],
        ),
      ),
      // Edit Mode එකේදී Smart Scan Button එක Hide කරනවා (අලුතින් Entry කරද්දි විතරයි ඕන)
      floatingActionButton: _isEditMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _showComingSoonMessage,
              backgroundColor: Colors.deepPurple,
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
              label: const Text('Smart Scan', style: TextStyle(color: Colors.white)),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

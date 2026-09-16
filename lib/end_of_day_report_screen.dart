import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'database_helper.dart';

class EndOfDayReportScreen extends StatefulWidget {
  const EndOfDayReportScreen({super.key});

  @override
  State<EndOfDayReportScreen> createState() => _EndOfDayReportScreenState();
}

class _EndOfDayReportScreenState extends State<EndOfDayReportScreen> {
  Map<String, dynamic>? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final data = await DatabaseHelper.instance.getDailyReportSummary();
    setState(() {
      _summary = data;
      _isLoading = false;
    });
  }

  // PDF එක නිර්මාණය කර Share කිරීම
  Future<void> _generateAndSharePDF() async {
    if (_summary == null) return;
    
    final pdf = pw.Document();
    final deliveredList = _summary!['deliveredList'] as List;
    final returnedList = _summary!['returnedList'] as List;
    final totalCod = _summary!['totalCod'];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, child: pw.Text('End of Day Courier Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
            pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 20),
            
            // සාරාංශය (Summary)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Total Delivered: ${_summary!['deliveredCount']}'),
                  pw.Text('Total Returned: ${_summary!['returnedCount']}'),
                  pw.Text('Pending/Rescheduled: ${_summary!['pendingCount']}'),
                  pw.SizedBox(height: 10),
                  pw.Text('TOTAL CASH (COD): Rs. $totalCod', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                ]
              )
            ),
            pw.SizedBox(height: 20),

            // Delivered ලිස්ට් එක පෙන්වීම
            pw.Text('Delivered Parcels', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            ...deliveredList.map((item) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text('${item['billNumber']} | ${item['customerName']} | COD: Rs. ${item['codAmount']}'),
            )),
            
            pw.SizedBox(height: 20),

            // Returned ලිස්ට් එක පෙන්වීම
            pw.Text('Returned Parcels', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            ...returnedList.map((item) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text('${item['billNumber']} | ${item['customerName']} | Note: ${item['notes']}'),
            )),
          ];
        },
      ),
    );

    // PDF එක WhatsApp / Email හරහා Share කිරීම
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'EOD_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _summary == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('End of Day Report')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ලොකු Cash Card එක
            Card(
              color: Colors.green[50],
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text('අද එකතු වූ මුළු මුදල (COD)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 8),
                    Text('Rs. ${_summary!['totalCod']}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // සාරාංශ කොටු 3
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSummaryBox('Delivered', _summary!['deliveredCount'], Colors.blue),
                _buildSummaryBox('Returned', _summary!['returnedCount'], Colors.red),
                _buildSummaryBox('Pending', _summary!['pendingCount'], Colors.orange),
              ],
            ),
            
            const Spacer(),

            // PDF බොත්තම
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Generate PDF & Share'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _generateAndSharePDF,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBox(String title, int count, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Column(
        children: [
          Text(count.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

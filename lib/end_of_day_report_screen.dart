import 'package:flutter/material.dart';

class EndOfDayReportScreen extends StatefulWidget {
  const EndOfDayReportScreen({super.key});

  @override
  State<EndOfDayReportScreen> createState() => _EndOfDayReportScreenState();
}

class _EndOfDayReportScreenState extends State<EndOfDayReportScreen> {
  String _selectedFilter = 'All';

  final List<Map<String, dynamic>> reports = [
    {'order': 'Order #101', 'status': 'Delivered', 'amount': 'Rs. 2500'},
    {'order': 'Order #102', 'status': 'Returned', 'amount': 'Rs. 1800'},
    {'order': 'Order #103', 'status': 'Delivered', 'amount': 'Rs. 3200'},
  ];

  @override
  Widget build(BuildContext context) {
    final filteredReports = _selectedFilter == 'All' 
        ? reports 
        : reports.where((r) => r['status'] == _selectedFilter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('End of Day Report')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ['All', 'Delivered', 'Returned'].map((filter) {
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
          Expanded(
            child: ListView.builder(
              itemCount: filteredReports.length,
              itemBuilder: (context, index) {
                final r = filteredReports[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: ListTile(
                    title: Text(r['order']),
                    subtitle: Text('Status: ${r['status']}'),
                    trailing: Text(r['amount'], style: const TextStyle(fontWeight: FontWeight.bold)),
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

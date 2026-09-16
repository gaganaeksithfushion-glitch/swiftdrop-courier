import 'package:flutter/material.dart';

class PendingCallsScreen extends StatefulWidget {
  const PendingCallsScreen({super.key});

  @override
  State<PendingCallsScreen> createState() => _PendingCallsScreenState();
}

class _PendingCallsScreenState extends State<PendingCallsScreen> {
  // ඔබේ ප්‍රොජෙක්ට් එකේ පවතින ලොজික් එක මෙතැනට යෙදිය හැක
  final List<Map<String, dynamic>> pendingCalls = [
    {'name': 'Nimal Perera', 'phone': '0771234567', 'address': 'Kandy Road, Colombo', 'attempts': 1},
    {'name': 'Kamal Silva', 'phone': '0719876543', 'address': 'Galle Road, Matara', 'attempts': 3},
  ];

  void _updateStatus(int index, String status) {
    setState(() {
      pendingCalls.removeAt(index);
    });

    if (status == 'Confirmed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('පාර්සලය Confirmed ලෙස සටහන් විය!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (status == 'Returned') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attempts 4ක් ඉක්මවූ බැවින් Returned ලිස්ට් එකට මාරු විය.'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Answer ලෙස සටහන් විය.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Calls'),
      ),
      body: pendingCalls.isEmpty
          ? const Center(child: Text('Pending calls කිසිවක් නැත.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: pendingCalls.length,
              itemBuilder: (context, index) {
                final call = pendingCalls[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  child: ListTile(
                    title: Text(call['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${call['phone']}\n${call['address']}'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _updateStatus(index, 'Confirmed'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _updateStatus(index, 'Returned'),
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

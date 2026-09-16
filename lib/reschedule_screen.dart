import 'package:flutter/material.dart';

class RescheduleScreen extends StatefulWidget {
  const RescheduleScreen({super.key});

  @override
  State<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends State<RescheduleScreen> {
  DateTime? _selectedDate;
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reschedule Order')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(_selectedDate == null ? 'Select Reschedule Date' : 'Date: ${_selectedDate.toString().split(' ')[0]}'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reschedule Note',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rescheduled successfully!'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Save Reschedule'),
            ),
          ],
        ),
      ),
    );
  }
}

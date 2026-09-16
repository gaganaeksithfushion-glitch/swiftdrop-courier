import 'package:flutter/material.dart';

class RouteListScreen extends StatefulWidget {
  const RouteListScreen({super.key});

  @override
  State<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends State<RouteListScreen> {
  final List<String> deliveries = [
    'Order #101 - 45/2 Temple Road',
    'Order #102 - 12 Main Street',
    'Order #103 - 88 Lake Drive',
  ];

  void _markDelivered(int index) {
    setState(() {
      deliveries.removeAt(index);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('සාර්ථකව Delivered ලෙස සටහන් විය!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Map & Deliveries'),
      ),
      body: deliveries.isEmpty
          ? const Center(child: Text('අදට නියමිත බෙදාහැරීම් අවසන්ය.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: deliveries.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping, color: Colors.purple),
                    title: Text(deliveries[index]),
                    trailing: ElevatedButton(
                      onPressed: () => _markDelivered(index),
                      child: const Text('Delivered'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

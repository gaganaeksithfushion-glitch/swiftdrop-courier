import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'database_helper.dart';

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  GoogleMapController? _controller;
  Set<Marker> _markers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  // Database එකෙන් deliveries ගෙනවිත් Map එකේ Markers දැමීම
  Future<void> _loadMapData() async {
    final deliveries = await DatabaseHelper.instance.getAllDeliveries();
    Set<Marker> markers = {};

    for (var d in deliveries) {
      final lat = (d['lat'] as num?)?.toDouble();
      final lng = (d['lng'] as num?)?.toDouble();

      if (lat != null && lng != null) {
        markers.add(
          Marker(
            markerId: MarkerId(d['id'].toString()),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: d['customerName'],
              snippet: 'COD: Rs. ${d['codAmount']} • ${d['address']}',
            ),
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
      _isLoading = false;
    });

    // Current location එකත් එක්ක 3km proximity check කිරීම
    _checkNearbyProximity(deliveries);
  }

  // 3km ප්‍රදේශයේ (මීටර 3000ක් තුළ) ඩිලිවරි තිබේ නම් Alert කිරීම
  Future<void> _checkNearbyProximity(List<Map<String, dynamic>> deliveries) async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      for (var d in deliveries) {
        final lat = (d['lat'] as num?)?.toDouble();
        final lng = (d['lng'] as num?)?.toDouble();

        if (lat != null && lng != null) {
          double distanceInMeters = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            lat,
            lng,
          );

          if (distanceInMeters <= 3000) {
            if (!mounted) return;
            _showNearbyAlertPopup(d, distanceInMeters / 1000);
            break; // එක වරකට ළඟම එක පෙන්වයි
          }
        }
      }
    } catch (_) {}
  }

  void _showNearbyAlertPopup(Map<String, dynamic> delivery, double km) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📍 Nearby Delivery Alert!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ඔබට මීටර ${(km * 1000).toStringAsFixed(0)} ක් (${km.toStringAsFixed(1)} km) ළඟින් තවත් ඩිලිවරි එකක් ඇත!'),
            const SizedBox(height: 10),
            Text('නම: ${delivery['customerName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('ලිපිනය: ${delivery['address']}'),
            Text('COD: Rs. ${delivery['codAmount']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Delivery Map & Proximity')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(6.9271, 79.8612), // Default Colombo
                zoom: 12,
              ),
              markers: _markers,
              myLocationEnabled: true,
              onMapCreated: (controller) => _controller = controller,
            ),
    );
  }
}

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
  static const double _proximityThresholdMeters = 3000;

  GoogleMapController? _controller;
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _deliveries = [];
  bool _isLoading = true;

  StreamSubscription<Position>? _positionSubscription;
  // දැනට Session එකේදී Alert එකක් පෙන්නපු Delivery ID ටික - එකම Parcel එකට Repeat Popup එනවා නම් නවත්වන්න
  final Set<int> _alertedIds = {};

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  // GPS On ද, Permission තියෙනවද කියලා තහවුරු කරගැනීම - නැත්නම් User ට හේතුව Snackbar එකෙන් පෙන්නනවා
  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS එක Off වෙලා තියෙන්නේ, කරුණාකර On කරන්න!'), backgroundColor: Colors.orange),
        );
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nearby Delivery Alert එකට Location Permission එක අවශ්‍යයි!'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location Permission එක Permanently Denied වෙලා. Settings > App Permissions වලින් On කරන්න.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
    return true;
  }

  // Database එකෙන් Active (තවම නොබෙදූ) deliveries ගෙනවිත් Map එකේ Markers දැමීම
  Future<void> _loadMapData() async {
    setState(() => _isLoading = true);
    // 'delivered' / 'returned' / 'cancelled' උනු Parcel වලට Marker/Alert ඕන නෑ
    final deliveries = await DatabaseHelper.instance.getActiveDeliveries();
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
              title: (d['customerName'] ?? '').toString(),
              snippet: 'COD: Rs. ${(d['codAmount'] ?? '0').toString()} • ${(d['address'] ?? '').toString()}',
            ),
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _deliveries = deliveries;
      _markers = markers;
      _isLoading = false;
    });

    // Live Proximity Tracking - Driver ගමන් කරන අතරතුරම, Continuous ලෙස Check කිරීම
    _startLiveProximityTracking();
  }

  // GPS Stream එකකින් Driver ගේ Location එක Continuous ලෙස Track කරලා,
  // ළඟින්ම තියෙන Active Delivery එක 3km ඇතුළත ආවොත් Alert කිරීම
  Future<void> _startLiveProximityTracking() async {
    _positionSubscription?.cancel();

    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100, // මීටර 100ක් ගමන් කරාට පස්සේ විතරයි ආයෙත් Check කරන්නේ (Battery/Performance සඳහා)
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) => _checkNearbyProximity(position),
      onError: (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location Track කිරීමේ දෝෂයක් ඇති විය.'), backgroundColor: Colors.red),
          );
        }
      },
    );
  }

  // Driver ගේ Current Position එකට ළඟින්ම තියෙන (3km ඇතුළත) Delivery එක සොයාගැනීම
  // (List එකේ පිළිවෙලට ගන්නවා වෙනුවට, ඇත්තටම ළඟින්ම තියෙන එකම තෝරාගැනීම)
  void _checkNearbyProximity(Position position) {
    Map<String, dynamic>? nearestDelivery;
    double nearestDistance = double.infinity;

    for (var d in _deliveries) {
      final id = d['id'] as int?;
      if (id == null || _alertedIds.contains(id)) continue; // මේකට කලින්ම Alert එකක් පෙන්නලා ඉවරයි

      final lat = (d['lat'] as num?)?.toDouble();
      final lng = (d['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final distanceInMeters = Geolocator.distanceBetween(position.latitude, position.longitude, lat, lng);
      if (distanceInMeters <= _proximityThresholdMeters && distanceInMeters < nearestDistance) {
        nearestDistance = distanceInMeters;
        nearestDelivery = d;
      }
    }

    if (nearestDelivery != null && mounted) {
      _alertedIds.add(nearestDelivery['id'] as int);
      _showNearbyAlertPopup(nearestDelivery, nearestDistance / 1000);
    }
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
            Text('නම: ${(delivery['customerName'] ?? '').toString()}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('ලිපිනය: ${(delivery['address'] ?? '').toString()}'),
            Text('COD: Rs. ${(delivery['codAmount'] ?? '0').toString()}'),
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
      appBar: AppBar(
        title: const Text('Live Delivery Map & Proximity'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMapData, tooltip: 'Refresh'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(6.9271, 79.8612), // Default Colombo
                zoom: 12,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (controller) => _controller = controller,
            ),
    );
  }
}

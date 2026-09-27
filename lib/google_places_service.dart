import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'database_helper.dart';
import 'google_places_service.dart';

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  static const double _proximityThresholdMeters = 3000;

  GoogleMapController? _controller;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<Map<String, dynamic>> _deliveries = [];
  bool _isLoading = true;
  bool _isRouteLoading = false;

  StreamSubscription<Position>? _positionSubscription;
  // දැනට Session එකේදී Alert එකක් පෙන්නපු Delivery ID ටික - එකම Parcel එකට Repeat Popup එනවා නම් නවත්වන්න
  final Set<int> _alertedIds = {};
  // 🩹 Fix: 100m ගානකට Position Update එකක් ආවම, කලින් Dialog එකක් තාම Open නම්
  // ආයෙත් showDialog() Call කරලා Dialog Stack වෙන එක වළක්වන්න
  bool _isAlertDialogShowing = false;

  // Route Order අනුව Numbered Marker Icons Cache කරගන්නවා (හැම Load එකකම අලුතෙන් Draw කරන්නේ නෑ)
  final Map<int, BitmapDescriptor> _numberedIconCache = {};

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

  // Number 1, 2, 3... එකක් සහිත, Deep Purple Circle Marker Icon එකක් Canvas එකකින් අඳිනවා
  // (Confirmed Route Stops ටික, ඒවායේ පිළිවෙලම Map එකේ පේන්න)
  Future<BitmapDescriptor> _buildNumberedIcon(int number) async {
    if (_numberedIconCache.containsKey(number)) return _numberedIconCache[number]!;

    const double size = 96;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final fillPaint = Paint()..color = const Color(0xFF4A148C);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, fillPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 3, borderPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: '$number',
        style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
      )
      ..layout();
    textPainter.paint(canvas, Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final icon = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
    _numberedIconCache[number] = icon;
    return icon;
  }

  // Database එකෙන් Active deliveries ගෙනවිත් Map එකේ Markers දැමීම -
  // "Confirmed" (Route එකේ තියෙන) Parcel ටිකට Numbered Icon, ඉතුරු ("Pending") ඒවාට සාමාන්‍ය Marker එකක්
  Future<void> _loadMapData() async {
    setState(() => _isLoading = true);

    // 'delivered' / 'returned' / 'cancelled' උනු Parcel වලට Marker/Alert ඕන නෑ
    final deliveries = await DatabaseHelper.instance.getActiveDeliveries();
    // Confirmed ටික, Driver Set කරපු Route Order එකටම (routeOrder ASC)
    final confirmedInOrder = await DatabaseHelper.instance.getConfirmedDeliveries();
    final confirmedWithLocation =
        confirmedInOrder.where((d) => d['lat'] != null && d['lng'] != null).toList();

    final confirmedIds = confirmedWithLocation.map((d) => d['id'] as int).toSet();

    final Set<Marker> markers = {};
    for (var d in deliveries) {
      final lat = (d['lat'] as num?)?.toDouble();
      final lng = (d['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final id = d['id'] as int;
      final isConfirmed = confirmedIds.contains(id);
      BitmapDescriptor icon;
      if (isConfirmed) {
        final stopNumber = confirmedWithLocation.indexWhere((c) => c['id'] == id) + 1;
        icon = await _buildNumberedIcon(stopNumber);
      } else {
        // Pending/Rescheduled - තාම Route එකට Confirm වෙලා නෑ, Orange Marker එකකින් වෙන් කරනවා
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      }

      markers.add(
        Marker(
          markerId: MarkerId(id.toString()),
          position: LatLng(lat, lng),
          icon: icon,
          infoWindow: InfoWindow(
            title: (d['customerName'] ?? '').toString(),
            snippet: 'COD: Rs. ${(d['codAmount'] ?? '0').toString()} • ${(d['address'] ?? '').toString()}'
                '${isConfirmed ? '  •  Route Stop #${confirmedWithLocation.indexWhere((c) => c['id'] == id) + 1}' : '  •  Pending'}',
          ),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _deliveries = deliveries;
      _markers = markers;
      _isLoading = false;
    });

    // Live Proximity Tracking - Driver ගමන් කරන අතරතුරම, Continuous ලෙස Check කිරීම
    _startLiveProximityTracking();

    // Confirmed Route එකේ Road-Following Line එක Draw කිරීම (2ක්වත් Location Save කරලා තියෙනවා නම්)
    if (confirmedWithLocation.length >= 1) {
      _loadRoutePolyline(confirmedWithLocation);
    } else {
      setState(() => _polylines = {});
    }
  }

  // Driver ගේ Current GPS Position එකේ ඉඳලා, Confirmed Route එකේ Order එකටම Road Polyline එක ගෙන Draw කිරීම
  Future<void> _loadRoutePolyline(List<Map<String, dynamic>> confirmedWithLocation) async {
    if (!GooglePlacesService.isConfigured) return;

    setState(() => _isRouteLoading = true);

    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) {
      if (mounted) setState(() => _isRouteLoading = false);
      return;
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      if (mounted) setState(() => _isRouteLoading = false);
      return;
    }

    final origin = LatLngResult(position.latitude, position.longitude);
    final waypoints = confirmedWithLocation
        .map((d) => LatLngResult((d['lat'] as num).toDouble(), (d['lng'] as num).toDouble()))
        .toList();

    final polylinePoints = await GooglePlacesService.getRoutePolyline(origin: origin, waypointsInOrder: waypoints);

    if (!mounted) return;
    setState(() {
      _isRouteLoading = false;
      if (polylinePoints != null && polylinePoints.isNotEmpty) {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('confirmed_route'),
            points: polylinePoints.map((p) => LatLng(p.lat, p.lng)).toList(),
            color: const Color(0xFF4A148C),
            width: 5,
          ),
        };
      } else {
        _polylines = {};
      }
    });
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
    // 🩹 Fix: කලින් Alert එකක් තාම Screen එකේ Open නම්, ආයෙත් Alert එකක් Stack කරන්නේ නෑ -
    // GPS Stream එක 100m ගානකට Continuous ලෙස Trigger වෙන නිසා, Dialog Multiple Times Pop Up විය හැක
    if (_isAlertDialogShowing) return;

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
    _isAlertDialogShowing = true;
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
            onPressed: () {
              _isAlertDialogShowing = false;
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((_) => _isAlertDialogShowing = false); // Dialog Back Button එකෙන් / Outside Tap එකෙන් Close උනත් Reset වෙනවා
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
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(6.9271, 79.8612), // Default Colombo
                    zoom: 12,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (controller) => _controller = controller,
                ),
                if (_isRouteLoading)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text('Route Line එක ගණනය කරමින්...', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (!_isRouteLoading && _markers.isNotEmpty)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _legendRow(const Color(0xFF4A148C), 'Confirmed Route Stop (Numbered)'),
                            const SizedBox(height: 4),
                            _legendRow(Colors.orange, 'Pending / Not Yet Confirmed'),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

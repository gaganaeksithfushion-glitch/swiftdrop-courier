import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'database_helper.dart';

class RouteListScreen extends StatefulWidget {
  const RouteListScreen({super.key});

  @override
  State<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends State<RouteListScreen> {
  List<Map<String, dynamic>> _confirmedDeliveries = [];
  bool _isLoading = true;
  
  // සිතියම පාලනය කරන Controller එක
  GoogleMapController? _mapController;
  
  // ආරම්භක ස්ථානය (දැනට කොළඹ ලෙස දී ඇත, පසුව GPS මගින් ගනී)
  final LatLng _initialPosition = const LatLng(6.9271, 79.8612);

  @override
  void initState() {
    super.initState();
    _loadConfirmedDeliveries();
  }

  Future<void> _loadConfirmedDeliveries() async {
    final data = await DatabaseHelper.instance.getConfirmedDeliveries();
    setState(() {
      _confirmedDeliveries = data;
      _isLoading = false;
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('දුරකථන ඇමතුම ලබා ගත නොහැක.')));
    }
  }

  Future<void> _markAsDelivered(int id) async {
    await DatabaseHelper.instance.updateDeliveryStatus(id, 'delivered', 0);
    _loadConfirmedDeliveries(); // ලිස්ට් එක Refresh කර ඊළඟ පාර්සලය පෙන්වයි
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('සාර්ථකව Delivered ලෙස සටහන් විය!', backgroundColor: Colors.green)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_confirmedDeliveries.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Route')),
        body: const Center(child: Text('බෙදා හැරීමට පාර්සල් නොමැත.', style: TextStyle(fontSize: 18))),
      );
    }

    // ලැයිස්තුවේ ඇති පළමු පාර්සලය (දැන් යා යුතු තැන)
    final currentTarget = _confirmedDeliveries.first;

    return Scaffold(
      appBar: AppBar(
        title: Text('Next: ${currentTarget['customerName']}'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 80% ක් සිතියම සඳහා (Expanded මගින් ඉතිරි ඉඩ සියල්ල ගනී)
          Expanded(
            flex: 4, // 80% අනුපාතය
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 14),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              // පාර්සලය බෙදිය යුතු ස්ථානයට රතු පාට Marker එකක් දමයි
              markers: {
                Marker(
                  markerId: const MarkerId('targetDestination'),
                  position: _initialPosition, // පසුව මෙතැනට නියම Latitude/Longitude ලබා දිය යුතුය
                  infoWindow: InfoWindow(title: currentTarget['customerName'], snippet: currentTarget['address']),
                )
              },
            ),
          ),
          
          // 20% ක් විස්තර සහ බොත්තම් සඳහා
          Expanded(
            flex: 1, // 20% අනුපාතය
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(currentTarget['customerName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                            Text(currentTarget['address'], style: const TextStyle(color: Colors.grey, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1),
                          ],
                        ),
                      ),
                      Text('Rs. ${currentTarget['codAmount']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 20)),
                    ],
                  ),
                  Row(
                    children: [
                      // කෝල් බොත්තම
                      Expanded(
                        flex: 1,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.call),
                          label: const Text('Call'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                          onPressed: () => _makePhoneCall(currentTarget['phone']),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Delivered බොත්තම
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle),
                          label: const Text('DELIVERED', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                          onPressed: () => _markAsDelivered(currentTarget['id']),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

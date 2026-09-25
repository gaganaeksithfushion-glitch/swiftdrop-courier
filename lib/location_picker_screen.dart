import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'google_places_service.dart';

// Result object - Screen එකෙන් ආපහු එවන Location එක
class PickedLocation {
  final double lat;
  final double lng;
  final String? address;
  PickedLocation({required this.lat, required this.lng, this.address});
}

// Map එකක් මත Pin එකක් ඇද ගෙන, Customer ගේ Delivery Location එක නිවැරදිව Pick කරගැනීමට
class LocationPickerScreen extends StatefulWidget {
  // Screen එක Open වෙද්දි පෙන්නන්න ඕන ආරම්භක Location එක (තියෙනවා නම්)
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const LatLng _fallbackCenter = LatLng(6.9271, 79.8612); // Colombo

  GoogleMapController? _mapController;
  LatLng _pickedLatLng = _fallbackCenter;
  bool _isLoadingLocation = true;

  // Address Search සඳහා
  final TextEditingController _searchController = TextEditingController();
  List<PlaceSuggestion> _suggestions = [];
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    // දැනටමත් Delivery එකට Save කරලා තියෙන Location එකක් තියෙනවා නම්, ඒකෙන් Start කරනවා
    if (widget.initialLat != null && widget.initialLng != null) {
      setState(() {
        _pickedLatLng = LatLng(widget.initialLat!, widget.initialLng!);
        _isLoadingLocation = false;
      });
      return;
    }
    // නැත්නම් Driver ගේ Current GPS Location එකෙන් Start කරනවා
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          if (mounted) {
            setState(() => _pickedLatLng = LatLng(pos.latitude, pos.longitude));
          }
        }
      }
    } catch (_) {
      // GPS අසාර්ථක උනොත් Fallback (Colombo) Center එකෙන්ම පටන් ගන්නවා
    }
    if (mounted) setState(() => _isLoadingLocation = false);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (!GooglePlacesService.isConfigured) return;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (value.trim().length < 3) {
        setState(() => _suggestions = []);
        return;
      }
      setState(() => _isSearching = true);
      final results = await GooglePlacesService.autocomplete(value);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    setState(() {
      _searchController.text = suggestion.description;
      _suggestions = [];
      _isSearching = true;
    });
    final latLng = await GooglePlacesService.getPlaceLatLng(suggestion.placeId);
    if (!mounted) return;
    setState(() => _isSearching = false);
    if (latLng != null) {
      final target = LatLng(latLng.lat, latLng.lng);
      setState(() => _pickedLatLng = target);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
    }
  }

  Future<void> _useMyCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GPS එක Off වෙලා තියෙන්නේ, කරුණාකර On කරන්න!'), backgroundColor: Colors.orange),
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        setState(() => _isLoadingLocation = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final target = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _pickedLatLng = target;
        _isLoadingLocation = false;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
    } catch (_) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _confirmLocation() {
    Navigator.pop(
      context,
      PickedLocation(lat: _pickedLatLng.latitude, lng: _pickedLatLng.longitude),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Location එක Pick කරන්න'),
      ),
      body: _isLoadingLocation
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: _pickedLatLng, zoom: 16),
                  onMapCreated: (controller) => _mapController = controller,
                  onCameraMove: (position) => _pickedLatLng = position.target,
                  onCameraIdle: () => setState(() {}),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                // සෑම විටම Map එකේ මැදින්ම පේන Fixed Pin එක - Camera එක Move කරද්දි එතන තමයි Location එක Select වෙන්නේ
                const IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 36),
                      child: Icon(Icons.location_pin, size: 46, color: Colors.deepPurple),
                    ),
                  ),
                ),
                // Address Search Bar
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    children: [
                      Material(
                        elevation: 3,
                        borderRadius: BorderRadius.circular(10),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'ලිපිනයක් සොයන්න...',
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      if (_suggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
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
                    ],
                  ),
                ),
                // Current Location Button
                Positioned(
                  bottom: 100,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'myLocationBtn',
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: _useMyCurrentLocation,
                    child: const Icon(Icons.my_location, color: Colors.deepPurple),
                  ),
                ),
                // Confirm Button
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _confirmLocation,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('මේ Location එක තෝරගන්න', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
    );
  }
}

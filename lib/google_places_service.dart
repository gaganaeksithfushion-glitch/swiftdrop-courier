import 'dart:convert';
import 'package:http/http.dart' as http;

class PlaceSuggestion {
  final String placeId;
  final String description;
  PlaceSuggestion({required this.placeId, required this.description});
}

class LatLngResult {
  final double lat;
  final double lng;
  LatLngResult(this.lat, this.lng);
}

class GooglePlacesService {
  // ⚠️ මේ Key එක කිසිම විටෙක මෙතන Hardcode කරන්න එපා!
  // Build කරද්දි --dart-define=GOOGLE_API_KEY=xxxxxxxx විදිහට pass කරන්න
  // (Codemagic එකේදී Environment Variable Group එකක් හරහා, Secure ලෙස).
  static const String _apiKey = String.fromEnvironment('GOOGLE_API_KEY', defaultValue: '');

  static bool get isConfigured => _apiKey.isNotEmpty;

  // Address Autocomplete - Type කරන විට Matching Places (Sri Lanka තුළ) ලබාගැනීම
  static Future<List<PlaceSuggestion>> autocomplete(String input) async {
    if (_apiKey.isEmpty || input.trim().length < 3) return [];
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(input)}'
      '&components=country:lk'
      '&key=$_apiKey',
    );
    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (data['status'] != 'OK') return [];
      final predictions = data['predictions'] as List;
      return predictions
          .map((p) => PlaceSuggestion(placeId: p['place_id'] as String, description: p['description'] as String))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Selected Place එකේ Lat/Lng (Coordinates) ලබාගැනීම
  static Future<LatLngResult?> getPlaceLatLng(String placeId) async {
    if (_apiKey.isEmpty) return null;
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId'
      '&fields=geometry'
      '&key=$_apiKey',
    );
    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (data['status'] != 'OK') return null;
      final loc = data['result']['geometry']['location'];
      return LatLngResult((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
    } catch (_) {
      return null;
    }
  }

  // Directions API - Current Location එකේ ඉඳලා, Stops ටික Best Order එකට Optimize කිරීම
  // Returns: Original List එකේ Index පිළිවෙලට, Optimized Order එක (අන්තිම Stop එකත් ඇතුළුව)
  static Future<List<int>?> optimizeRoute({
    required LatLngResult origin,
    required List<LatLngResult> waypoints,
  }) async {
    if (_apiKey.isEmpty || waypoints.isEmpty) return null;

    // අන්තිම Stop එකම Destination විදිහටත්, ඉතුරු ඒවා Optimize වෙන Waypoints විදිහටත් යවනවා
    final destination = waypoints.last;
    final middleWaypoints = waypoints.sublist(0, waypoints.length - 1);
    final waypointsParam = middleWaypoints.map((w) => '${w.lat},${w.lng}').join('|');

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${origin.lat},${origin.lng}'
      '&destination=${destination.lat},${destination.lng}'
      '${middleWaypoints.isNotEmpty ? '&waypoints=optimize:true|$waypointsParam' : ''}'
      '&key=$_apiKey',
    );

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (data['status'] != 'OK') return null;
      final order = (data['routes'][0]['waypoint_order'] as List).map((e) => e as int).toList();
      // Destination එකේ (Last Item එකේ) Original Index එක අන්තිමට එකතු කිරීම
      order.add(waypoints.length - 1);
      return order;
    } catch (_) {
      return null;
    }
  }
}

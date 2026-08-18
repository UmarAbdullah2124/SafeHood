import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeocodingService {
  // Free geocoding using OpenStreetMap (No API key required!)
  static Future<LatLng?> getCoordinatesFromAddress(String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = 'https://nominatim.openstreetmap.org/search?q=$encodedAddress&format=json&limit=1';

      print('🔍 Searching: $address');
      print('📡 URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'SafehoodApp/1.0', // Required by Nominatim
        },
      );

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          print('✅ Found: $lat, $lon');
          print('📍 Display name: ${data[0]['display_name']}');
          return LatLng(lat, lon);
        } else {
          print('❌ No results found for: $address');
          return null;
        }
      }
      return null;
    } catch (e) {
      print('❌ Geocoding error: $e');
      return null;
    }
  }
}
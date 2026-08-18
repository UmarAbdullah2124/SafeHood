import 'package:shared_preferences/shared_preferences.dart';

/// Fixed map anchor for geofenced community chat (set when Community tab is first opened).
class CommunityLocationService {
  static const _latKey = 'community_chat_anchor_lat';
  static const _lngKey = 'community_chat_anchor_lng';

  static Future<({double lat, double lng})> getOrSetAnchor({
    required double currentLat,
    required double currentLng,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedLat = prefs.getDouble(_latKey);
    final savedLng = prefs.getDouble(_lngKey);

    if (savedLat != null && savedLng != null) {
      return (lat: savedLat, lng: savedLng);
    }

    await prefs.setDouble(_latKey, currentLat);
    await prefs.setDouble(_lngKey, currentLng);
    return (lat: currentLat, lng: currentLng);
  }

  static Future<({double lat, double lng})?> getAnchor() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  }
}

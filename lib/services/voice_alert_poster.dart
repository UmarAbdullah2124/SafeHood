import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/post_model.dart';
import 'firebase_service.dart';
import 'location_service.dart';
import 'user_profile_service.dart';

class VoiceAlertPoster {
  static Future<String> postAlert({
    required String intent,
    required String emergencyType,
    String? description,
    String? detectedText,
  }) async {
    final hasLocation = await LocationService.checkAndRequestPermissions();
    if (!hasLocation) {
      throw Exception('Location permission is required to post an alert.');
    }

    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseService.signInAnonymously();
    }

    final position = await LocationService.getCurrentLocation();
    final locationName = await LocationService.getAddressFromLatLng(
      LatLng(position.latitude, position.longitude),
    );

    final profile = await UserProfileService.resolveForPost();

    var finalDescription = description?.trim() ?? '';
    if (finalDescription.isEmpty) {
      finalDescription = intent == 'alert'
          ? 'Emergency alert posted via voice${detectedText != null ? ': $detectedText' : ''}'
          : 'Help requested via voice${detectedText != null ? ': $detectedText' : ''}';
    }

    final post = EmergencyPost(
      id: '',
      userId: profile.userId,
      type: intent,
      emergencyType: emergencyType,
      description: finalDescription,
      locationName: locationName,
      latitude: position.latitude,
      longitude: position.longitude,
      userName: profile.userName,
      firstName: profile.firstName,
      lastName: profile.lastName,
      timestamp: DateTime.now(),
      trueVotes: 0,
      fakeVotes: 0,
      reportCount: 0,
    );

    await FirebaseService.createPost(post);
    return locationName;
  }
}

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../utils/app_colors.dart';
import '../utils/distance_utils.dart';
import '../utils/constants.dart';
import '../services/firebase_service.dart';
import '../services/direct_chat_service.dart';
import 'direct_chat_screen.dart';

class PostDetailScreen extends StatelessWidget {
  final EmergencyPost post;
  final LatLng userLocation;
  final String currentLocationName;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.userLocation,
    required this.currentLocationName,
  });

  void _openGoogleMaps() async {
    final url = 'https://www.google.com/maps/dir/?api=1&origin=${userLocation.latitude},${userLocation.longitude}&destination=${post.latitude},${post.longitude}&travelmode=driving';

    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch Google Maps';
    }
  }

  void _votePost(BuildContext context, bool isTrue) async {
    try {
      await FirebaseService.votePost(post.id, isTrue);
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isTrue ? '✓ You marked this as TRUE' : '✗ You marked this as FAKE'),
          backgroundColor: isTrue ? Colors.green : Colors.red,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      String errorMsg = e.toString().contains('Exception: ')
          ? e.toString().split('Exception: ')[1]
          : 'Failed to vote';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // NEW: Chat functionality from second file
  bool _canChatWithAuthor() {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null || post.authorId.isEmpty) return false;
    return me != post.authorId;
  }

  // NEW: Open chat with author from second file
  Future<void> _openChatWithAuthor(BuildContext context) async {
    try {
      final chatId = await DirectChatService.ensureChat(
        otherUserId: post.authorId,
        otherUserName: post.userName,
        linkedPostId: post.id,
      );
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DirectChatScreen(
            chatId: chatId,
            otherUserName: post.userName,
          ),
        ),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat saved under Community → Messages'),
          backgroundColor: AppColors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showVerificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.darkBg,
          title: const Text("Verify Post", style: TextStyle(color: Colors.white)),
          content: const Text(
            "Is this alert real or fake?",
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _votePost(context, true);
              },
              child: const Text("TRUE", style: TextStyle(color: Colors.green)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _votePost(context, false);
              },
              child: const Text("FAKE", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  String _getDistance() {
    double distance = DistanceUtils.calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      post.latitude,
      post.longitude,
    );

    if (distance < 0.1) {
      return '<100m away';
    } else if (distance < 1) {
      return '${(distance * 1000).toInt()}m away';
    } else {
      return '${distance.toStringAsFixed(1)}km away';
    }
  }

  String _getFormattedTime() {
    final now = DateTime.now();
    final difference = now.difference(post.timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${post.timestamp.day}/${post.timestamp.month}/${post.timestamp.year}';
    }
  }

  Color _getEmergencyColor() {
    switch (post.emergencyType.toLowerCase()) {
      case 'medical':
        return Colors.red;
      case 'theft / robbery':
        return Colors.purple;
      case 'house / building fire':
        return Colors.orange;
      case 'accident in street':
        return Colors.deepOrange;
      default:
        return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isHelpPost = post.type == 'help';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Full Screen Map (Dark Mode)
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                post.latitude - 0.012, // Shift focus down so marker appears higher on screen
                post.longitude,
              ),
              zoom: 15,
            ),
            onMapCreated: (GoogleMapController controller) {
              controller.setMapStyle(Constants.darkMapStyle);
              // Ensure it focuses on the right spot even after creation
              controller.moveCamera(
                CameraUpdate.newLatLng(
                  LatLng(post.latitude - 0.012, post.longitude),
                ),
              );
            },
            markers: {
              Marker(
                markerId: const MarkerId('incident'),
                position: LatLng(post.latitude, post.longitude),
                infoWindow: InfoWindow(
                  title: post.emergencyType,
                  snippet: post.locationName,
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  isHelpPost ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueAzure,
                ),
              ),
              Marker(
                markerId: const MarkerId('user'),
                position: userLocation,
                infoWindow: const InfoWindow(title: 'Your Location'),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
              ),
            },
            myLocationEnabled: true,
            zoomControlsEnabled: true,
            compassEnabled: true,
          ),

          // Back Button (Top Left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.darkBg.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
          ),

          // Direction Button on Map (Bottom Right)
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.58,
            right: 16,
            child: GestureDetector(
              onTap: _openGoogleMaps,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Directions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Popup Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.45,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.darkBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 50,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[600],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // User Row (like card)
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.blue.withOpacity(0.2),
                            child: Icon(Icons.person, color: AppColors.blue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _getFormattedTime(),
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          // Emergency Type Tag (like card)
                          if (!isHelpPost)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _getEmergencyColor().withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                post.emergencyType.toUpperCase(),
                                style: TextStyle(
                                  color: _getEmergencyColor(),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // UPDATED: Title + Chat Button (from second file)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              isHelpPost ? 'Help Request' : 'Emergency Alert',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // NEW: Chat button from second file
                          if (_canChatWithAuthor())
                            TextButton.icon(
                              onPressed: () => _openChatWithAuthor(context),
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                color: AppColors.blue,
                                size: 20,
                              ),
                              label: const Text(
                                'Chat',
                                style: TextStyle(
                                  color: AppColors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Description Container
                      if (post.description.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.darkBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Text(
                            post.description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Location Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 16, color: AppColors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    post.locationName,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.straighten, size: 16, color: AppColors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  _getDistance(),
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.map, size: 16, color: AppColors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${post.latitude.toStringAsFixed(6)}, ${post.longitude.toStringAsFixed(6)}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Verification Stats (Clickable)
                      GestureDetector(
                        onTap: () => _showVerificationDialog(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.darkBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified, size: 16, color: AppColors.blue),
                                  SizedBox(width: 8),
                                  Text(
                                    'Community Verification',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // True Votes Button
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _votePost(context, true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                                        ),
                                        child: Column(
                                          children: [
                                            const Icon(Icons.check_circle, color: Colors.green, size: 24),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${post.trueVotes}',
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const Text(
                                              'True',
                                              style: TextStyle(color: Colors.green, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Fake Votes Button
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _votePost(context, false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                                        ),
                                        child: Column(
                                          children: [
                                            const Icon(Icons.cancel, color: Colors.red, size: 24),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${post.fakeVotes}',
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const Text(
                                              'Fake',
                                              style: TextStyle(color: Colors.red, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  'Tap to verify this post',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Get Directions Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openGoogleMaps,
                          icon: const Icon(Icons.directions, color: Colors.white, size: 18),
                          label: const Text(
                            'Get Directions',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
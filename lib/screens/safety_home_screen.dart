import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled/screens/profile_screen.dart';
import 'package:untitled/screens/quick_post_dialog.dart';
import '../services/location_checker.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../services/location_service.dart';
import '../utils/distance_utils.dart';
import '../widgets/nav_icon.dart';
import '../widgets/emergency_post_popup.dart';
import '../models/post_model.dart';
import '../services/firebase_service.dart';
import '../services/messaging_service.dart';
import '../services/nearby_post_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/post_detail_screen.dart';
import 'chatbot_screen.dart';
import 'sign_in_screen.dart';
import 'community_chat_list_screen.dart';
import 'package:flutter/cupertino.dart';

class SafetyHomeScreen extends StatefulWidget {
  const SafetyHomeScreen({super.key});

  @override
  _SafetyHomeScreenState createState() => _SafetyHomeScreenState();
}

class _SafetyHomeScreenState extends State<SafetyHomeScreen> with WidgetsBindingObserver {
  late GoogleMapController _mapController;

  LatLng _currentPosition = LatLng(31.5204, 74.3587);
  String _currentLocationName = "Scanning your location...";
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  bool _isFollowingUser = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _handleNotificationTap();
    WidgetsBinding.instance.addObserver(this);
    _initializeLocation();
    Future.delayed(const Duration(seconds: 2), () {
      _testFirestoreConnection();
    });
  }

  @override
  void dispose() {
    NearbyPostNotificationService.instance.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('🔄 App resumed, checking location...');
      _checkLocationAfterResume();
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  String _getDistanceFromUser(double postLat, double postLon) {
    if (postLat == 0.0 ||
        postLon == 0.0 ||
        (postLat == 31.5204 && postLon == 74.3587)) {
      return 'Distance unknown';
    }

    try {
      double distance = DistanceUtils.calculateDistance(
        _currentPosition.latitude,
        _currentPosition.longitude,
        postLat,
        postLon,
      );

      if (distance < 0.1) {
        return '<100m away';
      } else if (distance < 1) {
        return '${(distance * 1000).toInt()}m away';
      } else {
        return '${distance.toStringAsFixed(1)}km away';
      }
    } catch (e) {
      return 'Distance unknown';
    }
  }

  void _showReportDialog(String postId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text("Verify Post", style: TextStyle(color: Colors.white)),
          content: const Text(
            "Is this alert real or fake?",
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FirebaseService.votePost(postId, true);
                Navigator.pop(context);
              },
              child: const Text("TRUE", style: TextStyle(color: Colors.green)),
            ),
            TextButton(
              onPressed: () {
                FirebaseService.votePost(postId, false);
                Navigator.pop(context);
              },
              child: const Text("FAKE", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkLocationAfterResume() async {
    bool isEnabled = await Geolocator.isLocationServiceEnabled();
    if (isEnabled && _currentLocationName == "Location services disabled") {
      print('✅ Location enabled, refreshing...');
      await _refreshLocation();
    } else if (!isEnabled) {
      setState(() {
        _currentLocationName = "Location services disabled";
      });
    }
  }

  Future<void> _refreshLocation() async {
    print('🔄 Refreshing location after settings change...');

    bool isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      setState(() {
        _currentLocationName = "Location services disabled";
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    await _getCurrentLocation();
    _startLocationUpdates();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Location enabled! Refreshing...'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _testFirestoreConnection() async {
    try {
      var snapshot = await FirebaseFirestore.instance.collection('posts').limit(1).get();
      print('✅ Community connection successful!');
      var allPosts = await FirebaseFirestore.instance.collection('posts').get();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Community connected!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Firestore connection failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firestore error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _initializeLocation() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      bool hasService = await LocationChecker.checkAndRequestLocation(context, () {
        _refreshLocation();
      });

      if (!hasService) {
        setState(() {
          _currentLocationName = "Location services disabled";
        });
        return;
      }

      bool hasPermission = await LocationService.checkAndRequestPermissions();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission denied. Please enable in settings.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      await _getCurrentLocation();
      _startLocationUpdates();
    });
  }

  Widget _buildLocationDisabledWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_off,
            size: 70,
            color: Colors.grey,
          ),
          const SizedBox(height: 5),
          const Text(
            'Location Services Disabled',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Please enable location services to see nearby alerts',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              await LocationChecker.checkAndRequestLocation(context, () {
                _refreshLocation();
              });

              if (await Geolocator.isLocationServiceEnabled()) {
                await _refreshLocation();
              }
            },
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
            label: const Text(
              'Retry',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: 30,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await LocationService.getCurrentLocation();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      _currentLocationName = await LocationService.getAddressFromLatLng(_currentPosition);
      _addCustomLocationMarker();
      _centerOnUserLocation();
      await _syncNearbyNotifications(_currentPosition.latitude, _currentPosition.longitude);
    } catch (e) {
      print("Error getting location: $e");
      _addCustomLocationMarker();
    }
  }

  void _startLocationUpdates() {
    final positionStream = LocationService.getLocationStream();
    positionStream.listen((Position position) {
      if (mounted) {
        setState(() => _currentPosition = LatLng(position.latitude, position.longitude));
        _addCustomLocationMarker();
        _updateLocationName();
        _syncNearbyNotifications(position.latitude, position.longitude);

        if (_isFollowingUser) {
          _mapController.animateCamera(CameraUpdate.newLatLng(_currentPosition));
        }
      }
    });
  }

  Future<void> _syncNearbyNotifications(double latitude, double longitude) async {
    await NearbyPostNotificationService.instance.updateLocation(latitude, longitude);
    await MessagingService.updatePostAlertTopic(
      latitude: latitude,
      longitude: longitude,
    );
    await MessagingService.updateCommunityChatTopic(
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> _updateLocationName() async {
    _currentLocationName = await LocationService.getAddressFromLatLng(_currentPosition);
    if (mounted) setState(() {});
  }

  void _addCustomLocationMarker() {
    setState(() {
      _markers.clear();
      _circles.clear();

      _circles.addAll([
        Circle(
          circleId: const CircleId('current_location_outer_circle'),
          center: _currentPosition,
          radius: 300,
          strokeWidth: 2,
          strokeColor: AppColors.blue.withOpacity(0.5),
          fillColor: AppColors.blue.withOpacity(0.15),
        ),
        Circle(
          circleId: const CircleId('current_location_inner_circle'),
          center: _currentPosition,
          radius: 70,
          strokeWidth: 2,
          strokeColor: AppColors.blue.withOpacity(0.9),
          fillColor: AppColors.blue.withOpacity(0.4),
        ),
        Circle(
          circleId: const CircleId('current_location_center_dot'),
          center: _currentPosition,
          radius: 20,
          strokeWidth: 1,
          strokeColor: AppColors.textPrimary,
          fillColor: AppColors.blue,
        ),
      ]);
    });
  }

  void _centerOnUserLocation() {
    _mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            _currentPosition.latitude - 0.003,
            _currentPosition.longitude,
          ),
          zoom: Constants.defaultMapZoom,
        ),
      ),
    );
    setState(() => _isFollowingUser = true);
  }

  void _showEmergencyPostPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: EmergencyPostPopup(
            currentLocation: _currentLocationName,
            onPostSubmitted: (emergencyType, location, useCurrentLocation) {
              setState(() {});
            },
          ),
        );
      },
    );
  }

  void _onNavItemTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ChatbotScreen(),
        ),
      );
      return;
    }

    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ProfileScreen(),
        ),
      ).then((_) {
        setState(() {});
      });
      return;
    }

    setState(() => _selectedIndex = index);
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  // Function to center map on current location
  void _goToCurrentLocation() {
    if (_currentPosition.latitude != 31.5204 || _currentPosition.longitude != 74.3587) {
      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentPosition,
            zoom: Constants.defaultMapZoom,
          ),
        ),
      );
      setState(() => _isFollowingUser = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Centered on your location'),
          backgroundColor: AppColors.blue,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting your location...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return Scaffold(
      extendBody: true,
      floatingActionButton: GestureDetector(
        onTap: _showEmergencyPostPopup,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.blue, AppColors.blue.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.blue.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.add_moderator_sharp, color: AppColors.textPrimary, size: 30),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: AppColors.darkBg,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        elevation: 10,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              NavIcon(
                assetName: 'lib/assets/icons/home.png',
                filledAssetName: 'lib/assets/icons/home_fill.png',
                label: 'Home',
                index: 0,
                selectedIndex: _selectedIndex,
                onTap: _onNavItemTapped,
              ),
              NavIcon(
                assetName: 'lib/assets/icons/community.png',
                filledAssetName: 'lib/assets/icons/community_fill.png',
                label: 'Community',
                index: 1,
                selectedIndex: _selectedIndex,
                onTap: _onNavItemTapped,
              ),
              const SizedBox(width: 50),
              NavIcon(
                assetName: 'lib/assets/icons/ai.png',
                filledAssetName: 'lib/assets/icons/ai_fill.png',
                label: 'Safebot',
                index: 2,
                selectedIndex: _selectedIndex,
                onTap: _onNavItemTapped,
              ),
              NavIcon(
                assetName: 'lib/assets/icons/profile.png',
                filledAssetName: 'lib/assets/icons/profile_fill.png',
                label: 'Profile',
                index: 3,
                selectedIndex: _selectedIndex,
                onTap: _onNavItemTapped,
              ),
            ],
          ),
        ),
      ),
      body: _selectedIndex == 1
          ? SafeArea(
        child: CommunityChatListScreen(
          latitude: _currentPosition.latitude,
          longitude: _currentPosition.longitude,
        ),
      )
          : Stack(
        children: [
          // Map - takes top half of screen
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.5,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _currentPosition, zoom: Constants.defaultMapZoom),
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                controller.setMapStyle(Constants.darkMapStyle);
                if (_isFollowingUser) _centerOnUserLocation();
              },
              zoomControlsEnabled: false,
              myLocationEnabled: false,
              markers: _markers,
              circles: _circles,
              onCameraMoveStarted: () => setState(() => _isFollowingUser = false),
            ),
          ),
          // Location name pill at top center
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBg.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.blue.withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, color: AppColors.blue, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _currentLocationName,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Posts slider - bottom half with rounded top
          Positioned(
            top: MediaQuery.of(context).size.height * 0.5 - 35,
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.darkBg.withOpacity(1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: _buildBodyForSelectedIndex(),
            ),
          ),
          // RECENT LOCATION BUTTON - Placed AFTER the posts slider so it appears on top
          // Positioned at the bottom of the map, right above the slider
          // RECENT LOCATION BUTTON
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.5 + 45,
            child: GestureDetector(
              onTap: _goToCurrentLocation,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.darkBg.withOpacity(0.85),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.blue.withOpacity(1),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: 0.5320, // 30 degrees
                  child: Icon(
                    Icons.navigation,
                    color: AppColors.blue.withOpacity(1),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyForSelectedIndex() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      default:
        return const Center(child: Text("Coming Soon", style: TextStyle(color: Colors.white)));
    }
  }

  Widget _buildHomeContent() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.darkBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const TabBar(
              dividerColor: Colors.blueGrey,
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(color: AppColors.blue, width: 3),
                insets: EdgeInsets.symmetric(horizontal: 80),
              ),
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              unselectedLabelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
              tabs: [
                Tab(text: "Alerts"),
                Tab(text: "Helps"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildAlertList(),
                _buildHelpList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertList() {
    if (_currentLocationName == "Location services disabled") {
      return _buildLocationDisabledWidget();
    }

    return StreamBuilder<List<EmergencyPost>>(
      stream: FirebaseService.getNearbyPostsStream(
        'alert',
        _currentPosition.latitude,
        _currentPosition.longitude,
        5.0,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue)),
                SizedBox(height: 16),
                Text('Loading alerts...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 16),
                const Text('Error loading alerts', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 50, color: Colors.grey),
                SizedBox(height: 8),
                Text('No alerts nearby', style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 50,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) => _buildPostCard(posts[index]),
        );
      },
    );
  }

  Widget _buildHelpList() {
    if (_currentLocationName == "Location services disabled") {
      return _buildLocationDisabledWidget();
    }

    return StreamBuilder<List<EmergencyPost>>(
      stream: FirebaseService.getNearbyPostsStream(
        'help',
        _currentPosition.latitude,
        _currentPosition.longitude,
        5.0,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue)),
                SizedBox(height: 16),
                Text('Loading help requests...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 16),
                const Text('Error loading help requests', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.help_outline, size: 50, color: Colors.grey),
                SizedBox(height: 8),
                Text('No help requests nearby', style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 50,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) => _buildPostCard(posts[index]),
        );
      },
    );
  }

  Widget _buildPostCard(EmergencyPost post) {
    bool isHelpPost = post.type == 'help';

    Color getEmergencyColor() {
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

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              post: post,
              userLocation: _currentPosition,
              currentLocationName: _currentLocationName,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHelpPost ? Colors.grey : getEmergencyColor().withOpacity(0.2),
            width: isHelpPost ? 0.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: AppColors.blue.withOpacity(0.2),
                        child: Icon(Icons.person, size: 15, color: AppColors.blue),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          post.userName,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!isHelpPost) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: getEmergencyColor().withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Text(
                        post.emergencyType.toUpperCase(),
                        style: TextStyle(color: getEmergencyColor(), fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (post.description.isNotEmpty) ...[
                    Text(
                      post.description,
                      style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 13, fontWeight: FontWeight.w300),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getDistanceFromUser(post.latitude, post.longitude),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 9, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTimeAgo(post.timestamp),
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _showReportDialog(post.id),
                    child: const Text("Report", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.radio_button_checked, size: 12, color: Colors.green),
                          const SizedBox(width: 2),
                          Text("${post.trueVotes}", style: const TextStyle(color: Colors.green, fontSize: 10)),
                        ],
                      ),
                      const SizedBox(width: 6),
                      Row(
                        children: [
                          const Icon(Icons.radio_button_checked, size: 12, color: Colors.red),
                          const SizedBox(width: 2),
                          Text("${post.fakeVotes}", style: const TextStyle(color: Colors.red, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(Icons.location_on, size: 12, color: Colors.grey),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          post.locationName,
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNotificationTap() {
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null && message.data.isNotEmpty) {
        _showQuickPostDialogFromNotification(message.data);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (message.data.isNotEmpty) {
        _showQuickPostDialogFromNotification(message.data);
      }
    });
  }

  void _showQuickPostDialogFromNotification(Map<String, dynamic> data) {
    final intent = data['intent'] ?? 'alert';
    final emergencyType = data['emergencyType'];
    final description = data['description'];
    final fullText = data['fullText'] ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => QuickPostDialog(
        intent: intent,
        emergencyType: emergencyType,
        description: description,
        detectedText: fullText,
      ),
    );
  }
}
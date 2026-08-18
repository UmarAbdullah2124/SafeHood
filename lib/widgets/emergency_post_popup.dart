import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/app_colors.dart';
import '../models/emergency_type.dart';
import '../models/post_model.dart';
import '../services/firebase_service.dart';
import '../services/geocoding_service.dart';

class EmergencyPostPopup extends StatefulWidget {
  final String currentLocation;
  final String? preSelectedEmergency;
  final String? preFilledText;
  final Function(String, String, bool) onPostSubmitted;

  const EmergencyPostPopup({
    super.key,
    required this.currentLocation,
    this.preSelectedEmergency,
    this.preFilledText,
    required this.onPostSubmitted,
  });

  @override
  _EmergencyPostPopupState createState() => _EmergencyPostPopupState();
}

class _EmergencyPostPopupState extends State<EmergencyPostPopup>
    with SingleTickerProviderStateMixin {
  String? _selectedEmergency;
  String? _customAddress;
  bool _useCurrentLocation = true;
  late TabController _tabController;

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  LatLng? _currentPosition;
  LatLng? _customPosition;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedEmergency = widget.preSelectedEmergency;
    _descriptionController.text = widget.preFilledText ?? '';
    _getCurrentPosition();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentPosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      print('Error getting position: $e');
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a location to search'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    print('🔍 User searched for: "$query"');

    setState(() {
      _isSearching = true;
    });

    try {
      final result = await GeocodingService.getCoordinatesFromAddress(query);

      if (result != null) {
        setState(() {
          _customPosition = result;
          _customAddress = query;
          _isSearching = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Location found! ${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _isSearching = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Location not found. Try a different address or be more specific.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Search error: $e');
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _submitPost() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Posting your alert...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      if (_currentPosition == null && _useCurrentLocation) {
        await _getCurrentPosition();
      }

      User? user = FirebaseService.getCurrentUser();
      if (user == null) {
        await FirebaseService.signInAnonymously();
        user = FirebaseService.getCurrentUser();
      }

      String description = _descriptionController.text.trim();

      // For Alerts (tab index 0): if description is empty, use "No details provided"
      if (_tabController.index == 0) {
        if (description.isEmpty) {
          description = "No details provided";
        }
      } else {
        if (description.isEmpty) {
          description = _selectedEmergency != null
              ? 'Emergency assistance needed for $_selectedEmergency'
              : 'Emergency assistance needed';
        }
      }

      // Get firstName and lastName from Firestore
      String firstName = 'Community';
      String lastName = 'Member';
      String userName = 'Community Member';

      if (user != null) {
        try {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            firstName = userDoc['firstName'] ?? 'Community';
            lastName = userDoc['lastName'] ?? 'Member';
            userName = '$firstName $lastName';  // Full name for display
          } else {
            // Fallback to email prefix
            if (user.email != null && user.email!.contains('@')) {
              String emailPrefix = user.email!.split('@')[0];
              userName = emailPrefix;
              firstName = emailPrefix;
              lastName = '';
            }
          }
        } catch (e) {
          print('Error getting user data: $e');
          // Fallback to email prefix
          if (user.email != null && user.email!.contains('@')) {
            String emailPrefix = user.email!.split('@')[0];
            userName = emailPrefix;
            firstName = emailPrefix;
            lastName = '';
          }
        }
      }


      // Use custom position if available, otherwise use current position
      LatLng finalPosition = _useCurrentLocation
          ? (_currentPosition ?? LatLng(0, 0))
          : (_customPosition ?? LatLng(0, 0));

      String finalLocationName = _useCurrentLocation
          ? widget.currentLocation
          : (_customAddress ?? '');

      final post = EmergencyPost(
        id: '',
        userId: user?.uid ?? '',
        type: _tabController.index == 0 ? 'alert' : 'help',
        emergencyType: _selectedEmergency ?? 'Medical',
        description: description,
        locationName: finalLocationName,
        latitude: finalPosition.latitude,
        longitude: finalPosition.longitude,
        userName: userName,  // Full name
        firstName: firstName,  // First name only
        lastName: lastName,    // Last name only
        timestamp: DateTime.now(),
        trueVotes: 0,
        fakeVotes: 0,
        reportCount: 0,
      );

      await FirebaseService.createPost(post);

      Navigator.pop(context); // Close loading dialog
      Navigator.pop(context); // Close post popup

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _tabController.index == 0 ? '✓ Alert posted successfully!' : '✓ Help request posted successfully!',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );

      widget.onPostSubmitted(
          _selectedEmergency ?? 'Medical',
          finalLocationName,
          _useCurrentLocation
      );

    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error: ${e.toString()}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Container(
      height: mediaQuery.size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          _buildDragHandle(),
          _buildHeader(),
          _buildTabBar(),
          Flexible(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAlertTab(mediaQuery.viewInsets.bottom),
                _buildHelpTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(2)
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Text(
          'Make Emergency Post',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.blue,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        tabs: const [Tab(text: 'Alert'), Tab(text: 'Help')],
      ),
    );
  }

  Widget _buildAlertTab(double bottomPadding) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(left: 0, right: 0, top: 20, bottom: bottomPadding + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionTitle('Select emergency'),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: _buildEmergencyTypeList(),
            ),
          ),
          const SizedBox(height: 25),
          _buildSectionTitle('Description'),
          const SizedBox(height: 10),
          _buildDescriptionTextField(),
          const SizedBox(height: 25),
          _buildSectionTitle('Location'),
          const SizedBox(height: 15),
          _buildLocationOption(
            title: 'Use Current Location',
            subtitle: widget.currentLocation,
            icon: Icons.my_location,
            isSelected: _useCurrentLocation,
            onTap: () => setState(() => _useCurrentLocation = true),
          ),
          const SizedBox(height: 10),
          _buildLocationOption(
            title: 'Search Location',
            subtitle: _customAddress ?? 'Search for a location',
            icon: Icons.search,
            isSelected: !_useCurrentLocation,
            onTap: () => setState(() => _useCurrentLocation = false),
          ),
          if (!_useCurrentLocation) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter address or place name',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: AppColors.cardBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (value) => _searchLocation(value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _isSearching
                          ? Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue),
                            ),
                          ),
                        ),
                      )
                          : GestureDetector(
                        onTap: () => _searchLocation(_searchController.text),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.search, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                  if (_customPosition != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Location found!',
                                style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _customAddress ?? 'Selected location',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                          Text(
                            'Lat: ${_customPosition!.latitude.toStringAsFixed(6)}, Lng: ${_customPosition!.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(color: Colors.green, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildSendButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHelpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),
          _buildDescriptionTextField(),
          const SizedBox(height: 20),
          _buildSectionTitle('Location'),
          const SizedBox(height: 10),
          _buildLocationOption(
            title: 'Use Current Location',
            subtitle: widget.currentLocation,
            icon: Icons.my_location,
            isSelected: _useCurrentLocation,
            onTap: () => setState(() => _useCurrentLocation = true),
          ),
          const SizedBox(height: 10),
          _buildLocationOption(
            title: 'Search Location',
            subtitle: _customAddress ?? 'Search for a location',
            icon: Icons.search,
            isSelected: !_useCurrentLocation,
            onTap: () => setState(() => _useCurrentLocation = false),
          ),
          if (!_useCurrentLocation) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter address or place name',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: AppColors.cardBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (value) => _searchLocation(value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _isSearching
                          ? Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue),
                            ),
                          ),
                        ),
                      )
                          : GestureDetector(
                        onTap: () => _searchLocation(_searchController.text),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.search, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                  if (_customPosition != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Location found!',
                                style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _customAddress ?? 'Selected location',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                          Text(
                            'Lat: ${_customPosition!.latitude.toStringAsFixed(6)}, Lng: ${_customPosition!.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(color: Colors.green, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildRequestHelpButton(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }

  List<Widget> _buildEmergencyTypeList() {
    return EmergencyType.types.map((type) {
      bool isSelected = _selectedEmergency == type.name;
      return GestureDetector(
        onTap: () => setState(() => _selectedEmergency = type.name),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.blue.withOpacity(0.2) : AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.blue : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(type.icon, color: isSelected ? AppColors.blue : Colors.grey, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    type.name,
                    style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 14)
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: AppColors.blue, size: 20),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildDescriptionTextField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: _descriptionController,
        maxLines: 3,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Enter details...',
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: AppColors.cardBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildLocationOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue.withOpacity(0.1) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.blue : Colors.grey, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      title,
                      style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.w500)
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.blue : Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _selectedEmergency == null ? null : _submitPost,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.cardBg,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text(
              'Send Alert',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
          ),
        ),
      ),
    );
  }

  Widget _buildRequestHelpButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _descriptionController.text.isEmpty ? null : _submitPost,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.cardBg,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text(
              'Request Help',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
          ),
        ),
      ),
    );
  }
}
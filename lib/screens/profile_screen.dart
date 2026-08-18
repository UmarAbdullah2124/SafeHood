import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/screens/sign_in_screen.dart';
import 'package:untitled/utils/app_colors.dart';
import '../services/local_db.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  bool _loading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  // ================= FETCH USER DATA =================

  Future<void> _fetchUser() async {
    final user = _auth.currentUser;

    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Load from local database first
      final local = await LocalDB.getUser(user.uid);

      if (local != null) {
        setState(() {
          _userData = local;
          _loading = false;
        });
      }

      // Fetch from Firebase to get latest data
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (doc.exists) {
        final data = doc.data()!;

        // Merge with existing local data (preserve imagePath)
        final mergedData = {
          "id": user.uid,
          "firstName": data['firstName'] ?? '',
          "lastName": data['lastName'] ?? '',
          "email": data['email'] ?? '',
          "phone": data['phone'] ?? '',
          "cnic": data['cnic'] ?? '',
          "dob": data['dob'] ?? '',
          "imagePath": local?['imagePath'], // Keep local image path
        };

        // Save to local database
        await LocalDB.saveUser(mergedData);

        if (!mounted) return;

        setState(() {
          _userData = mergedData;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      print("Error fetching user: $e");
      setState(() => _loading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load profile")),
        );
      }
    }
  }

  // ================= REFRESH DATA =================

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await _fetchUser();
    setState(() => _isRefreshing = false);
  }

  // ================= PROFILE IMAGE =================

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.black,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera, color: Colors.white),
            title: const Text("Camera", style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.image, color: Colors.white),
            title: const Text("Gallery", style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;

    // Save image locally
    final dir = await getApplicationDocumentsDirectory();
    final fileName = "profile_${_auth.currentUser?.uid}.jpg";
    final savedImage = await File(picked.path).copy('${dir.path}/$fileName');

    final user = _auth.currentUser;
    if (user == null) return;

    // Update local database with new image path
    final updatedData = {
      "id": user.uid,
      "firstName": _userData?['firstName'] ?? '',
      "lastName": _userData?['lastName'] ?? '',
      "email": _userData?['email'] ?? '',
      "phone": _userData?['phone'] ?? '',
      "cnic": _userData?['cnic'] ?? '',
      "dob": _userData?['dob'] ?? '',
      "imagePath": savedImage.path,
    };

    await LocalDB.saveUser(updatedData);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path', savedImage.path);

    setState(() {
      _userData = updatedData;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile picture updated"), backgroundColor: Colors.green),
      );
    }
  }

  // ================= LOGOUT =================

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        backgroundColor: Colors.grey.shade900,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(color: Colors.white70),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog

              await _auth.signOut();

              if (!mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const SignInScreen(),
                ),
                    (route) => false,
              );
            },
            child: const Text(
              "Logout",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true, // This centers the title
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading profile...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _header(),
              const SizedBox(height: 20),
              _infoCard(),
              const SizedBox(height: 20),
              _supportCard(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ================= HEADER =================

  Widget _header() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 280,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/map_dark.png"),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(
          height: 280,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned(
          bottom: -1,
          child: Container(
            height: 80,
            width: MediaQuery.of(context).size.width,
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          child: Column(
            children: [
              _avatar(),
              const SizedBox(height: 12),
              _name(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar() {
    final path = _userData?['imagePath'];

    return Stack(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundImage: path != null && File(path).existsSync()
              ? FileImage(File(path))
              : null,
          backgroundColor: AppColors.blue,
          child: path == null
              ? const Icon(Icons.person, size: 50, color: Colors.white)
              : null,
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _name() {
    return Column(
      children: [
        Text(
          "${_userData?['firstName'] ?? 'Unknown'} ${_userData?['lastName'] ?? 'User'}",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified, size: 16, color: Colors.green),
              SizedBox(width: 6),
              Text(
                "Biometric Verified",
                style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= INFO CARD =================

  Widget _infoCard() {
    return _card([
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.person_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text(
              "Personal Information",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      const Divider(color: Colors.white24, height: 1),
      _row(Icons.email, "Email", _userData?['email']),
      _row(Icons.phone, "Phone Number", _userData?['phone']),
      _row(Icons.credit_card, "CNIC Number", _userData?['cnic']),
      _row(Icons.calendar_today, "Date of Birth", _userData?['dob']),
    ]);
  }

  // ================= SUPPORT CARD =================

  Widget _supportCard() {
    return _card([
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.support_agent, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text(
              "Support",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      const Divider(color: Colors.white24, height: 1),
      _row(Icons.help_outline, "Help & Support", "", showArrow: true),
      _row(Icons.mail_outline, "Contact Us", "", showArrow: true),
      _row(Icons.privacy_tip, "Privacy Policy", "", showArrow: true),
      const Divider(color: Colors.white24, height: 1),
      ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text(
          "Logout",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.red),
        onTap: _logout,
      ),
    ]);
  }

  // ================= HELPER WIDGETS =================

  Widget _card(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(children: children),
    );
  }

  Widget _row(IconData icon, String label, String? value, {bool showArrow = false}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 22),
      title: Text(
        label,
        style: const TextStyle(color: Colors.grey, fontSize: 14),
      ),
      subtitle: value != null && value.isNotEmpty
          ? Text(
        value,
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
      )
          : const Text(
        "Not provided",
        style: TextStyle(color: Colors.grey, fontSize: 14, fontStyle: FontStyle.italic),
      ),
      trailing: showArrow ? const Icon(Icons.chevron_right, color: Colors.grey) : null,
      onTap: showArrow
          ? () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$label feature coming soon")),
        );
      }
          : null,
    );
  }
}
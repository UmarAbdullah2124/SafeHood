import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserPostProfile {
  final String userId;
  final String firstName;
  final String lastName;
  final String userName;

  const UserPostProfile({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.userName,
  });
}

class UserProfileService {
  static Future<UserPostProfile> resolveForPost() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const UserPostProfile(
        userId: '',
        firstName: 'Community',
        lastName: 'Member',
        userName: 'Community Member',
      );
    }

    String firstName = 'Community';
    String lastName = 'Member';
    String userName = 'Community Member';

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        firstName = userDoc['firstName'] ?? 'Community';
        lastName = userDoc['lastName'] ?? 'Member';
        userName = '$firstName $lastName'.trim();
      } else if (user.email != null && user.email!.contains('@')) {
        final emailPrefix = user.email!.split('@')[0];
        userName = emailPrefix;
        firstName = emailPrefix;
        lastName = '';
      }
    } catch (e) {
      print('Error loading user profile for post: $e');
      if (user.email != null && user.email!.contains('@')) {
        final emailPrefix = user.email!.split('@')[0];
        userName = emailPrefix;
        firstName = emailPrefix;
        lastName = '';
      }
    }

    return UserPostProfile(
      userId: user.uid,
      firstName: firstName,
      lastName: lastName,
      userName: userName,
    );
  }
}

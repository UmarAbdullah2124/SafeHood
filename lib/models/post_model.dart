import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyPost {
  final String id;
  final String userId;
  final String type;
  final String emergencyType;
  final String description;
  final String locationName;
  final double latitude;
  final double longitude;
  final String userName;
  final String firstName;
  final String lastName;
  final DateTime timestamp;
  final int trueVotes;
  final int fakeVotes;
  final int reportCount;

  EmergencyPost({
    required this.id,
    required this.userId,
    required this.type,
    required this.emergencyType,
    required this.description,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.userName,
    required this.firstName,
    required this.lastName,
    required this.timestamp,
    required this.trueVotes,
    required this.fakeVotes,
    required this.reportCount,
  });

  // Helper method to get full name
  String get fullName {
    if (firstName.isEmpty && lastName.isEmpty) return 'Community Member';
    if (lastName.isEmpty) return firstName;
    return '$firstName $lastName';
  }

  // Helper method to get initials
  String get initials {
    String firstInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    String lastInitial = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';

    if (firstInitial.isEmpty && lastInitial.isEmpty) return '?';
    if (lastInitial.isEmpty) return firstInitial;
    return '$firstInitial$lastInitial';
  }

  // NEW: Helper to get author ID (for compatibility with chat)
  String get authorId => userId;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'emergencyType': emergencyType,
      'description': description,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'userName': userName,
      'firstName': firstName,
      'lastName': lastName,
      'timestamp': Timestamp.fromDate(timestamp),
      'trueVotes': trueVotes,
      'fakeVotes': fakeVotes,
      'reportCount': reportCount,
    };
  }

  factory EmergencyPost.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return EmergencyPost(
      id: doc.id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      emergencyType: map['emergencyType'] ?? '',
      description: map['description'] ?? '',
      locationName: map['locationName'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      userName: map['userName'] ?? 'Anonymous',
      firstName: map['firstName'] ?? 'User',
      lastName: map['lastName'] ?? '',
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      trueVotes: map['trueVotes'] ?? 0,
      fakeVotes: map['fakeVotes'] ?? 0,
      reportCount: map['reportCount'] ?? 0,
    );
  }

  factory EmergencyPost.fromMap(String id, Map<String, dynamic> map) {
    return EmergencyPost(
      id: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      emergencyType: map['emergencyType'] ?? '',
      description: map['description'] ?? '',
      locationName: map['locationName'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      userName: map['userName'] ?? 'Anonymous',
      firstName: map['firstName'] ?? 'User',
      lastName: map['lastName'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      trueVotes: map['trueVotes'] ?? 0,
      fakeVotes: map['fakeVotes'] ?? 0,
      reportCount: map['reportCount'] ?? 0,
    );
  }

  Null get isResolved => null;
}
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/community_message.dart';
import '../utils/constants.dart';
import '../utils/distance_utils.dart';

/// Geofenced community chat: messages are stored with location and only
/// shown to users within [Constants.communityChatRadiusKm].
class CommunityChatService {
  static const String messagesCollection = 'community_messages';
  static const String fcmTopicPrefix = 'community_chat';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  /// ~5 km grid cells for FCM topic grouping (aligned with chat radius).
  static const double _cellDegrees = 0.045;

  static String computeGeoCell(double latitude, double longitude) {
    final latCell = (latitude / _cellDegrees).floor();
    final lonCell = (longitude / _cellDegrees).floor();
    return '${latCell}_$lonCell';
  }

  static String fcmTopicForCell(String geoCell) => '${fcmTopicPrefix}_$geoCell';

  static Stream<List<CommunityMessage>> nearbyMessagesStream({
    required double latitude,
    required double longitude,
    double radiusKm = Constants.communityChatRadiusKm,
  }) {
    final latDelta = radiusKm / 111.0;
    final lonDelta = radiusKm / (111.0 * cos(latitude * pi / 180));

    return _firestore
        .collection(messagesCollection)
        .where('latitude', isGreaterThanOrEqualTo: latitude - latDelta)
        .where('latitude', isLessThanOrEqualTo: latitude + latDelta)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => CommunityMessage.fromFirestore(doc))
          .where((message) {
        if (message.latitude == 0 && message.longitude == 0) {
          return false;
        }
        final distance = DistanceUtils.calculateDistance(
          latitude,
          longitude,
          message.latitude,
          message.longitude,
        );
        return distance <= radiusKm;
      }).toList();

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  static Stream<CommunityChatSummary> nearbySummaryStream({
    required double latitude,
    required double longitude,
    double radiusKm = Constants.communityChatRadiusKm,
  }) {
    return nearbyMessagesStream(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    ).map(CommunityChatSummary.fromMessages);
  }

  static Future<String> _resolveDisplayName() async {
    final user = _auth.currentUser;
    if (user == null) return 'Community Member';

    try {
      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final first = userDoc.data()?['firstName'] as String? ?? '';
        final last = userDoc.data()?['lastName'] as String? ?? '';
        final combined = '$first $last'.trim();
        if (combined.isNotEmpty) return combined;
      }
    } catch (_) {}

    final emailName = user.email?.split('@').first;
    if (emailName != null && emailName.isNotEmpty) {
      return emailName[0].toUpperCase() + emailName.substring(1);
    }
    return 'Community Member';
  }

  static Future<void> sendMessage({
    required String text,
    required double latitude,
    required double longitude,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    var user = _auth.currentUser;
    if (user == null) {
      await _auth.signInAnonymously();
      user = _auth.currentUser;
    }
    if (user == null) {
      throw StateError('Unable to authenticate for community chat');
    }

    final senderName = await _resolveDisplayName();
    final now = DateTime.now();
    final geoCell = computeGeoCell(latitude, longitude);

    final message = CommunityMessage(
      id: '',
      text: trimmed,
      senderId: user.uid,
      senderName: senderName,
      timestamp: now,
      latitude: latitude,
      longitude: longitude,
      geoCell: geoCell,
    );

    await _firestore.collection(messagesCollection).add(message.toMap());
  }

  static Future<void> sendMediaMessage({
    required File file,
    required CommunityMessageType type,
    required double latitude,
    required double longitude,
    String caption = '',
  }) async {
    var user = _auth.currentUser;
    if (user == null) {
      await _auth.signInAnonymously();
      user = _auth.currentUser;
    }
    if (user == null) {
      throw StateError('Unable to authenticate for community chat');
    }

    final ext = type == CommunityMessageType.video ? 'mp4' : 'jpg';
    final path = 'community_messages/${_uuid.v4()}.$ext';
    final ref = _storage.ref().child(path);
    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    final senderName = await _resolveDisplayName();
    final now = DateTime.now();
    final geoCell = computeGeoCell(latitude, longitude);

    final message = CommunityMessage(
      id: '',
      text: caption,
      senderId: user.uid,
      senderName: senderName,
      timestamp: now,
      latitude: latitude,
      longitude: longitude,
      geoCell: geoCell,
      type: type,
      mediaUrl: url,
    );

    await _firestore.collection(messagesCollection).add(message.toMap());
  }

  static Future<void> markCommunityChatRead() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({
      'communityChatLastReadAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<int> nearbyUnreadCountStream({
    required double latitude,
    required double longitude,
    double radiusKm = Constants.communityChatRadiusKm,
  }) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return nearbyMessagesStream(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    ).asyncMap((messages) async {
      if (messages.isEmpty) return 0;

      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final lastRead = userDoc.data()?['communityChatLastReadAt'];
      if (lastRead is! Timestamp) {
        return messages.length.clamp(0, 99);
      }

      final readAt = lastRead.toDate();
      final unread = messages
          .where((m) => m.timestamp.isAfter(readAt))
          .length;
      return unread.clamp(0, 99);
    });
  }
}

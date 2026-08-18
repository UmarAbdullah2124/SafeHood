import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import '../models/post_model.dart';
import 'community_chat_service.dart';
import 'nearby_post_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _showRemoteMessageNotification(message);
}

Future<void> _showRemoteMessageNotification(RemoteMessage message) async {
  final data = message.data;
  final type = data['type'] ?? 'alert';
  final isAlert = type == 'alert';
  final emergencyType = data['emergencyType'] ?? 'Emergency';
  final description = data['description'] ?? '';
  final locationName = data['locationName'] ?? '';
  final postId = data['postId'] ?? '';

  final title = message.notification?.title ??
      (isAlert ? 'New Alert Nearby' : 'Help Request Nearby');

  await NearbyPostNotificationService.instance.ensureInitialized();

  final post = EmergencyPost(
      id: postId,
      userId: '',
      type: type,
      emergencyType: emergencyType,
      description: description,
      locationName: locationName,
      latitude: 0,
      longitude: 0,
      userName: '',
      firstName: '',
      lastName: '',
      timestamp: DateTime.now(),
      trueVotes: 0,
      fakeVotes: 0,
      reportCount: 0,
    );

  await NearbyPostNotificationService.instance.showPostNotification(
    post: post,
    type: type,
    titleOverride: title,
  );
}

class MessagingService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;
  static String? _subscribedChatGeoCell;
  static String? _subscribedPostGeoCell;

  static const String postTopicPrefix = 'safehood_posts';

  static String postTopicForCell(String geoCell) => '${postTopicPrefix}_$geoCell';

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await NearbyPostNotificationService.instance.ensureInitialized();

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final token = await _messaging.getToken();
    await _persistToken(token);
    debugPrint('FCM token: ${token ?? 'none'}');

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        final refreshed = await _messaging.getToken();
        await _persistToken(refreshed);
      }
    });

    _messaging.onTokenRefresh.listen(_persistToken);

    FirebaseMessaging.onMessage.listen((message) async {
      debugPrint('FCM foreground message: ${message.messageId}');
      await _showRemoteMessageNotification(message);
    });
  }

  /// Subscribe to FCM topics for community chat in the user's map cell.
  static Future<void> updateCommunityChatTopic({
    required double latitude,
    required double longitude,
  }) async {
    final geoCell = CommunityChatService.computeGeoCell(latitude, longitude);
    if (_subscribedChatGeoCell == geoCell) return;

    try {
      if (_subscribedChatGeoCell != null) {
        await _messaging.unsubscribeFromTopic(
          CommunityChatService.fcmTopicForCell(_subscribedChatGeoCell!),
        );
      }
      await _messaging.subscribeToTopic(
        CommunityChatService.fcmTopicForCell(geoCell),
      );
      _subscribedChatGeoCell = geoCell;
      debugPrint('Subscribed to chat topic: ${CommunityChatService.fcmTopicForCell(geoCell)}');
    } catch (e) {
      debugPrint('Chat topic subscribe failed: $e');
    }
  }

  /// Subscribe to FCM topic for nearby alert/help push (requires Cloud Function sender).
  static Future<void> updatePostAlertTopic({
    required double latitude,
    required double longitude,
  }) async {
    final geoCell = CommunityChatService.computeGeoCell(latitude, longitude);
    if (_subscribedPostGeoCell == geoCell) return;

    try {
      if (_subscribedPostGeoCell != null) {
        await _messaging.unsubscribeFromTopic(
          postTopicForCell(_subscribedPostGeoCell!),
        );
      }
      await _messaging.subscribeToTopic(postTopicForCell(geoCell));
      _subscribedPostGeoCell = geoCell;
      debugPrint('Subscribed to post alert topic: ${postTopicForCell(geoCell)}');
    } catch (e) {
      debugPrint('Post alert topic subscribe failed: $e');
    }
  }

  static Future<void> _persistToken(String? token) async {
    if (token == null || token.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': token,
      'fcmPlatform': Platform.operatingSystem,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

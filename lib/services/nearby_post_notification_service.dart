import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BuildContext, Color, MaterialPageRoute, Navigator;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../main.dart' show rootNavigatorKey;
import '../models/post_model.dart';
import '../models/community_message.dart';
import '../models/direct_message.dart';
import '../screens/community_chat_screen.dart';
import '../screens/direct_chat_screen.dart';
import '../screens/post_detail_screen.dart';
import '../utils/constants.dart';
import 'firebase_service.dart';
import 'community_chat_service.dart';
import 'direct_chat_service.dart';

/// Shows local notifications when new alert/help posts appear nearby.
/// Works while the app process is alive (including foreground service) — no paid backend required.
class NearbyPostNotificationService {
  NearbyPostNotificationService._();
  static final NearbyPostNotificationService instance =
  NearbyPostNotificationService._();

  static const _channelId = 'safehood_emergency_alerts_v1';
  static const _channelName = 'Nearby Alerts & Help';
  static const _alertChannelId = 'safehood_emergency_alerts_alert_v1';
  static const _alertChannelName = 'Emergency Alerts';
  static const _communityChatChannelId = 'safehood_community_chat_v1';
  static const _communityChatChannelName = 'Community Chat';
  static const _directChatChannelId = 'safehood_direct_chat_v1';
  static const _directChatChannelName = 'Direct Messages';

  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  StreamSubscription<List<EmergencyPost>>? _alertSub;
  StreamSubscription<List<EmergencyPost>>? _helpSub;
  StreamSubscription<List<CommunityMessage>>? _communityChatSub;
  StreamSubscription<List<DirectChatPreview>>? _directChatSub;
  final Set<String> _seenKeys = {};
  bool _alertBootstrapped = false;
  bool _helpBootstrapped = false;
  bool _communityChatBootstrapped = false;
  bool _directChatBootstrapped = false;
  bool _initialized = false;
  double? _latitude;
  double? _longitude;
  int _notificationId = 2000;

  Future<void> ensureInitialized() async {
    if (_initialized) return;

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Regular channel for help notifications (default sound)
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Notifications for nearby help requests',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ));

    // Alert channel with beeping sound for emergencies
    await android?.createNotificationChannel(AndroidNotificationChannel(
      _alertChannelId,
      _alertChannelName,
      description: 'Urgent beeping alerts for emergencies',
      importance: Importance.max,
      //priority: Priority.high,
      playSound: true,
      enableVibration: true,
      sound: const RawResourceAndroidNotificationSound('alert_beep'),
    ));

    // Community chat channel
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _communityChatChannelId,
      _communityChatChannelName,
      description: 'Notifications for nearby community messages',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ));

    // Direct chat channel
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _directChatChannelId,
      _directChatChannelName,
      description: 'Notifications for direct messages',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ));

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    if (payload == 'community_chat') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityChatScreen(
            latitude: _latitude ?? 0,
            longitude: _longitude ?? 0,
          ),
        ),
      );
    } else if (payload.startsWith('direct_chat:')) {
      final parts = payload.split(':');
      if (parts.length >= 3) {
        final chatId = parts[1];
        final otherUserName = parts[2];
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DirectChatScreen(
              chatId: chatId,
              otherUserName: otherUserName,
            ),
          ),
        );
      }
    } else if (payload.startsWith('post:')) {
      final parts = payload.split(':');
      if (parts.length >= 3) {
        final postId = parts[1];
        final type = parts[2];
        _handlePostTap(context, postId, type);
      }
    }
  }

  Future<void> _handlePostTap(
    BuildContext context,
    String postId,
    String type,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();
      if (doc.exists) {
        final post = EmergencyPost.fromFirestore(doc);
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(
              post: post,
              userLocation: LatLng(_latitude ?? 0, _longitude ?? 0),
              currentLocationName: '', // Could be improved if needed
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to post from notification: $e');
    }
  }

  Future<void> updateLocation(double latitude, double longitude) async {
    await ensureInitialized();

    final moved = _latitude == null ||
        _longitude == null ||
        (latitude - _latitude!).abs() > 0.001 ||
        (longitude - _longitude!).abs() > 0.001;

    _latitude = latitude;
    _longitude = longitude;

    if (!moved && _alertSub != null) return;

    await _restartListeners();
  }

  Future<void> stop() async {
    await _alertSub?.cancel();
    await _helpSub?.cancel();
    await _communityChatSub?.cancel();
    await _directChatSub?.cancel();
    _alertSub = null;
    _helpSub = null;
    _communityChatSub = null;
    _directChatSub = null;
    _alertBootstrapped = false;
    _helpBootstrapped = false;
    _communityChatBootstrapped = false;
    _directChatBootstrapped = false;
    _seenKeys.clear();
  }

  Future<void> _restartListeners() async {
    await _alertSub?.cancel();
    await _helpSub?.cancel();
    await _communityChatSub?.cancel();
    await _directChatSub?.cancel();
    _alertBootstrapped = false;
    _helpBootstrapped = false;
    _communityChatBootstrapped = false;
    _directChatBootstrapped = false;
    _seenKeys.clear();

    final lat = _latitude;
    final lon = _longitude;
    if (lat == null || lon == null) return;

    _alertSub = FirebaseService.getNearbyPostsStream(
      'alert',
      lat,
      lon,
      Constants.communityChatRadiusKm,
    ).listen(
          (posts) => _handlePosts(posts, 'alert'),
      onError: (e) => debugPrint('Alert notification stream error: $e'),
    );

    _helpSub = FirebaseService.getNearbyPostsStream(
      'help',
      lat,
      lon,
      Constants.communityChatRadiusKm,
    ).listen(
          (posts) => _handlePosts(posts, 'help'),
      onError: (e) => debugPrint('Help notification stream error: $e'),
    );

    _communityChatSub = CommunityChatService.nearbyMessagesStream(
      latitude: lat,
      longitude: lon,
    ).listen(
      _handleCommunityMessages,
      onError: (e) => debugPrint('Community chat notification error: $e'),
    );

    _directChatSub = DirectChatService.myChatsStream().listen(
      _handleDirectChats,
      onError: (e) => debugPrint('Direct chat notification error: $e'),
    );
  }

  Future<void> _handleCommunityMessages(List<CommunityMessage> messages) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (!_communityChatBootstrapped) {
      for (final msg in messages) {
        _seenKeys.add(_key('comm', msg.id));
      }
      _communityChatBootstrapped = true;
      return;
    }

    for (final msg in messages) {
      final key = _key('comm', msg.id);
      if (_seenKeys.contains(key)) continue;
      _seenKeys.add(key);

      if (currentUserId != null && msg.senderId == currentUserId) continue;

      await showChatNotification(
        title: 'Community: ${msg.senderName}',
        body: msg.text.isNotEmpty
            ? msg.text
            : (msg.type == CommunityMessageType.image ? '📷 Photo' : '🎥 Video'),
        payload: 'community_chat',
        channelId: _communityChatChannelId,
        channelName: _communityChatChannelName,
        color: const Color(0xFF4CAF50),
      );
    }
  }

  Future<void> _handleDirectChats(List<DirectChatPreview> chats) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (!_directChatBootstrapped) {
      for (final chat in chats) {
        if (chat.lastMessageAt != null) {
          _seenKeys.add(_key('direct',
              '${chat.chatId}_${chat.lastMessageAt!.millisecondsSinceEpoch}'));
        }
      }
      _directChatBootstrapped = true;
      return;
    }

    for (final chat in chats) {
      if (chat.lastMessageAt == null) continue;
      final key = _key('direct',
          '${chat.chatId}_${chat.lastMessageAt!.millisecondsSinceEpoch}');
      if (_seenKeys.contains(key)) continue;
      _seenKeys.add(key);

      try {
        final lastMsgDoc = await FirebaseFirestore.instance
            .collection(DirectChatService.chatsCollection)
            .doc(chat.chatId)
            .collection(DirectChatService.messagesSubcollection)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (lastMsgDoc.docs.isNotEmpty) {
          final msg = DirectMessage.fromFirestore(lastMsgDoc.docs.first);
          if (msg.senderId != currentUserId) {
            await showChatNotification(
              title: msg.senderName,
              body: msg.text.isNotEmpty
                  ? msg.text
                  : (msg.type == DirectMessageType.image
                  ? '📷 Photo'
                  : '🎥 Video'),
              payload: 'direct_chat:${chat.chatId}:${msg.senderName}',
              channelId: _directChatChannelId,
              channelName: _directChatChannelName,
              color: const Color(0xFF9C27B0),
            );
          }
        }
      } catch (e) {
        debugPrint('Error fetching last direct message for notification: $e');
      }
    }
  }

  Future<void> showChatNotification({
    required String title,
    required String body,
    required String payload,
    required String channelId,
    required String channelName,
    required Color color,
  }) async {
    await ensureInitialized();

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      color: color,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notifications.show(
      _notificationId++,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> _handlePosts(List<EmergencyPost> posts, String type) async {
    final bootstrapped =
    type == 'alert' ? _alertBootstrapped : _helpBootstrapped;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (!bootstrapped) {
      for (final post in posts) {
        _seenKeys.add(_key(type, post.id));
      }
      if (type == 'alert') {
        _alertBootstrapped = true;
      } else {
        _helpBootstrapped = true;
      }
      return;
    }

    for (final post in posts) {
      final key = _key(type, post.id);
      if (_seenKeys.contains(key)) continue;
      _seenKeys.add(key);

      if (currentUserId != null && post.userId == currentUserId) continue;

      await showPostNotification(post: post, type: type);
    }
  }

  String _key(String type, String postId) => '$type:$postId';

  String _getNotificationBody(EmergencyPost post, String type) {
    if (type == 'help') {
      // For help requests, show the user's actual description
      if (post.description.isNotEmpty) {
        if (post.locationName.isNotEmpty) {
          return '${post.description}\n${post.locationName}';
        }
        return post.description;
      }
      return post.locationName.isNotEmpty
          ? 'Help needed\n${post.locationName}'
          : 'Help needed nearby';
    } else {
      // For alerts, show emergency type and location
      final emergencyType = post.emergencyType.isNotEmpty
          ? post.emergencyType
          : 'Emergency';
      return post.locationName.isNotEmpty
          ? '$emergencyType\n${post.locationName}'
          : emergencyType;
    }
  }

  Future<void> showPostNotification({
    required EmergencyPost post,
    required String type,
    String? titleOverride,
    String? bodyOverride,
  }) async {
    await ensureInitialized();

    final isAlert = type == 'alert';
    final title = titleOverride ??
        (isAlert ? '🚨 ALERT' : 'Help Request Nearby');
    final body = bodyOverride ?? _getNotificationBody(post, type);

    // Use different channel for alerts vs help
    final channelId = isAlert ? _alertChannelId : _channelId;
    final channelName = isAlert ? _alertChannelName : _channelName;

    NotificationDetails details;

    if (isAlert) {
      // Alert notification with beeping sound
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Urgent beeping alerts for emergencies',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        sound: const RawResourceAndroidNotificationSound('alert_beep'),
        timeoutAfter: 30000, // Auto dismiss after 30 seconds
        color: const Color(0xFFE53935),
      );

      details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
    } else {
      // Help notification with default sound
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Notifications for nearby help requests',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        color: const Color(0xFF1E88E5),
      );

      details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
    }

    await _notifications.show(
      _notificationId++,
      title,
      body,
      details,
      payload: 'post:${post.id}:$type',
    );
  }
}
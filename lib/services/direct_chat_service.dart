import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/direct_message.dart';

class DirectChatService {
  static const String chatsCollection = 'direct_chats';
  static const String messagesSubcollection = 'messages';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  static String chatIdFor(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  static Future<String> _myDisplayName() async {
    final user = _auth.currentUser;
    if (user == null) return 'Member';
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final first = doc.data()?['firstName'] as String? ?? '';
        final last = doc.data()?['lastName'] as String? ?? '';
        final name = '$first $last'.trim();
        if (name.isNotEmpty) return name;
      }
    } catch (_) {}
    final email = user.email?.split('@').first;
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase() + email.substring(1);
    }
    return 'Member';
  }

  static Future<String> ensureChat({
    required String otherUserId,
    required String otherUserName,
    String? linkedPostId,
  }) async {
    final me = _auth.currentUser;
    if (me == null) {
      throw StateError('Sign in required to start a chat');
    }
    if (me.uid == otherUserId) {
      throw StateError('Cannot chat with yourself');
    }

    final chatId = chatIdFor(me.uid, otherUserId);
    final myName = await _myDisplayName();

    final preview = linkedPostId != null
        ? 'Chat about alert/help'
        : 'Chat started';

    await _firestore.collection(chatsCollection).doc(chatId).set({
      'participants': [me.uid, otherUserId],
      'participantNames': {
        me.uid: myName,
        otherUserId: otherUserName,
      },
      if (linkedPostId != null) 'linkedPostId': linkedPostId,
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return chatId;
  }

  static Stream<List<DirectChatPreview>> myChatsStream() {
    final me = _auth.currentUser;
    if (me == null) return Stream.value([]);

    return _firestore
        .collection(chatsCollection)
        .where('participants', arrayContains: me.uid)
        .snapshots()
        .asyncMap((snapshot) async {
      final userDoc =
          await _firestore.collection('users').doc(me.uid).get();
      final lastReadMap =
          userDoc.data()?['directChatLastRead'] as Map<String, dynamic>? ?? {};

      final chats = snapshot.docs.map((doc) {
        final data = doc.data();
        final participants =
            List<String>.from(data['participants'] as List? ?? []);
        final names =
            Map<String, dynamic>.from(data['participantNames'] as Map? ?? {});
        final otherId =
            participants.firstWhere((id) => id != me.uid, orElse: () => '');
        final otherName =
            names[otherId] as String? ?? 'Community Member';
        final lastAt = data['lastMessageAt'];
        final lastMessageAt =
            lastAt is Timestamp ? lastAt.toDate() : null;
        final lastRead = lastReadMap[doc.id];
        var unread = 0;
        if (lastMessageAt != null && lastRead is Timestamp) {
          if (lastMessageAt.isAfter(lastRead.toDate())) unread = 1;
        } else if (lastMessageAt != null && lastRead == null) {
          unread = 1;
        }

        return DirectChatPreview(
          chatId: doc.id,
          otherUserId: otherId,
          otherUserName: otherName,
          lastMessage: data['lastMessage'] as String? ?? '',
          lastMessageAt: lastMessageAt,
          unreadCount: unread,
        );
      }).toList();

      chats.sort((a, b) {
        final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return chats;
    });
  }

  static Stream<List<DirectMessage>> messagesStream(String chatId) {
    return _firestore
        .collection(chatsCollection)
        .doc(chatId)
        .collection(messagesSubcollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => DirectMessage.fromFirestore(doc))
            .toList());
  }

  static Future<void> _updateChatMeta(
    String chatId,
    String preview,
  ) async {
    await _firestore.collection(chatsCollection).doc(chatId).set({
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> sendTextMessage({
    required String chatId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final senderName = await _myDisplayName();
    final message = DirectMessage(
      id: '',
      senderId: user.uid,
      senderName: senderName,
      text: trimmed,
      type: DirectMessageType.text,
      timestamp: DateTime.now(),
    );

    await _firestore
        .collection(chatsCollection)
        .doc(chatId)
        .collection(messagesSubcollection)
        .add(message.toMap());

    await _updateChatMeta(chatId, trimmed);
  }

  static Future<void> sendMediaMessage({
    required String chatId,
    required File file,
    required DirectMessageType type,
    String caption = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ext = type == DirectMessageType.video ? 'mp4' : 'jpg';
    final path =
        'direct_chats/$chatId/${_uuid.v4()}.$ext';
    final ref = _storage.ref().child(path);
    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    final senderName = await _myDisplayName();
    final preview =
        type == DirectMessageType.video ? 'Video' : 'Photo';
    final message = DirectMessage(
      id: '',
      senderId: user.uid,
      senderName: senderName,
      text: caption,
      type: type,
      mediaUrl: url,
      timestamp: DateTime.now(),
    );

    await _firestore
        .collection(chatsCollection)
        .doc(chatId)
        .collection(messagesSubcollection)
        .add(message.toMap());

    await _updateChatMeta(
      chatId,
      caption.isNotEmpty ? caption : preview,
    );
  }

  static Future<void> markChatRead(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({
      'directChatLastRead': {chatId: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }
}

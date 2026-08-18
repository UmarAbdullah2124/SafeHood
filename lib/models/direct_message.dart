import 'package:cloud_firestore/cloud_firestore.dart';

enum DirectMessageType { text, image, video }

class DirectMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DirectMessageType type;
  final String? mediaUrl;
  final DateTime timestamp;

  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.type,
    this.mediaUrl,
    required this.timestamp,
  });

  factory DirectMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final ts = data['timestamp'];
    final typeRaw = data['type'] as String? ?? 'text';
    return DirectMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Member',
      text: data['text'] as String? ?? '',
      type: DirectMessageType.values.firstWhere(
        (t) => t.name == typeRaw,
        orElse: () => DirectMessageType.text,
      ),
      mediaUrl: data['mediaUrl'] as String?,
      timestamp: ts is Timestamp
          ? ts.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'type': type.name,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class DirectChatPreview {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const DirectChatPreview({
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });
}

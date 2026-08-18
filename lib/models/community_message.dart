import 'package:cloud_firestore/cloud_firestore.dart';

enum CommunityMessageType { text, image, video }

class CommunityMessage {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String geoCell;
  final CommunityMessageType type;
  final String? mediaUrl;

  const CommunityMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.geoCell,
    this.type = CommunityMessageType.text,
    this.mediaUrl,
  });

  factory CommunityMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final ts = data['timestamp'];
    return CommunityMessage(
      id: doc.id,
      text: data['text'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Community Member',
      timestamp: ts is Timestamp
          ? ts.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      geoCell: data['geoCell'] as String? ?? '',
      type: CommunityMessageType.values.firstWhere(
        (t) => t.name == (data['type'] as String? ?? 'text'),
        orElse: () => CommunityMessageType.text,
      ),
      mediaUrl: data['mediaUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': Timestamp.fromDate(timestamp),
      'latitude': latitude,
      'longitude': longitude,
      'geoCell': geoCell,
      'type': type.name,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
    };
  }
}

class CommunityChatSummary {
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String lastSenderName;

  const CommunityChatSummary({
    required this.lastMessage,
    this.lastMessageAt,
    this.lastSenderName = '',
  });

  factory CommunityChatSummary.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const CommunityChatSummary(lastMessage: 'No messages nearby');
    }
    final ts = data['lastMessageAt'];
    return CommunityChatSummary(
      lastMessage: data['lastMessage'] as String? ?? 'No messages nearby',
      lastMessageAt: ts is Timestamp ? ts.toDate() : null,
      lastSenderName: data['lastSenderName'] as String? ?? '',
    );
  }

  factory CommunityChatSummary.fromMessages(List<CommunityMessage> messages) {
    if (messages.isEmpty) {
      return const CommunityChatSummary(
        lastMessage: 'No messages nearby — say hello',
      );
    }
    final last = messages.last;
    return CommunityChatSummary(
      lastMessage: last.text,
      lastMessageAt: last.timestamp,
      lastSenderName: last.senderName,
    );
  }
}

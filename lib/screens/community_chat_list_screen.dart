import 'package:flutter/material.dart';
import '../models/community_message.dart';
import '../models/direct_message.dart';
import '../services/community_chat_service.dart';
import '../services/community_location_service.dart';
import '../services/direct_chat_service.dart';
import '../services/messaging_service.dart';
import '../utils/app_colors.dart';
import '../utils/chat_ui_styles.dart';
import '../utils/constants.dart';
import 'community_chat_screen.dart';
import 'direct_chat_screen.dart';

/// Full-screen community hub: pinned geofenced group chat + DMs (newest first).
class CommunityChatListScreen extends StatefulWidget {
  final double latitude;
  final double longitude;

  const CommunityChatListScreen({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<CommunityChatListScreen> createState() =>
      _CommunityChatListScreenState();
}

class _CommunityChatListScreenState extends State<CommunityChatListScreen> {
  double? _anchorLat;
  double? _anchorLng;

  @override
  void initState() {
    super.initState();
    _loadAnchor();
  }

  Future<void> _loadAnchor() async {
    final anchor = await CommunityLocationService.getOrSetAnchor(
      currentLat: widget.latitude,
      currentLng: widget.longitude,
    );
    if (!mounted) return;
    setState(() {
      _anchorLat = anchor.lat;
      _anchorLng = anchor.lng;
    });
    await MessagingService.updateCommunityChatTopic(
      latitude: anchor.lat,
      longitude: anchor.lng,
    );
  }

  static String _formatListTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final isToday =
        time.year == now.year && time.month == now.month && time.day == now.day;
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    if (isToday) return '$hh:$mm';
    final dd = time.day.toString().padLeft(2, '0');
    final mo = time.month.toString().padLeft(2, '0');
    return '$hh:$mm $dd/$mo';
  }

  void _openCommunityChat() {
    if (_anchorLat == null || _anchorLng == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityChatScreen(
          latitude: _anchorLat!,
          longitude: _anchorLng!,
        ),
      ),
    );
  }

  void _openDirectChat(DirectChatPreview chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectChatScreen(
          chatId: chat.chatId,
          otherUserName: chat.otherUserName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_anchorLat == null || _anchorLng == null) {
      return const ColoredBox(
        color: AppColors.darkBg,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.blue),
        ),
      );
    }

    final anchorLat = _anchorLat!;
    final anchorLng = _anchorLng!;
    final radiusLabel = Constants.communityChatRadiusKm.toStringAsFixed(0);

    return ColoredBox(
      color: AppColors.darkBg,
      child: StreamBuilder<CommunityChatSummary>(
        stream: CommunityChatService.nearbySummaryStream(
          latitude: anchorLat,
          longitude: anchorLng,
        ),
        builder: (context, summarySnap) {
          final summary = summarySnap.data ??
              const CommunityChatSummary(
                lastMessage: 'Tap to open nearby community chat',
              );

          return StreamBuilder<int>(
            stream: CommunityChatService.nearbyUnreadCountStream(
              latitude: anchorLat,
              longitude: anchorLng,
            ),
            builder: (context, unreadSnap) {
              final groupUnread = unreadSnap.data ?? 0;

              return StreamBuilder<List<DirectChatPreview>>(
                stream: DirectChatService.myChatsStream(),
                builder: (context, dmSnap) {
                  if (dmSnap.hasError) {
                    return Center(
                      child: Text(
                        'Could not load messages',
                        style: ChatUiStyles.listPreview,
                      ),
                    );
                  }

                  final dms = dmSnap.data ?? [];

                  return ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      _GeofencedCommunityChatTile(
                        preview: summary.lastMessage,
                        time: _formatListTime(summary.lastMessageAt),
                        unreadCount: groupUnread,
                        radiusLabel: radiusLabel,
                        onTap: _openCommunityChat,
                      ),
                      const Divider(
                        color: Color(0xFF2A2D33),
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      if (dms.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text(
                            'Messages',
                            style: ChatUiStyles.listSubtitle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...dms.map(
                          (chat) => _DirectChatListTile(
                            name: chat.otherUserName,
                            preview: chat.lastMessage,
                            time: _formatListTime(chat.lastMessageAt),
                            unreadCount: chat.unreadCount,
                            onTap: () => _openDirectChat(chat),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _GeofencedCommunityChatTile extends StatelessWidget {
  final String preview;
  final String time;
  final int unreadCount;
  final String radiusLabel;
  final VoidCallback onTap;

  const _GeofencedCommunityChatTile({
    required this.preview,
    required this.time,
    required this.unreadCount,
    required this.radiusLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12), // Slightly larger padding
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.blue,
                    AppColors.blue.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [ // Added subtle shadow for depth
                  BoxShadow(
                    color: AppColors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.groups,
                color: Colors.white,
                size: 24, // Slightly larger icon
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Community Chat',
                          style: ChatUiStyles.listTitle?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (time.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.darkBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            time,
                            style: ChatUiStyles.listSubtitle?.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6), // Slightly more space
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: AppColors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Chat within $radiusLabel km',
                        style: ChatUiStyles.listSubtitle?.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8), // More space before preview
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          style: ChatUiStyles.listPreview?.copyWith(
                            height: 1.4, // Better line height for readability
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _UnreadBadge(count: unreadCount),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectChatListTile extends StatelessWidget {
  final String name;
  final String preview;
  final String time;
  final int unreadCount;
  final VoidCallback onTap;

  const _DirectChatListTile({
    required this.name,
    required this.preview,
    required this.time,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: ChatUiStyles.listTilePadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF3D4450),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name, style: ChatUiStyles.listTitle)),
                      if (time.isNotEmpty)
                        Text(time, style: ChatUiStyles.listSubtitle),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: Text(preview, style: ChatUiStyles.listPreview)),
                      if (unreadCount > 0) _UnreadBadge(count: unreadCount),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

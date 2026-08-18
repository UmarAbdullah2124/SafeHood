import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/community_message.dart';
import '../services/community_chat_service.dart';
import '../services/messaging_service.dart';
import '../utils/app_colors.dart';
import '../utils/chat_ui_styles.dart';
import '../utils/constants.dart';
import '../utils/media_picker_utils.dart';
import '../widgets/chat_message_input_bar.dart';

/// Geofenced group chat with a fixed full-screen map behind the message list.
class CommunityChatScreen extends StatefulWidget {
  final double latitude;
  final double longitude;

  const CommunityChatScreen({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  GoogleMapController? _mapController;

  LatLng get _mapCenter => LatLng(widget.latitude, widget.longitude);

  @override
  void initState() {
    super.initState();
    CommunityChatService.markCommunityChatRead();
    MessagingService.updateCommunityChatTopic(
      latitude: widget.latitude,
      longitude: widget.longitude,
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  String _formatBubbleTime(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text;
    if (text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await CommunityChatService.sendMessage(
        text: text,
        latitude: widget.latitude,
        longitude: widget.longitude,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send message: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendMedia() async {
    if (_isSending) return;
    final picked = await MediaPickerUtils.pickFromGallery(context);
    if (picked == null) return;

    setState(() => _isSending = true);
    try {
      await CommunityChatService.sendMediaMessage(
        file: picked.file,
        type: picked.type == PickedMediaType.image
            ? CommunityMessageType.image
            : CommunityMessageType.video,
        latitude: widget.latitude,
        longitude: widget.longitude,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final radiusLabel = Constants.communityChatRadiusKm.toStringAsFixed(0);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.85),
                Colors.transparent,
              ],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.blue,
                    AppColors.blue.withOpacity(0.7),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.groups,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Community Chat', style: ChatUiStyles.appBarTitle),
                  Text(
                    'Chats in · ${radiusLabel} km radius',
                    style: ChatUiStyles.appBarSubtitle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Interactive map that responds to gestures
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _mapCenter,
              zoom: Constants.defaultMapZoom,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              controller.setMapStyle(Constants.darkMapStyle);
            },
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            liteModeEnabled: false,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            tiltGesturesEnabled: false,
            rotateGesturesEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: false,
            padding: EdgeInsets.only(bottom: bottomInset + 80),
          ),
          // Gradient overlay for better text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.85),
                ],
                stops: const [0.0, 0.2, 0.7, 1.0],
              ),
            ),
          ),
          // Glass morphism effect overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.blue.withOpacity(0.05),
                  Colors.transparent,
                  AppColors.blue.withOpacity(0.03),
                ],
              ),
            ),
          ),
          // Message list with improved background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: StreamBuilder<List<CommunityMessage>>(
              stream: CommunityChatService.nearbyMessagesStream(
                latitude: widget.latitude,
                longitude: widget.longitude,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const CircularProgressIndicator(
                        color: AppColors.blue,
                      ),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];
                if (messages.isNotEmpty) _scrollToBottom();

                if (messages.isEmpty) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.blue.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 48,
                            color: AppColors.blue.withOpacity(0.6),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No messages within ${radiusLabel} km yet',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Say hello to neighbors nearby! 🌍',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 4, // Reduced side margins
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMine = msg.senderId == currentUid;
                    return _MessageBubble(
                      message: msg,
                      isMine: isMine,
                      timeLabel: _formatBubbleTime(msg.timestamp),
                    );
                  },
                );
              },
            ),
          ),
          // Input bar with glass morphism
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.9),
                  ],
                  stops: const [0.0, 0.3],
                ),
              ),
              child: ChatMessageInputBar(
                controller: _messageController,
                isSending: _isSending,
                onSend: _sendMessage,
                onAttach: _pickAndSendMedia,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final CommunityMessage message;
  final bool isMine;
  final String timeLabel;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = this.isMine;
    final bubbleColor = isMine
        ? AppColors.blue
        : Colors.white.withOpacity(0.9);  // White for others
    final textColor = isMine ? Colors.white : Colors.black87;
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 8, right: 8),
      child: Row(
        mainAxisAlignment:
        isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMine) const Spacer(),

          // Use Flexible with Container that has no fixed width
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: screenWidth * 0.5,  // Max 50% of screen width
                minWidth: 60,  // Minimum width for very short messages
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
                ),
                border: !isMine
                    ? Border.all(
                  color: AppColors.blue.withOpacity(0.2),
                  width: 0.8,
                )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Media content
                  if (message.type == CommunityMessageType.image &&
                      message.mediaUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        message.mediaUrl!,
                        height: 150,
                        width: double.infinity,  // Take available width
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (message.type == CommunityMessageType.video &&
                      message.mediaUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.network(
                            message.mediaUrl!,
                            height: 150,
                            width: double.infinity,  // Take available width
                            fit: BoxFit.cover,
                          ),
                          Container(
                            color: Colors.black.withOpacity(0.3),
                            height: 150,
                            width: double.infinity,
                            child: const Icon(
                              Icons.play_circle_filled,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Text message
                  if (message.text.isNotEmpty) ...[
                    if (message.type != CommunityMessageType.text)
                      const SizedBox(height: 6),
                    Text(
                      message.text,
                      style: TextStyle(
                        color: textColor,
                        fontSize: ChatUiStyles.messageFontSize,
                        height: 1.4,
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),

                  // Time and read status row
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: isMine
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      Text(
                        timeLabel,
                        style: TextStyle(
                          color: (isMine ? Colors.white : Colors.black87).withOpacity(0.6),
                          fontSize: ChatUiStyles.messageTimeSize,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 12,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ],
                    ],
                  ),

                  // Sender name (only for received messages in community chat)
                  if (!isMine) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppColors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            message.senderName,
                            style: TextStyle(
                              color: AppColors.blue.withOpacity(0.9),
                              fontSize: ChatUiStyles.listSubtitleSize,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (!isMine) const Spacer(),
        ],
      ),
    );
  }
}
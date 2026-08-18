import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/direct_message.dart';
import '../services/direct_chat_service.dart';
import '../utils/app_colors.dart';
import '../utils/chat_ui_styles.dart';
import '../utils/constants.dart';
import '../utils/media_picker_utils.dart';
import '../widgets/chat_message_input_bar.dart';

class DirectChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;

  const DirectChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    DirectChatService.markChatRead(widget.chatId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
      await DirectChatService.sendTextMessage(
        chatId: widget.chatId,
        text: text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $e'), backgroundColor: AppColors.red),
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
      await DirectChatService.sendMediaMessage(
        chatId: widget.chatId,
        file: picked.file,
        type: picked.type == PickedMediaType.image
            ? DirectMessageType.image
            : DirectMessageType.video,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.otherUserName, style: ChatUiStyles.appBarTitle),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Map background
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: Constants.defaultMapZoom,
            ),
            onMapCreated: (c) => c.setMapStyle(Constants.darkMapStyle),
            zoomControlsEnabled: false,
            scrollGesturesEnabled: false,
            zoomGesturesEnabled: false,
            liteModeEnabled: true,
          ),

          // WhatsApp-like doodle pattern
          const DoodleBackground(),

          // Dark overlay with reduced opacity to let doodle show through
          Container(color: Colors.black.withOpacity(0.35)),

          // Messages
          Positioned.fill(
            child: StreamBuilder<List<DirectMessage>>(
              stream: DirectChatService.messagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.blue),
                  );
                }

                final messages = snapshot.data ?? [];
                if (messages.isNotEmpty) _scrollToBottom();

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Send a message to start the conversation',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: ChatUiStyles.messageListPadding.copyWith(top: 20, bottom: 88),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _DirectMessageBubble(
                      message: msg,
                      isMine: msg.senderId == currentUid,
                    );
                  },
                );
              },
            ),
          ),

          // Input bar
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: ChatMessageInputBar(
              controller: _messageController,
              isSending: _isSending,
              onSend: _sendMessage,
              onAttach: _pickAndSendMedia,
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectMessageBubble extends StatelessWidget {
  final DirectMessage message;
  final bool isMine;

  const _DirectMessageBubble({
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine
        ? AppColors.blue
        : Colors.white.withOpacity(0.9);
    final textColor = isMine ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 8, right: 8),
      child: Row(
        mainAxisAlignment:
        isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: ChatUiStyles.bubblePadding,
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: ChatUiStyles.bubbleRadius(isMine),
                border: !isMine
                    ? Border.all(color: AppColors.blue.withOpacity(0.08))
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (message.type == DirectMessageType.image &&
                      message.mediaUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        message.mediaUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (message.type == DirectMessageType.video &&
                      message.mediaUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.network(
                            message.mediaUrl!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          Container(
                            color: Colors.black.withOpacity(0.3),
                            child: const Icon(
                              Icons.play_circle_filled,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (message.text.isNotEmpty) ...[
                    if (message.type != DirectMessageType.text)
                      const SizedBox(height: 6),
                    Text(
                      message.text,
                      style: TextStyle(
                        color: textColor,
                        fontSize: ChatUiStyles.messageFontSize,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment:
                    isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: ChatUiStyles.messageTimeSize,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 12,
                          color: textColor.withOpacity(0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

// WhatsApp-like doodle background widget
class DoodleBackground extends StatelessWidget {
  const DoodleBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DoodlePainter(),
      size: Size.infinite,
    );
  }
}

class DoodlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final random = math.Random(42); // Fixed seed for consistent pattern

    // Draw circles (bubbles)
    for (int i = 0; i < 60; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 15 + random.nextDouble() * 40;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Draw filled dots
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.06);

    for (int i = 0; i < 200; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 1 + random.nextDouble() * 3;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Draw pluses (+)
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withOpacity(0.05);

    for (int i = 0; i < 40; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final size2 = 8 + random.nextDouble() * 12;

      canvas.drawLine(Offset(x - size2/2, y), Offset(x + size2/2, y), paint);
      canvas.drawLine(Offset(x, y - size2/2), Offset(x, y + size2/2), paint);
    }

    // Draw crosses (x)
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final size2 = 10 + random.nextDouble() * 15;

      canvas.drawLine(Offset(x - size2/2, y - size2/2), Offset(x + size2/2, y + size2/2), paint);
      canvas.drawLine(Offset(x + size2/2, y - size2/2), Offset(x - size2/2, y + size2/2), paint);
    }

    // Draw small stars/sparkles
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.07);

    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final size2 = 2 + random.nextDouble() * 4;

      // Small diamond shapes
      final path = Path();
      path.moveTo(x, y - size2);
      path.lineTo(x + size2, y);
      path.lineTo(x, y + size2);
      path.lineTo(x - size2, y);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
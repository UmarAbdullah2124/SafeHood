import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/app_colors.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../models/post_model.dart';
import '../widgets/emergency_post_popup.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  late GenerativeModel _model;
  late ChatSession _chatSession;

  // Emergency contacts by country
  final Map<String, Map<String, String>> _emergencyContacts = {
    'Pakistan': {
      'police': '15',
      'ambulance': '115',
      'fire': '16',
      'rescue': '1122',
      'women_helpline': '1099',
      'child_protection': '1121',
      'traffic_police': '1038',
      'bomb_disposal': '1191',
    },
    'International': {
      'police': '112',
      'ambulance': '112',
      'fire': '112',
      'emergency': '911',
    }
  };

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _initializeGemini();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeGemini() {
    try {
      if (_apiKey.isEmpty) {
        _addErrorMessage();
        return;
      }
      _model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 1,
          topP: 1,
          maxOutputTokens: 2048,
        ),
      );
      _chatSession = _model.startChat();
    } catch (e) {
      _addErrorMessage();
    }
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text: "👋 Welcome to SafeBot - Your Emergency AI Assistant!\n\n"
          "I can help you with:\n"
          "• Medical emergencies\n"
          "• Fire emergencies\n"
          "• Road accidents\n"
          "• Self defense techniques\n"
          "• Emergency contacts in your area\n"
          "• Post alerts or help requests\n\n"
          "⚠️ For life-threatening emergencies, call emergency services IMMEDIATELY!\n\n"
          "Try saying:\n"
          "• Post alert for medical emergency\n"
          "• Need emergency contacts\n"
          "• What to do in a fire?\n"
          "• Show nearby hospitals\n\n"
          "How can I help you stay safe?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
    setState(() {});
  }

  void _addErrorMessage() {
    _messages.add(ChatMessage(
      text: "⚠️ Unable to connect right now. Please check your internet connection and try again.",
      isUser: false,
      timestamp: DateTime.now(),
      isError: true,
    ));
    setState(() {});
  }

  String? _detectEmergencyType(String message) {
    if (message.contains('medical') || message.contains('heart') ||
        message.contains('injury') || message.contains('bleeding') ||
        message.contains('heart attack') || message.contains('stroke') ||
        message.contains('unconscious') || message.contains('breathing')) {
      return 'Medical';
    }
    if (message.contains('fire') || message.contains('burn') ||
        message.contains('house fire') || message.contains('building fire') ||
        message.contains('smoke')) {
      return 'House / Building Fire';
    }
    if (message.contains('robbery') || message.contains('theft') ||
        message.contains('stolen') || message.contains('mugging') ||
        message.contains('rob')) {
      return 'Theft / Robbery';
    }
    if (message.contains('accident') || message.contains('crash') ||
        message.contains('collision') || message.contains('hit') ||
        message.contains('car accident') || message.contains('vehicle')) {
      return 'Accident in Street';
    }
    return null;
  }

  String _getEmergencyContactsText() {
    return "EMERGENCY CONTACTS\n\n"
        "🚓 POLICE: 15\n"
        "🚑 AMBULANCE: 115\n"
        "🔥 FIRE: 16\n"
        "🆘 RESCUE: 1122\n"
        "👩 WOMEN HELPLINE: 1099\n"
        "👶 CHILD PROTECTION: 1121\n"
        "🚦 TRAFFIC POLICE: 1038\n\n"
        "⚠️ SAFETY TIPS:\n"
        "• Stay calm and speak clearly\n"
        "• Provide your exact location\n"
        "• Describe the emergency type\n"
        "• Don't hang up until told\n"
        "• Keep your phone charged";
  }

  String _getMedicalEmergencyResponse() {
    return "MEDICAL EMERGENCY - ACT FAST!\n\n"
        "IMMEDIATE ACTIONS:\n"
        "1️⃣ Call AMBULANCE: 115\n"
        "2️⃣ Call RESCUE 1122: 1122\n"
        "3️⃣ Provide exact location\n\n"
        "FIRST AID:\n"
        "• Check responsiveness - tap shoulders\n"
        "• Check breathing - look, listen, feel\n"
        "• If not breathing → Start CPR\n"
        "• Control bleeding → Apply pressure\n"
        "• Don't move injured person\n"
        "• Keep person warm\n\n"
        "For Heart Attack:\n"
        "• Call ambulance immediately\n"
        "• Have person sit down\n"
        "• Loosen tight clothing\n"
        "• Ask if they have medication\n\n"
        "🆘 Need help? Say 'post alert for medical emergency' to notify nearby people\n\n"
        "${_getEmergencyContactsText()}";
  }

  String _getFireEmergencyResponse() {
    return "FIRE EMERGENCY - EVACUATE NOW!\n\n"
        "IMMEDIATE ACTIONS:\n"
        "1️⃣ Call FIRE: 16\n"
        "2️⃣ Call RESCUE: 1122\n"
        "3️⃣ Alert everyone in building\n\n"
        "EVACUATION TIPS:\n"
        "• Crawl low under smoke\n"
        "• Feel doors before opening\n"
        "• Use stairs, NOT elevators\n"
        "• Cover mouth with wet cloth\n"
        "• Meet at designated area\n\n"
        "If trapped:\n"
        "• Seal door gaps with cloth\n"
        "• Call for help from window\n"
        "• Wave light-colored cloth\n\n"
        "🆘 Need help? Say 'post alert for fire' to notify nearby people\n\n"
        "${_getEmergencyContactsText()}";
  }

  String _getAccidentResponse() {
    return "ROAD ACCIDENT - HELP NEEDED!\n\n"
        "IMMEDIATE ACTIONS:\n"
        "1️⃣ Call AMBULANCE: 115\n"
        "2️⃣ Call POLICE: 15\n"
        "3️⃣ Call RESCUE: 1122\n\n"
        "DO NOT:\n"
        "• DON'T move injured person\n"
        "• DON'T remove helmet\n"
        "• DON'T give food/water\n"
        "• DON'T pull out objects\n\n"
        "DO:\n"
        "• Turn on hazard lights\n"
        "• Place warning triangle\n"
        "• Take photos of scene\n"
        "• Comfort injured person\n"
        "• Keep them warm\n\n"
        "🆘 Need help? Say 'post alert for accident' to notify nearby people\n\n"
        "${_getEmergencyContactsText()}";
  }

  String _getRobberyResponse() {
    return "ROBBERY/THEFT - STAY SAFE!\n\n"
        "IMMEDIATE ACTIONS:\n"
        "1️⃣ Call POLICE: 15\n"
        "2️⃣ Call WOMEN HELPLINE: 1099\n\n"
        "DURING ROBBERY:\n"
        "• Stay calm - don't resist\n"
        "• Don't make sudden moves\n"
        "• Observe without staring\n"
        "• Remember unique features\n\n"
        "AFTER ROBBERY:\n"
        "• Call police immediately\n"
        "• Don't chase robber\n"
        "• Preserve evidence\n"
        "• Lock all doors\n\n"
        "🆘 Need help? Say 'post alert for robbery' to notify nearby people\n\n"
        "${_getEmergencyContactsText()}";
  }

  Future<void> _autoPostAlert(String emergencyType, String description) async {
    try {
      Position position = await LocationService.getCurrentLocation();
      String locationName = await LocationService.getAddressFromLatLng(
          LatLng(position.latitude, position.longitude));

      User? user = FirebaseAuth.instance.currentUser;
      String firstName = user?.displayName?.split(' ')[0] ?? 'Community';
      String lastName = (user?.displayName?.split(' ').length ?? 1) > 1
          ? user!.displayName!.split(' ')[1]
          : 'Member';
      String userName = user?.displayName ?? '$firstName $lastName';

      final post = EmergencyPost(
        id: '',
        userId: user?.uid ?? '',
        type: 'alert',
        emergencyType: emergencyType,
        description: description,
        locationName: locationName,
        latitude: position.latitude,
        longitude: position.longitude,
        userName: userName,
        firstName: firstName,
        lastName: lastName,
        timestamp: DateTime.now(),
        trueVotes: 0,
        fakeVotes: 0,
        reportCount: 0,
      );

      await FirebaseService.createPost(post);

      _messages.add(ChatMessage(
        text: "✅ *ALERT POSTED SUCCESSFULLY!*\n\n"
            "Type: $emergencyType\n"
            "Location: $locationName\n"
            "🆘 Help has been notified!\n\n"
            "Stay safe and wait for assistance. Share your live location with trusted contacts.",
        isUser: false,
        timestamp: DateTime.now(),
      ));

      setState(() {});
    } catch (e) {
      _messages.add(ChatMessage(
        text: "❌ Failed to post alert. Please try again.\nError: $e",
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      ));
      setState(() {});
    }
  }

  Future<void> _autoPostHelp(String emergencyType, String description) async {
    try {
      Position position = await LocationService.getCurrentLocation();
      String locationName = await LocationService.getAddressFromLatLng(
          LatLng(position.latitude, position.longitude));

      User? user = FirebaseAuth.instance.currentUser;
      String firstName = user?.displayName?.split(' ')[0] ?? 'Community';
      String lastName = (user?.displayName?.split(' ').length ?? 1) > 1
          ? user!.displayName!.split(' ')[1]
          : 'Member';
      String userName = user?.displayName ?? '$firstName $lastName';

      final post = EmergencyPost(
        id: '',
        userId: user?.uid ?? '',
        type: 'help',
        emergencyType: emergencyType,
        description: description,
        locationName: locationName,
        latitude: position.latitude,
        longitude: position.longitude,
        userName: userName,
        firstName: firstName,
        lastName: lastName,
        timestamp: DateTime.now(),
        trueVotes: 0,
        fakeVotes: 0,
        reportCount: 0,
      );

      await FirebaseService.createPost(post);

      _messages.add(ChatMessage(
        text: "✅ *HELP REQUEST POSTED!*\n\n"
            "Type: $emergencyType\n"
            "Location: $locationName\n"
            "Nearby community members notified!\n\n"
            "Stay visible and keep your phone nearby.",
        isUser: false,
        timestamp: DateTime.now(),
      ));

      setState(() {});
    } catch (e) {
      _messages.add(ChatMessage(
        text: "❌ Failed to post help request. Please try again.",
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      ));
      setState(() {});
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    String lowerMessage = userMessage.toLowerCase();

    // Emergency detection - QUICK RESPONSE
    if (lowerMessage.contains('medical') || lowerMessage.contains('heart attack') ||
        lowerMessage.contains('bleeding') || lowerMessage.contains('unconscious')) {
      _isLoading = false;
      setState(() {});
      _messages.add(ChatMessage(
        text: _getMedicalEmergencyResponse(),
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _scrollToBottom();
      return;
    }

    if (lowerMessage.contains('fire') || lowerMessage.contains('burn') ||
        lowerMessage.contains('smoke') || lowerMessage.contains('evacuate')) {
      _isLoading = false;
      setState(() {});
      _messages.add(ChatMessage(
        text: _getFireEmergencyResponse(),
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _scrollToBottom();
      return;
    }

    if (lowerMessage.contains('accident') || lowerMessage.contains('crash') ||
        lowerMessage.contains('collision') || lowerMessage.contains('car accident')) {
      _isLoading = false;
      setState(() {});
      _messages.add(ChatMessage(
        text: _getAccidentResponse(),
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _scrollToBottom();
      return;
    }

    if (lowerMessage.contains('robbery') || lowerMessage.contains('theft') ||
        lowerMessage.contains('stolen') || lowerMessage.contains('mugging')) {
      _isLoading = false;
      setState(() {});
      _messages.add(ChatMessage(
        text: _getRobberyResponse(),
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _scrollToBottom();
      return;
    }

    // Emergency contacts request
    if (lowerMessage.contains('emergency contact') || lowerMessage.contains('helpline') ||
        lowerMessage.contains('police number') || lowerMessage.contains('ambulance number')) {
      _isLoading = false;
      setState(() {});
      _messages.add(ChatMessage(
        text: _getEmergencyContactsText(),
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _scrollToBottom();
      return;
    }

    // Auto-post alert detection
    if (lowerMessage.contains('post alert') || lowerMessage.contains('send alert')) {
      String? emergencyType = _detectEmergencyType(lowerMessage);

      if (emergencyType != null) {
        _isLoading = false;
        setState(() {});
        await _autoPostAlert(emergencyType, 'Emergency alert posted via SafeBot: ${userMessage.substring(0, userMessage.length > 100 ? 100 : userMessage.length)}');
        _scrollToBottom();
        return;
      } else {
        _isLoading = false;
        setState(() {});
        _showPostOptions(isAlert: true);
        return;
      }
    }

    // Auto-post help detection
    if (lowerMessage.contains('request help') || lowerMessage.contains('need help')) {
      String? emergencyType = _detectEmergencyType(lowerMessage);

      if (emergencyType != null) {
        _isLoading = false;
        setState(() {});
        await _autoPostHelp(emergencyType, 'Help requested via SafeBot: ${userMessage.substring(0, userMessage.length > 100 ? 100 : userMessage.length)}');
        _scrollToBottom();
        return;
      } else {
        _isLoading = false;
        setState(() {});
        _showPostOptions(isAlert: false);
        return;
      }
    }

    // Send to Gemini AI for other queries
    try {
      final response = await _chatSession.sendMessage(Content.text(userMessage));
      final botResponse = response.text ?? "I couldn't process your request.";

      setState(() {
        _messages.add(ChatMessage(
          text: botResponse,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Something went wrong. Please try again.",
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
        _isLoading = false;
      });
    }
  }

  void _showPostOptions({required bool isAlert}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return EmergencyPostPopup(
          currentLocation: "Current Location",
          onPostSubmitted: (emergencyType, location, useCurrentLocation) {
            setState(() {
              String message = isAlert
                  ? "✅ Alert posted successfully! Stay safe."
                  : "✅ Help request posted successfully! Someone will assist you soon.";
              _messages.add(ChatMessage(
                text: message,
                isUser: false,
                timestamp: DateTime.now(),
              ));
            });
            _scrollToBottom();
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Quick Emergency Actions",
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),
                  _quickActionButton(
                    icon: Icons.medical_services,
                    label: "Medical Emergency",
                    message: "medical emergency help",
                    color: Colors.red,
                  ),
                  _quickActionButton(
                    icon: Icons.local_fire_department,
                    label: "Fire Emergency",
                    message: "fire emergency help",
                    color: Colors.orange,
                  ),
                  _quickActionButton(
                    icon: Icons.car_crash,
                    label: "Accident",
                    message: "road accident help",
                    color: Colors.deepOrange,
                  ),
                  _quickActionButton(
                    icon: Icons.security,
                    label: "Robbery/Theft",
                    message: "robbery help",
                    color: Colors.purple,
                  ),
                  const Divider(color: Colors.grey, height: 30),
                  const Text(
                    "Quick Actions",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  _quickActionButton(
                    icon: Icons.emergency,
                    label: "Emergency Contacts",
                    message: "emergency contacts",
                    color: AppColors.blue,
                  ),
                  _quickActionButton(
                    icon: Icons.notifications_active,
                    label: "Post Alert",
                    message: "post alert",
                    color: Colors.red,
                  ),
                  _quickActionButton(
                    icon: Icons.help_outline,
                    label: "Request Help",
                    message: "request help",
                    color: Colors.green,
                  ),
                  _quickActionButton(
                    icon: Icons.local_hospital,
                    label: "First Aid",
                    message: "first aid instructions",
                    color: AppColors.blue,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required String message,
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (color ?? AppColors.blue).withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color ?? AppColors.blue),
        ),
        title: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        onTap: () {
          Navigator.pop(context);
          _messageController.text = message;
          _sendMessage();
        },
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Clear Chat", style: TextStyle(color: Colors.white)),
        content: const Text("Delete all conversation messages?", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _messages.clear();
                _addWelcomeMessage();
              });
              Navigator.pop(context);
            },
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.blue, AppColors.blue.withOpacity(0.7)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("SafeBot", overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  SizedBox(height: 2),
                  Text("Emergency AI Assistant", overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: _showQuickActions, icon: const Icon(Icons.grid_view_rounded, color: Colors.white70)),
          IconButton(onPressed: _clearChat, icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
              ),
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const SizedBox(width: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(18)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue))),
                          const SizedBox(width: 10),
                          const Text("SafeBot is responding...", style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            SafeArea(top: false, child: _buildInputBar()),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final bool isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            Container(
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.blue, AppColors.blue.withOpacity(0.7)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.blue : (message.isError ? Colors.red.shade900 : AppColors.cardBg),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isUser ? 22 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 22),
                ),
                border: !isUser ? Border.all(color: AppColors.blue.withOpacity(0.08)) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45)),
                  const SizedBox(height: 8),
                  Text(_formatTime(message.timestamp),
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(28),
              ),
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 5,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: "How may I help...",
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.blue, AppColors.blue.withOpacity(0.7)]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.blue.withOpacity(0.35), blurRadius: 12, spreadRadius: 1)],
              ),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  ChatMessage({required this.text, required this.isUser, required this.timestamp, this.isError = false});
}

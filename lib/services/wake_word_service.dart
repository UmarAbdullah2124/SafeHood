import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../navigation/app_navigator.dart';
import '../utils/app_colors.dart';
import 'foreground_service.dart';
import 'voice_alert_poster.dart';

enum _VoiceSessionState { idle, awaitingEmergencyType }

/// Handles wake-word listening, spoken prompts, and voice-posted alerts.
class WakeWordService with WidgetsBindingObserver {
  static final WakeWordService _instance = WakeWordService._internal();
  factory WakeWordService() => _instance;
  WakeWordService._internal();

  stt.SpeechToText? _speech;
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  bool _isInitialized = false;
  bool _wantsContinuousListening = false;
  bool _inVoiceSession = false;
  bool _appInForeground = true;
  bool _lifecycleObserverRegistered = false;
  ForegroundService? _foregroundService;
  DateTime? _lastDetectionAt;
  _VoiceSessionState _sessionState = _VoiceSessionState.idle;
  String _sessionIntent = 'alert';
  Timer? _sessionTimeoutTimer;
  int _typeListenAttempts = 0;
  String _lastHeardSnippet = '';
  bool _isListeningForType = false;
  bool _isSpeaking = false;

  static const _confirmChannelId = 'safehood_voice_confirm_v1';
  static const _silentChannelId = 'safehood_voice_silent_v1';

  final Map<String, String> _emergencyTypes = {
    'medical': 'Medical',
    'heart': 'Medical',
    'heart attack': 'Medical',
    'bleeding': 'Medical',
    'injury': 'Medical',
    'doctor': 'Medical',
    'ambulance': 'Medical',
    'fire': 'House / Building Fire',
    'burning': 'House / Building Fire',
    'smoke': 'House / Building Fire',
    'robbery': 'Theft / Robbery',
    'theft': 'Theft / Robbery',
    'stolen': 'Theft / Robbery',
    'mugging': 'Theft / Robbery',
    'accident': 'Accident in Street',
    'car crash': 'Accident in Street',
    'collision': 'Accident in Street',
    'crash': 'Accident in Street',
  };

  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _foregroundService = ForegroundService();
      _registerLifecycleObserver();

      await _notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: false,
          ),
        ),
      );

      await _createNotificationChannels();

      // Initialize TTS with better configuration
      await _initTTS();

      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        debugPrint('WakeWordService: microphone denied');
        return;
      }

      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      _speech = stt.SpeechToText();
      final available = await _speech!.initialize(
        onError: (error) {
          debugPrint('WakeWordService speech error: $error');
          if (!_inVoiceSession && _appInForeground) {
            Future.delayed(const Duration(seconds: 30), () {
              if (_wantsContinuousListening && !_inVoiceSession && _appInForeground) {
                unawaited(_startContinuousListenSession());
              }
            });
          }
        },
        onStatus: (status) => debugPrint('WakeWordService status: $status'),
      );

      if (available) {
        _isInitialized = true;
        debugPrint('WakeWordService: ready');

        // Test TTS after initialization
        await Future.delayed(const Duration(seconds: 1));
        await _speak('Voice service is ready');
      }
    } catch (e) {
      debugPrint('WakeWordService init failed: $e');
    }
  }

  Future<void> _initTTS() async {
    try {
      // Stop any ongoing TTS
      await _tts.stop();

      // Set TTS properties
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // Test if TTS is working
      bool isAvailable = await _tts.isLanguageAvailable('en-US');
      debugPrint('TTS language available: $isAvailable');

      // Set up TTS listeners
      _tts.setStartHandler(() {
        debugPrint('TTS: Started speaking');
      });

      _tts.setCompletionHandler(() {
        debugPrint('TTS: Completed speaking');
        _isSpeaking = false;
      });

      _tts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        _isSpeaking = false;
      });

      _tts.setCancelHandler(() {
        debugPrint('TTS: Cancelled');
        _isSpeaking = false;
      });

      debugPrint('TTS initialized successfully');
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  void _registerLifecycleObserver() {
    if (_lifecycleObserverRegistered) return;
    WidgetsBinding.instance.addObserver(this);
    _lifecycleObserverRegistered = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    if (_appInForeground) {
      unawaited(ensureListening());
    } else if (!_inVoiceSession) {
      unawaited(_speech?.stop());
    }
  }

  Future<void> _createNotificationChannels() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _confirmChannelId,
      'Voice alert confirmations',
      description: 'Shows when a voice alert is posted',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _silentChannelId,
      'Voice prompts',
      description: 'Safehood voice assistant prompts',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));
  }

  Future<void> startBackgroundListening() async {
    if (!_isInitialized) await initialize();
    await _foregroundService?.startForegroundService();
  }

  Future<void> startContinuousListening() async {
    if (!_isInitialized) await initialize();
    if (!_isInitialized) return;

    _wantsContinuousListening = true;
    _isListening = true;
    if (_appInForeground) {
      await _startContinuousListenSession();
    }
  }

  Future<void> ensureListening() async {
    if (!_isInitialized || !_wantsContinuousListening || _inVoiceSession) {
      return;
    }
    if (!_appInForeground) return;
    if (_speech?.isListening == true) return;
    await _startContinuousListenSession();
  }

  Future<void> _startContinuousListenSession() async {
    if (_speech == null ||
        !_wantsContinuousListening ||
        _inVoiceSession ||
        !_appInForeground) {
      return;
    }

    try {
      if (_speech!.isListening) return;

      final locales = await _speech!.locales();
      final locale = locales.firstWhere(
            (l) => l.localeId.startsWith('en'),
        orElse: () => locales.first,
      );

      await _speech!.listen(
        onResult: (result) {
          if (_inVoiceSession) return;
          final text = result.recognizedWords.toLowerCase().trim();
          if (text.isEmpty) return;
          _lastHeardSnippet = text;

          final wake = _matchWakeWord(text);
          if (wake != null) {
            unawaited(_onWakeWordDetected(text, wake.intent));
          }
        },
        localeId: locale.localeId,
        listenFor: const Duration(hours: 2),
        pauseFor: const Duration(seconds: 60),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      );
    } catch (e) {
      debugPrint('WakeWordService listen failed: $e');
    }
  }

  Future<void> stopContinuousListening() async {
    _wantsContinuousListening = false;
    _isListening = false;
    _sessionTimeoutTimer?.cancel();
    await _speech?.stop();
  }

  _WakeMatch? _matchWakeWord(String text) {
    final lower = text.toLowerCase().trim();
    final compact = lower.replaceAll(RegExp(r'[^a-z]'), '');

    if (RegExp(r'\bhelp\b').hasMatch(lower) ||
        lower.contains('help me') ||
        lower.contains('need help') ||
        lower.contains('request help')) {
      return const _WakeMatch(intent: 'help');
    }

    if (RegExp(r'\balert\b').hasMatch(lower) ||
        lower.contains('send alert') ||
        lower.contains('post alert')) {
      return const _WakeMatch(intent: 'alert');
    }

    if (compact.contains('safehood') ||
        lower.contains('safe hood') ||
        RegExp(r'safe\s*[-]?\s*hood').hasMatch(lower)) {
      return const _WakeMatch(intent: 'alert');
    }

    return null;
  }

  Future<void> _onWakeWordDetected(String fullText, String intent) async {
    final now = DateTime.now();
    if (_lastDetectionAt != null &&
        now.difference(_lastDetectionAt!) < const Duration(seconds: 8)) {
      return;
    }
    if (_inVoiceSession) return;

    _lastDetectionAt = now;
    _inVoiceSession = true;
    _sessionIntent = intent;

    debugPrint('WakeWordService: keyword "$intent" in "$fullText"');
    HapticFeedback.heavyImpact();

    await _speech?.stop();
    await Future.delayed(const Duration(milliseconds: 350));

    final spokenType = _parseEmergencyType(fullText);
    if (spokenType != null) {
      await _postVoiceAlert(emergencyType: spokenType, detectedText: fullText);
      return;
    }

    await _beginTypePromptSession();
  }

  Future<void> _beginTypePromptSession() async {
    _sessionState = _VoiceSessionState.awaitingEmergencyType;
    _typeListenAttempts = 0;
    _isListeningForType = false;

    // Make the prompt clear for both intents
    String prompt;
    if (_sessionIntent == 'help') {
      prompt = 'What kind of help do you need? Say medical, fire, robbery, or accident.';
    } else {
      prompt = 'What type of alert? Say medical, fire, robbery, or accident.';
    }

    debugPrint('🎤 Speaking prompt: "$prompt"');

    await _showPromptNotification(
      title: _sessionIntent == 'help' ? 'Help requested' : 'Alert requested',
      body: 'Listening for: medical, fire, robbery, or accident…',
    );

    // Speak the prompt and wait for it to complete
    await _speak(prompt);

    // Wait a moment after speaking before listening
    await Future.delayed(const Duration(milliseconds: 1500));

    await _listenForEmergencyType();
  }

  Future<void> _listenForEmergencyType() async {
    if (_speech == null) {
      await _endVoiceSession();
      return;
    }

    _typeListenAttempts += 1;
    if (_typeListenAttempts > 2) {
      await _speak('Cancelled. Try again when ready.');
      await _endVoiceSession();
      return;
    }

    _sessionTimeoutTimer?.cancel();
    _sessionTimeoutTimer = Timer(const Duration(seconds: 10), () async {
      if (_isListeningForType) {
        debugPrint('⏰ Timeout waiting for emergency type');
        await _speak('I did not hear the type. Please say medical, fire, robbery, or accident.');
        await _listenForEmergencyType();
      }
    });

    await _listenForEmergencyTypeOnce();
  }

  Future<void> _listenForEmergencyTypeOnce() async {
    if (_speech == null) return;

    if (_isListeningForType) {
      debugPrint('Already listening for type, skipping...');
      return;
    }

    try {
      if (_speech!.isListening) {
        await _speech!.stop();
      }

      await Future.delayed(const Duration(milliseconds: 500));

      final locales = await _speech!.locales();
      final locale = locales.firstWhere(
            (l) => l.localeId.startsWith('en'),
        orElse: () => locales.first,
      );

      var handled = false;
      _isListeningForType = true;

      debugPrint('🎤 Listening for emergency type...');

      await _speech!.listen(
        onResult: (result) async {
          if (handled || !_isListeningForType) return;

          final text = result.recognizedWords.toLowerCase().trim();
          debugPrint('🎤 Heard: "$text"');

          if (text.isEmpty) return;

          final type = _parseEmergencyType(text);
          if (type != null) {
            debugPrint('✅ Detected emergency type: $type');
            handled = true;
            _isListeningForType = false;
            _sessionTimeoutTimer?.cancel();

            if (_speech!.isListening) {
              await _speech!.stop();
            }

            await _postVoiceAlert(emergencyType: type, detectedText: text);
          }
        },
        localeId: locale.localeId,
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      );

      Future.delayed(const Duration(seconds: 8), () async {
        if (_isListeningForType && !handled) {
          debugPrint('⏰ Auto-stop: No detection');
          _isListeningForType = false;
          if (_speech!.isListening) {
            await _speech!.stop();
          }
        }
      });

    } catch (e) {
      debugPrint('❌ Type listen failed: $e');
      _isListeningForType = false;
      await _speak('Could not hear you. Please try again.');
      await _endVoiceSession();
    }
  }

  String? _parseEmergencyType(String text) {
    final lowerText = text.toLowerCase().trim();

    // Quick single-word checks
    if (lowerText == 'medical' || lowerText.contains('medical')) {
      return 'Medical';
    }
    if (lowerText == 'fire' || lowerText.contains('fire')) {
      return 'House / Building Fire';
    }
    if (lowerText == 'robbery' || lowerText.contains('robbery') ||
        lowerText == 'theft' || lowerText.contains('theft')) {
      return 'Theft / Robbery';
    }
    if (lowerText == 'accident' || lowerText.contains('accident')) {
      return 'Accident in Street';
    }

    // Check mapped keywords
    final sorted = _emergencyTypes.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final entry in sorted) {
      if (lowerText.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  Future<void> _postVoiceAlert({
    required String emergencyType,
    String? detectedText,
  }) async {
    try {
      await _speak(
        _sessionIntent == 'help'
            ? 'Posting your help request now.'
            : 'Posting your alert now.',
      );

      final locationName = await VoiceAlertPoster.postAlert(
        intent: _sessionIntent,
        emergencyType: emergencyType,
        detectedText: detectedText,
      );

      final title =
      _sessionIntent == 'help' ? 'Help request posted' : 'Alert posted';
      final body = '$emergencyType · $locationName';

      await _speak(
        _sessionIntent == 'help'
            ? 'Help request posted successfully near $locationName.'
            : 'Alert posted successfully near $locationName.',
      );

      await _showConfirmationNotification(title: title, body: body);
      _showInAppConfirmation(title, body);
    } catch (e) {
      debugPrint('WakeWordService post failed: $e');
      await _speak('Sorry, the post failed. Open Safehood and try again.');
      await _showPromptNotification(
        title: 'Post failed',
        body: e.toString(),
      );
    } finally {
      await _endVoiceSession();
    }
  }

  Future<void> _speak(String message) async {
    // Wait if already speaking
    while (_isSpeaking) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      _isSpeaking = true;
      debugPrint('🔊 Speaking: "$message"');

      // Stop any ongoing speech recognition
      if (_speech != null && _speech!.isListening) {
        await _speech!.stop();
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Stop any ongoing TTS
      await _tts.stop();
      await Future.delayed(const Duration(milliseconds: 100));

      // Speak the message
      int result = await _tts.speak(message);
      debugPrint('TTS speak result: $result (1=success, 0=failed)');

      if (result == 1) {
        // Wait for the speech to complete (approximate duration)
        int estimatedDuration = (message.length / 10 * 1000).toInt();
        await Future.delayed(Duration(milliseconds: estimatedDuration.clamp(1000, 5000)));
      } else {
        debugPrint('⚠️ TTS failed to start, showing notification instead');
        // Fallback: show notification with the message
        await _showFallbackNotification(message);
      }

    } catch (e) {
      debugPrint('❌ TTS exception: $e');
      // Fallback: show notification
      await _showFallbackNotification(message);
    } finally {
      _isSpeaking = false;
    }
  }

  Future<void> _showFallbackNotification(String message) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _silentChannelId,
        'Voice Assistant',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
    );
    await _notifications.show(
      DateTime.now().millisecond,
      'Safehood Assistant',
      message,
      details,
    );
  }

  Future<void> _endVoiceSession() async {
    _sessionTimeoutTimer?.cancel();
    _inVoiceSession = false;
    _sessionState = _VoiceSessionState.idle;
    _isListeningForType = false;

    if (_speech != null && _speech!.isListening) {
      await _speech!.stop();
    }

    if (_wantsContinuousListening && _isListening && _appInForeground) {
      await Future.delayed(const Duration(milliseconds: 500));
      unawaited(_startContinuousListenSession());
    }
  }

  Future<void> _showPromptNotification({
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _silentChannelId,
        'Voice prompts',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        onlyAlertOnce: true,
      ),
      iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
    );
    await _notifications.show(
      9101,
      title,
      body,
      details,
    );
  }

  Future<void> _showConfirmationNotification({
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _confirmChannelId,
        'Voice alert confirmations',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        onlyAlertOnce: true,
        autoCancel: true,
      ),
      iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
    );
    await _notifications.show(
      9102,
      title,
      body,
      details,
    );
  }

  void _showInAppConfirmation(String title, String body) {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _sessionIntent == 'help' ? AppColors.blue : Colors.red.shade800,
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            Icon(
              _sessionIntent == 'help' ? Icons.help_outline : Icons.warning_amber_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get lastHeardSnippet => _lastHeardSnippet;
  bool isInitialized() => _isInitialized;
  bool isListening() => _isListening;

  void dispose() {
    _wantsContinuousListening = false;
    _sessionTimeoutTimer?.cancel();
    if (_lifecycleObserverRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _lifecycleObserverRegistered = false;
    }
    _foregroundService?.stopForegroundService();
    _speech?.stop();
    _tts.stop();
    _isInitialized = false;
  }
}

class _WakeMatch {
  final String intent;
  const _WakeMatch({required this.intent});
}
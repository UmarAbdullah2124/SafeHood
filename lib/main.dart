import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'screens/safety_home_screen.dart';
import 'screens/sign_in_screen.dart';
import 'services/messaging_service.dart';
import 'services/wake_word_service.dart';
import 'utils/app_colors.dart';
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Init only — start listening after the first frame (needs Activity).
    await WakeWordService().initialize();
    await MessagingService.initialize();
  } catch (e) {
    debugPrint('Error during initialization: $e');
  }

  runApp(const SafehoodApp());
}

class SafehoodApp extends StatefulWidget {
  const SafehoodApp({super.key});

  @override
  State<SafehoodApp> createState() => _SafehoodAppState();
}

class _SafehoodAppState extends State<SafehoodApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startVoiceServices());
  }

  Future<void> _startVoiceServices() async {
    try {
      final wakeWordService = WakeWordService();
      await wakeWordService.startBackgroundListening();
      await wakeWordService.startContinuousListening();
      debugPrint('Wake word service started after first frame');
    } catch (e) {
      debugPrint('Failed to start wake word service: $e');
    }

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        title: 'Safehood',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          fontFamily: 'Inter',

          // MAIN APP COLORS
          primaryColor: AppColors.blue,
          scaffoldBackgroundColor: Colors.black,

          // Material 3 color scheme
          colorScheme: ColorScheme.dark(
            primary: AppColors.blue,
            secondary: AppColors.blue,
            surface: const Color(0xFF121212),
          ),

          // Cursor color
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: AppColors.blue,
            selectionColor: AppColors.blue.withOpacity(0.4),
            selectionHandleColor: AppColors.blue,
          ),

          // AppBar
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),

          // Date picker / calendar
          datePickerTheme: DatePickerThemeData(
            backgroundColor: const Color(0xFF121212),
            headerBackgroundColor: AppColors.blue,
            headerForegroundColor: Colors.white,
            dayForegroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              return Colors.white;
            }),
            dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.blue;
              }
              return Colors.transparent;
            }),
          ),

          // Input fields
          inputDecorationTheme: InputDecorationTheme(
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.blue),
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade700),
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          // Buttons
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _removeSplash();
  }

  void _removeSplash() async {
    await Future.delayed(const Duration(seconds: 1));
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null || user.isAnonymous) {
            return const SignInScreen();
          } else {
            return const SafetyHomeScreen();
          }
        }

        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: AppColors.blue,
            ),
          ),
        );
      },
    );
  }
}

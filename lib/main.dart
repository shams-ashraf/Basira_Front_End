import 'dart:async';

import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'services/backend_service.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/child_voice.dart';
import 'screens/parent_dashboard.dart';
import 'screens/esp32_camera.dart';
import 'screens/child_qr.dart';
import 'screens/parent_scanner.dart';
import 'screens/child_profile.dart';
import 'screens/child_unknown.dart';
import 'screens/child_phone_camera.dart';

// persons
import 'screens/persons.dart';
import 'screens/add_person.dart';
import 'screens/person_details.dart';
import 'screens/unknown.dart';
import 'screens/alerts.dart';
import 'screens/alerts_history.dart';
import 'screens/settings.dart';
import 'screens/ai_lab_page.dart';

// camera
import 'screens/camera.dart';
import 'screens/debug_gallery.dart';
import 'camera_ai/camera_test_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.init();
  runApp(const MyApp());
  unawaited(BackendService.instance.initNotifications());
  unawaited(BackendService.instance.retryPendingUploads());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Basera - Smart Assistant",
      home: const SplashScreen(),
      routes: {
        "/splash": (context) => const SplashScreen(),
        "/login": (context) => const LoginScreen(),
        "/signup": (context) => const SignupScreen(),
        "/child": (context) => const VoiceFlow(),
        "/parent": (context) => const ParentDashboard(),
        "/child-qr": (context) => const ChildQRScreen(),
        "/parent-scanner": (context) => const ParentScannerScreen(),
        "/child-profile": (context) => ChildProfileScreen(),
        "/child-unknown": (context) => const ChildUnknownCaptureScreen(),
        "/child-camera": (context) => const ChildPhoneCameraScreen(),
        "/debug-gallery": (context) => const DebugGalleryScreen(),
        "/persons": (context) => PersonsScreen(),
        "/add": (context) => AddPersonScreen(),
        "/unknown": (context) => UnknownScreen(),
        "/alerts": (context) => AlertsScreen(),
        "/alerts-history": (context) => AlertsHistoryScreen(),
        "/settings": (context) => SettingsScreen(),
        "/camera": (context) => const CameraScreen(),
        "/ai-lab": (context) => const AILabPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == "/person-details") {
          final args = settings.arguments as Map;
          return MaterialPageRoute(
            builder: (_) => PersonDetailsScreen(
              id: args["id"],
              name: args["name"],
            ),
          );
        }
        if (settings.name == "/camera-ai") {
          final args = settings.arguments as Map?;
          final mode = args?['mode'] as String?;
          return MaterialPageRoute(
            builder: (_) => CameraTestPage(initialMode: mode),
          );
        }
        if (settings.name == "/esp-camera") {
          final args = (settings.arguments ?? {'mode': 'object'}) as Map;
          return MaterialPageRoute(
            builder: (_) => Esp32CameraScreen(initialMode: args["mode"]),
          );
        }
        return null;
      },
    );
  }
}

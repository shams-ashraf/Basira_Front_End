import 'dart:async';

import 'l10n.dart';

import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'services/backend_service.dart';
import 'services/voice_service.dart';

import 'screens/splash_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/language_select_screen.dart';
import 'screens/select_role.dart';
import 'screens/parent/login_screen.dart';
import 'screens/parent/signup_screen.dart';
import 'screens/child/child_voice.dart';
import 'screens/parent/parent_dashboard.dart';
import 'screens/child/esp32_camera.dart';
import 'screens/child/child_qr.dart';
import 'screens/parent/parent_scanner.dart';
import 'screens/child/child_profile.dart';
import 'screens/child/child_unknown.dart';
import 'screens/child_name_screen.dart';

// persons
import 'screens/parent/persons.dart';
import 'screens/parent/add_person.dart';
import 'screens/parent/person_details.dart';
import 'screens/parent/unknown.dart';
import 'screens/parent/alerts.dart';
import 'screens/parent/settings.dart';
import 'screens/child/ai_lab_page.dart';


import 'camera_ai/camera_test_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.init();
  await L10n.load();
  runApp(const MyApp());
  unawaited(BackendService.instance.initNotifications());
  unawaited(BackendService.instance.retryPendingUploads());
}

class VoiceRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Basera - Smart Assistant",
      home: const SplashScreen(),
      navigatorObservers: [VoiceRouteObserver()],
      routes: {
        "/splash": (context) => const SplashScreen(),
        "/setup": (context) => const SetupScreen(),
        "/language-select": (context) => const LanguageSelectScreen(),
        "/select-user": (context) => const SelectRoleScreen(),
        "/login": (context) => const LoginScreen(),
        "/signup": (context) => const SignupScreen(),
        "/child-name": (context) => const ChildNameScreen(),
        "/child": (context) => const VoiceFlow(),
        "/parent": (context) => const ParentDashboard(),
        "/child-qr": (context) => const ChildQRScreen(),
        "/parent-scanner": (context) => const ParentScannerScreen(),
        "/child-profile": (context) => ChildProfileScreen(),
        "/child-unknown": (context) => const ChildUnknownCaptureScreen(),
        "/persons": (context) => PersonsScreen(),
        "/add": (context) => AddPersonScreen(),
        "/unknown": (context) => UnknownScreen(),
        "/alerts": (context) => AlertsScreen(),
        "/settings": (context) => SettingsScreen(),
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

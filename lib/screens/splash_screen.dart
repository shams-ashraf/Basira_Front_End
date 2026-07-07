import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _checkAuth();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    // Keep splash visible for at least 2 seconds for a premium feel
    await Future.delayed(const Duration(seconds: 2));
    
    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('user_role');
    final childName = prefs.getString('child_name');
    
    if (!mounted) return;
    
    if (userRole == 'child' && childName != null && childName.isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/esp-camera', arguments: {'mode': 'safety'});
      return;
    }

    final isValid = await AuthService.instance.validateToken();
    
    if (!mounted) return;
    
    if (isValid) {
      final auth = await AuthService.instance.getAuth();
      if (auth != null) {
        final role = auth['role'];
        if (role == 'parent') {
          Navigator.pushReplacementNamed(context, '/parent');
        } else {
          Navigator.pushReplacementNamed(context, '/esp-camera', arguments: {'mode': 'safety'});
        }
        return;
      }
    }
    
    Navigator.pushReplacementNamed(context, '/setup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3D59), Color(0xFF17B890)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.remove_red_eye_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "BASIRA (بصيرة)",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Smart AI Vision for Visually Impaired",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

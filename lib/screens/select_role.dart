import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SelectRoleScreen extends StatefulWidget {
  const SelectRoleScreen({super.key});

  @override
  _SelectRoleScreenState createState() => _SelectRoleScreenState();
}

class _SelectRoleScreenState extends State<SelectRoleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("BASERA", style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 4)),
            const SizedBox(height: 10),
            const Text("Choose your role to begin", style: TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 60),
            _roleCard(
              title: "Parent",
              subtitle: "Monitor & receive alerts",
              icon: Icons.family_restroom_rounded,
              color: Colors.blueAccent,
              onTap: () async {
                final auth = await AuthService.instance.getAuth();
                if (auth != null && auth['role'] == 'parent') {
                  Navigator.pushReplacementNamed(context, "/parent");
                } else {
                  Navigator.pushReplacementNamed(context, "/parent-scanner");
                }
              },
            ),
            const SizedBox(height: 20),
            _roleCard(
              title: "Child",
              subtitle: "Smart voice assistant",
              icon: Icons.child_care_rounded,
              color: Colors.amber,
              onTap: () async {
                Navigator.pushReplacementNamed(context, "/child");
              },
            ),
            const SizedBox(height: 20),
            _roleCard(
              title: "Camera AI",
              subtitle: "Dual-mode real-time ESP32-CAM monitoring",
              icon: Icons.camera_alt_rounded,
              color: Colors.greenAccent,
              onTap: () async {
                Navigator.pushNamed(context, "/camera-ai");
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}

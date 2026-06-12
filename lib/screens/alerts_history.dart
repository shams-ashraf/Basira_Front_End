import 'package:flutter/material.dart';
import '../app_header.dart';

class AlertsHistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: "Alerts History 📅"),
      backgroundColor: const Color(0xFFEEF4FB),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_toggle_off, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              "Under Development 🚧", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            const Text(
              "History log will be available soon.", 
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
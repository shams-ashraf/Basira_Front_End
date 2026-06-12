import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_header.dart';
import 'system_logs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String language = "en";
  final TextEditingController _ipController = TextEditingController();
  bool _ipSaved = false;

  @override
  void initState() {
    super.initState();
    _loadSavedIp();
  }

  Future<void> _loadSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('esp32_ip') ?? '192.168.1.100';
    setState(() {
      _ipController.text = savedIp;
    });
  }

  Future<void> _saveIp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('esp32_ip', _ipController.text.trim());
    setState(() => _ipSaved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _ipSaved = false);
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: "Settings ⚙️"),
      backgroundColor: const Color(0xFFEEF4FB),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            // Language Card (Locked to English for now)
            card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Language",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E6B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDDE6F0)),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFF7FAFD),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "English",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "System Logs",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E6B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "View backend events, warnings, and errors.",
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SystemLogsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt_long),
                      label: const Text("Open Logs"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C3E6B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),



            // ESP32 Config Card
            card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "ESP32 Camera",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E6B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ipController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: "Camera IP Address",
                      hintText: "e.g. 192.168.1.10",
                      prefixIcon: const Icon(Icons.router),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: _ipSaved
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveIp,
                      icon: const Icon(Icons.save),
                      label: const Text("Save IP Address"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C3E6B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (_ipSaved)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        "✅ IP saved successfully!",
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget card(Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA0B4C8).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }
}

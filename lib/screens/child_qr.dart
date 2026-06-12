import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_header.dart';
import '../config.dart';

class ChildQRScreen extends StatefulWidget {
  const ChildQRScreen({super.key});

  @override
  _ChildQRScreenState createState() => _ChildQRScreenState();
}

class _ChildQRScreenState extends State<ChildQRScreen> {
  String? childId;
  final serverIpCtrl = TextEditingController();
  final espIpCtrl = TextEditingController();
  String? qrData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      childId = prefs.getString('auth_id');
      serverIpCtrl.text = prefs.getString('server_ip') ?? AppConfig.serverIp;
      espIpCtrl.text = prefs.getString('esp32_ip') ?? AppConfig.esp32Ip;
      _generateQR();
    });
  }

  void _generateQR() async {
    if (childId == null) return;
    
    // Save IPs locally
    final prefs = await SharedPreferences.getInstance();
    final normalizedServer = AppConfig.normalizeHost(serverIpCtrl.text);
    final normalizedEsp = AppConfig.normalizeHost(espIpCtrl.text);
    await prefs.setString('server_ip', normalizedServer);
    await prefs.setString('esp32_ip', normalizedEsp);
    AppConfig.serverIp = normalizedServer;
    AppConfig.esp32Ip = normalizedEsp;
    final childName = prefs.getString('child_profile_${childId}_name') ?? "Ahmed Ali";
    final data = {
      "id": childId,
      "childName": childName,
      "type": "child_link",
    };
    setState(() {
      qrData = jsonEncode(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppHeader(title: "Connect Child", backgroundColor: Colors.transparent),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFF), Color(0xFFE0EAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
                  ]
                ),
                child: Column(
                  children: [
                    const Text(
                      "Show this to Parent",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 20),
                    if (qrData != null)
                      QrImageView(
                        data: qrData!,
                        version: QrVersions.auto,
                        size: 200.0,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black87),
                      )
                    else
                      const CircularProgressIndicator(),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Configuration (Technical)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: serverIpCtrl,
                decoration: InputDecoration(
                  labelText: "Server IP (e.g. 192.168.1.5:3000)",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                onChanged: (v) => _generateQR(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: espIpCtrl,
                decoration: InputDecoration(
                  labelText: "ESP32 IP (e.g. 192.168.1.10)",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                onChanged: (v) => _generateQR(),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("Done", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

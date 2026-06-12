import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../app_header.dart';

class ParentScannerScreen extends StatefulWidget {
  const ParentScannerScreen({super.key});

  @override
  _ParentScannerScreenState createState() => _ParentScannerScreenState();
}

class _ParentScannerScreenState extends State<ParentScannerScreen> {
  bool isScanned = false;
  DateTime? lastErrorTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppHeader(title: "Scan Child QR", backgroundColor: Colors.transparent),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) async {
              if (isScanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final rawValue = barcode.rawValue;
                if (rawValue != null && rawValue.isNotEmpty) {
                  try {
                    final data = jsonDecode(rawValue);
                    if (data['type'] == 'child_link') {
                      isScanned = true;
                      
                      // Pair child with parent locally and on the backend
                      await AuthService.instance.linkChild(data['id'].toString());
                      final childName = data['childName'] ?? 'Child';
                      await BackendService.instance.linkChild(data['id'].toString(), childName);
                      
                      final prefs = await SharedPreferences.getInstance();
                      if (data['childName'] != null) {
                        await prefs.setString('linked_child_name', data['childName']);
                      }
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Child linked successfully!"), backgroundColor: Colors.green),
                        );
                        Navigator.pop(context);
                      }
                    } else {
                      throw Exception("Invalid QR type");
                    }
                    break;
                  } catch (e) {
                    final now = DateTime.now();
                    if (lastErrorTime == null || now.difference(lastErrorTime!).inSeconds > 3) {
                      lastErrorTime = now;
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Invalid QR code."), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }
                }
              }
            },
          ),
          // Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: const Text(
              "Center the Child's QR code in the frame",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }
}

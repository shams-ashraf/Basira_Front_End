import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_header.dart';
import '../../l10n.dart';
import '../../services/voice_service.dart';

class ChildQRScreen extends StatefulWidget {
  const ChildQRScreen({super.key});

  @override
  State<ChildQRScreen> createState() => _ChildQRScreenState();
}

class _ChildQRScreenState extends State<ChildQRScreen> {
  String? childId;
  String? qrData;
  bool _voiceAnnounced = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      childId = prefs.getString('auth_id') ??
          prefs.getString('linked_child_id') ??
          prefs.getString('child_id') ??
          prefs.getString('child_device_id');
    });
    await _generateQR();
  }

  Future<void> _generateQR() async {
    final prefs = await SharedPreferences.getInstance();
    childId ??= prefs.getString('auth_id') ??
        prefs.getString('linked_child_id') ??
        prefs.getString('child_id') ??
        prefs.getString('child_device_id');
    childId ??= await _ensureChildDeviceId(prefs);

    final childName =
        prefs.getString('child_profile_${childId}_name') ?? 'Ahmed Ali';
    final data = {
      'id': childId,
      'childName': childName,
      'type': 'child_link',
    };
    setState(() {
      qrData = jsonEncode(data);
    });

    if (!_voiceAnnounced) {
      _voiceAnnounced = true;
      await VoiceService.instance.init();
      await VoiceService.instance.speakWithRetry(
        L10n.isArabic
            ? 'يرجى طلب أحد الوالدين لمسح رمز QR هذا للمتابعة.'
            : 'Please ask a parent to scan this code to continue.',
      );
    }
  }

  Future<String> _ensureChildDeviceId(SharedPreferences prefs) async {
    final existing = prefs.getString('child_device_id');
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = DateTime.now().millisecondsSinceEpoch.toString();
    await prefs.setString('child_device_id', generated);
    await prefs.setString('child_id', generated);
    await prefs.setString('linked_child_id', generated);
    return generated;
  }

  @override
  Widget build(BuildContext context) {
    final isAr = L10n.isArabic;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppHeader(
        title: isAr ? 'ربط الطفل' : 'Link Child',
        backgroundColor: Colors.transparent,
      ),
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
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      isAr ? 'ورّي الرمز ده لولي الأمر' : 'Show this code to the parent',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (qrData != null)
                      QrImageView(
                        data: qrData!,
                        version: QrVersions.auto,
                        size: 200.0,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black87,
                        ),
                      )
                    else
                      const CircularProgressIndicator(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isAr
                    ? 'سيحتوي رمز QR على معلومات الربط فقط.'
                    : 'The QR code contains only the pairing information needed for linking.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  '/esp-camera',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isAr ? 'التالي' : 'Next',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

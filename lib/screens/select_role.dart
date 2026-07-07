import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n.dart';
import '../services/voice_service.dart';

class SelectRoleScreen extends StatefulWidget {
  const SelectRoleScreen({super.key});

  @override
  State<SelectRoleScreen> createState() => _SelectRoleScreenState();
}

class _SelectRoleScreenState extends State<SelectRoleScreen> {
  StreamSubscription<String>? _voiceSub;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    await VoiceService.instance.init();
    final prompt = L10n.isArabic
        ? '  ولي الأمر أم الطفل؟.'
        : 'Please say: parent or child.';
    await VoiceService.instance.speakWithRetry(prompt);
    await VoiceService.instance.startContinuousListening();
    _voiceSub = VoiceService.instance.textStream.listen((text) {
      if (!mounted || _navigating) return;
      final normalized = text.toLowerCase().trim();
      if (normalized.isEmpty) return;
      if (normalized.contains('parent') ||
          normalized.contains('guardian') ||
          normalized.contains('ولي') ||
          normalized.contains('أهل') ||
          normalized.contains('اهل')) {
        _goParent();
      } else if (normalized.contains('child') ||
          normalized.contains('طفل') ||
          normalized.contains('kid')) {
        _goChild();
      }
    });
  }

  Future<void> _goParent() async {
    if (_navigating) return;
    _navigating = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', 'parent');
    await VoiceService.instance.stopListening();
    await VoiceService.instance.stopSpeech();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _goChild() async {
    if (_navigating) return;
    _navigating = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', 'child');
    await VoiceService.instance.stopListening();
    await VoiceService.instance.stopSpeech();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/child-name');
  }

  @override
  void dispose() {
    _voiceSub?.cancel();
    VoiceService.instance.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = L10n.isArabic;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isAr ? 'اختيار نوع المستخدم' : 'Choose User Type',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isAr ? 'قل: ولي الأمر أو الطفل.' : 'Say: parent or child.',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _bigButton(
                context,
                title: isAr ? 'ولي الأمر' : 'Parent',
                subtitle: isAr
                    ? 'متابعة واستقبال التنبيهات'
                    : 'Monitor and receive alerts',
                color: const Color(0xFF38BDF8),
                onTap: _goParent,
              ),
              const SizedBox(height: 16),
              _bigButton(
                context,
                title: isAr ? 'الطفل' : 'Child',
                subtitle: isAr ? 'مساعد صوتي ذكي' : 'Smart voice assistant',
                color: const Color(0xFFF59E0B),
                onTap: _goChild,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bigButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 104,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

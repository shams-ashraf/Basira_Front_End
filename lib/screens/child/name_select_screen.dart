import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n.dart';
import '../../services/voice_service.dart';

class NameSelectScreen extends StatefulWidget {
  const NameSelectScreen({super.key});

  @override
  State<NameSelectScreen> createState() => _NameSelectScreenState();
}

class _NameSelectScreenState extends State<NameSelectScreen> {
  StreamSubscription<String>? _voiceSub;
  bool _navigating = false;
  String _promptText = '';
  String _recognizedName = '';

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

 Future<void> _initVoice() async {
  await VoiceService.instance.init();

  final prompt =
      L10n.isArabic ? 'مرحباً بك ما اسمك' : 'What is your name?';

  if (mounted) {
    setState(() => _promptText = prompt);
  }

  await VoiceService.instance.interruptAndSpeak(prompt);
  await VoiceService.instance.startContinuousListening();

  _voiceSub = VoiceService.instance.textStream.listen((text) {
    if (!mounted || _navigating) return;

    if (text.trim().isEmpty) return;

    _handleNameResponse(text);
  });
}

  Future<void> _handleNameResponse(String rawName) async {
    if (_navigating) return;

    final cleanedName = _sanitizeName(rawName);
    if (cleanedName.isEmpty) return;

    setState(() {
      _recognizedName = cleanedName;
      _navigating = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('child_name', cleanedName);

    final welcomeMsg = L10n.isArabic ? 'مرحباً بك يا $cleanedName' : 'Welcome, $cleanedName';
    
    // Stop listening so we don't pick up the welcome message
    await VoiceService.instance.stopListening();
    await VoiceService.instance.interruptAndSpeak(welcomeMsg);

    // Give it a couple of seconds to speak before navigating
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/child-qr');
  }

  String _sanitizeName(String value) {
    final normalized = value
        .replaceAll(RegExp(r'[\u200B-\u200F\uFEFF]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return '';
    
    var lower = normalized.toLowerCase();
    
    // Remove common prefixes
    final prefixes = [
      'my name is ',
      'i am ',
      'im ',
      'i\'m ',
      'انا اسمي ',
      'أنا اسمي ',
      'اسمي ',
      'انا ',
      'أنا ',
      'اسمه ',
      'اسمها ',
    ];

    for (final prefix in prefixes) {
      if (lower.startsWith(prefix)) {
        lower = lower.substring(prefix.length).trim();
        // Since we modified it, we want the original casing of the remaining part if possible,
        // but for Arabic it doesn't matter. For English, we'll just capitalize the first letter.
        if (lower.isNotEmpty) {
          final parts = normalized.split(RegExp(r'\s+'));
          return parts.last; // Simple fallback, usually the last word is the name
        }
      }
    }
    
    if (lower.isEmpty) return '';
    
    // Filter out filler words that might be caught
    const blocked = <String>{
      'حسنا', 'حسنًا', 'حسناً', 'okay', 'ok', 'welcome', 'child',
    };
    
    if (blocked.contains(lower)) return '';
    
    return normalized;
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
              const Icon(Icons.face_retouching_natural_rounded, size: 80, color: Color(0xFFF59E0B)),
              const SizedBox(height: 24),
              Text(
                isAr ? 'مرحباً بك' : 'Welcome',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _promptText,
                style: const TextStyle(color: Colors.white70, fontSize: 24),
                textAlign: TextAlign.center,
              ),
              if (_recognizedName.isNotEmpty) ...[
                const SizedBox(height: 40),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isAr ? 'اسمك هو' : 'Your name is',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _recognizedName,
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: Color(0xFFF59E0B)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

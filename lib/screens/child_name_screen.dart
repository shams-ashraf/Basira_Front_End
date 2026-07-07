import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/voice_service.dart';

class ChildNameScreen extends StatefulWidget {
  const ChildNameScreen({super.key});

  @override
  State<ChildNameScreen> createState() => _ChildNameScreenState();
}

class _ChildNameScreenState extends State<ChildNameScreen> {
  bool _saving = false;
  String _language = 'ar';
  StreamSubscription<String>? _voiceSub;
  bool _voiceListeningStarted = false;
  bool _isSpeaking = true;

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString('language') ?? 'ar';
    
    debugPrint('[ChildNameScreen] _initVoice start, language=$_language');
    await VoiceService.instance.init();
    if (!mounted || _voiceListeningStarted) return;
    _voiceListeningStarted = true;
    
    // Give TTS engine a moment to fully initialize before first speech
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    
    final prompt = _language == 'ar'
        ? 'مرحبا، ما هو اسمك؟'
        : 'Welcome, what is your name?';
    
    debugPrint('[ChildNameScreen] 🔊 Speaking prompt: $prompt');
    await VoiceService.instance.interruptAndSpeak(prompt);
    
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
    });
    
    await VoiceService.instance.startContinuousListening();
    _voiceSub = VoiceService.instance.textStream.listen((text) {
      if (!mounted || _saving || _isSpeaking) return;
      final normalized = text.trim();
      if (normalized.isEmpty) return;
      
      // Basic extraction logic
      String name = normalized;
      if (_language == 'ar' && name.startsWith('اسمي ')) {
        name = name.substring(5).trim();
      } else if (_language == 'en' && name.toLowerCase().startsWith('my name is ')) {
        name = name.substring(11).trim();
      } else if (_language == 'en' && name.toLowerCase().startsWith('i am ')) {
        name = name.substring(5).trim();
      }
      
      _saveNameAndProceed(name);
    });
  }

  Future<void> _saveNameAndProceed(String name) async {
    if (_saving) return;
    setState(() => _saving = true);
    
    _voiceSub?.cancel();
    await VoiceService.instance.stopListening();
    await VoiceService.instance.stopSpeech();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('child_name', name);
    
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/esp-camera', arguments: {'mode': 'safety'});
  }

  @override
  void dispose() {
    _voiceSub?.cancel();
    VoiceService.instance.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.face_retouching_natural,
                size: 80,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(height: 32),
              Text(
                _language == 'ar' ? 'مرحباً بك' : 'Welcome',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _language == 'ar' ? 'ما اسمك؟' : 'What is your name?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 48),
              if (_saving)
                const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
              else if (!_isSpeaking)
                Column(
                  children: [
                    const Icon(Icons.mic, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _language == 'ar' ? 'أنا أستمع إليك...' : 'I am listening...',
                      style: const TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n.dart';
import '../services/voice_service.dart';

class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  String _language = 'ar';
  bool _saving = false;
  bool _voiceListeningStarted = false;
  StreamSubscription<String>? _voiceSub;

  bool _isArabicTurn = true;
  Timer? _promptTimer;

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    await VoiceService.instance.init();
    if (!mounted || _voiceListeningStarted) return;
    _voiceListeningStarted = true;
    
    _voiceSub = VoiceService.instance.textStream.listen((text) {
      if (!mounted || _saving) return;
      final normalized = text.toLowerCase().trim();
      if (normalized.isEmpty) return;
      
      if (normalized.contains('arabic') ||
          normalized.contains('عربي') ||
          normalized.contains('العربية') ||
          normalized == 'ar') {
        _chooseLanguage('ar');
      } else if (normalized.contains('english') ||
          normalized.contains('انجليزي') ||
          normalized.contains('إنجليزي') ||
          normalized == 'en') {
        _chooseLanguage('en');
      }
    });
    
    _startPromptLoop();
  }
  
  Future<void> _startPromptLoop() async {
    if (!mounted || _saving) return;
    
    // Stop listening before speaking
    await VoiceService.instance.stopListening();
    
    if (_isArabicTurn) {
      await VoiceService.instance.speakWithRetry(
        'مرحبا، أنا بصيرة. من فضلك اختر اللغة التي أتحدث بها.',
      );
    } else {
      await VoiceService.instance.speakWithRetry(
        'Hello, I am Baseera. Please choose the language I should speak.',
      );
    }
    
    // Start listening after speaking
    await VoiceService.instance.startContinuousListening();
    
    // Set a timer to prompt again in the other language if no response
    _promptTimer?.cancel();
    _promptTimer = Timer(const Duration(seconds: 7), () {
      if (mounted && !_saving) {
        _isArabicTurn = !_isArabicTurn;
        _startPromptLoop();
      }
    });
  }

  @override
  void dispose() {
    _promptTimer?.cancel();
    _voiceSub?.cancel();
    VoiceService.instance.stopListening();
    super.dispose();
  }

  Future<void> _chooseLanguage(String language) async {
    if (_saving) return;
    
    _promptTimer?.cancel();
    
    setState(() {
      _language = language;
      _saving = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    await prefs.setString('voice_language', language == 'ar' ? 'ar-EG' : 'en-US');
    L10n.setLanguage(language);

    if (!mounted) return;
    await VoiceService.instance.stopListening();
    await VoiceService.instance.stopSpeech();
    setState(() => _saving = false);
    Navigator.pushReplacementNamed(context, '/select-user');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.language_rounded,
                  size: 72, color: Color(0xFF5B8DEF)),
              const SizedBox(height: 20),
              const Text(
                'اختر اللغة',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'من فضلك اختر العربية أو الإنجليزية.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 36),
              _option(
                label: 'English / إنجليزي',
                sub: 'Keep everything in English / خلّي التطبيق بالإنجليزية',
                active: _language == 'en',
                color: const Color(0xFF38BDF8),
                onTap: () => _chooseLanguage('en'),
              ),
              const SizedBox(height: 16),
              _option(
                label: 'Arabic / عربي',
                sub: 'Arabic voice and UI / صوت وواجهة عربية',
                active: _language == 'ar',
                color: const Color(0xFFF59E0B),
                onTap: () => _chooseLanguage('ar'),
              ),
              if (_saving) ...[
                const SizedBox(height: 24),
                const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _option({
    required String label,
    required String sub,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 96,
      child: ElevatedButton(
        onPressed: _saving ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? color : const Color(0xFF111A2E),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: active ? color : Colors.white12),
          ),
        ),
        child: Row(
          children: [
            Icon(active ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(sub,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

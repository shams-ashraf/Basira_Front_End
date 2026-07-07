import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../services/voice_service.dart';

class CameraModeScreen extends StatefulWidget {
  const CameraModeScreen({super.key});

  @override
  State<CameraModeScreen> createState() =>
      _CameraModeScreenState();
}

class _CameraModeScreenState
    extends State<CameraModeScreen> with RouteAware {
  StreamSubscription<String>? _voiceSub;
  bool _navigating = false;
  static final RouteObserver<ModalRoute<void>> _observer =
      RouteObserver<ModalRoute<void>>();

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observer.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    _navigating = false;
    _initVoice();
  }

  Future<void> _initVoice() async {
    await _voiceSub?.cancel();
    _voiceSub = null;
    await VoiceService.instance.init();
    await VoiceService.instance.speakWithRetry(
      L10n.isArabic
          ? 'وضع الكاميرا. قل أشياء أو مشهد.'
          : 'Camera mode. Say objects or scene.',
    );
    await VoiceService.instance.startContinuousListening();
    _voiceSub = VoiceService.instance.textStream.listen((text) {
      if (!mounted || _navigating) return;
      final normalized = text.toLowerCase().trim();
      if (normalized.contains('scene') ||
          normalized.contains('مشهد') ||
        normalized.contains('summary')) {
        _goScene();
      } else if (normalized.contains('object') ||
          normalized.contains('objects') ||
          normalized.contains('أشياء') ||
          normalized.contains('اشياء')) {
        _goObject();
      }
    });
  }

  Future<void> _goObject() async {
    if (_navigating) return;
    _navigating = true;
    await VoiceService.instance.stopListening();
    if (!mounted) return;
    Navigator.pushNamed(context, '/esp-camera', arguments: {'mode': 'object'});
  }

  Future<void> _goScene() async {
    if (_navigating) return;
    _navigating = true;
    await VoiceService.instance.stopListening();
    if (!mounted) return;
    Navigator.pushNamed(context, '/esp-camera', arguments: {'mode': 'scene'});
  }

  @override
  void dispose() {
    _observer.unsubscribe(this);
    _voiceSub?.cancel();
    unawaited(VoiceService.instance.stopListening());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.maybePop(context),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text(L10n.isArabic ? 'الكاميرا' : 'Camera'),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _button(
                context,
                title: L10n.isArabic ? 'تعرّف على الأشياء' : 'Detect Objects',
                color: const Color(0xFF38BDF8),
                onTap: _goObject,
              ),
              const SizedBox(height: 16),
              _button(
                context,
                title: L10n.isArabic ? 'وصف المشهد' : 'Describe Scene',
                color: const Color(0xFFF59E0B),
                onTap: _goScene,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(
    BuildContext context, {
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 92,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
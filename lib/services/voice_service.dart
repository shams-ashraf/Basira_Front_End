import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'backend_service.dart';

class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();

  final _commandController = StreamController<String>.broadcast();
  Stream<String> get commandStream => _commandController.stream;

  final _textController = StreamController<String>.broadcast();
  Stream<String> get textStream => _textController.stream;

  final _responseController = StreamController<String>.broadcast();
  Stream<String> get responseStream => _responseController.stream;

  bool _isListening = false;
  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _resumeListeningAfterTts = false;
  bool _speechReady = false;
  String _lastSentText = "";

  Future<void> init() async {
    if (!_isInitialized) {
      await BackendService.instance
          .connectVoiceWebSocket(_handleBackendResponse);
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.45);
      await _tts.awaitSpeakCompletion(true);
      _isInitialized = true;
    }
    if (!_speechReady) {
      await _speech.initialize(
        onStatus: (status) => debugPrint("Speech status: $status"),
        onError: (error) => debugPrint("Speech error: $error"),
      );
      _speechReady = true;
    }
  }

  void _handleBackendResponse(Map<String, dynamic> data) async {
    final text = data['text'];
    final action = data['action'];
    final audioUrl = data['audio_url'];
    final error = data['error'];

    if (error != null) {
      _responseController.add(error.toString());
    }

    // If audio is provided, prioritize audio playback over text to avoid duplicate speech.
    if (audioUrl == null && text != null) {
      final responseText = text.toString();
      _textController.add(responseText);
      _responseController.add(responseText);
    }

    if (action != null) {
      _commandController.add(action.toString());
    }

    if (audioUrl != null) {
      _isProcessing = true;
      try {
        await _audioPlayer.setUrl(audioUrl.toString());
        await _audioPlayer.play();
      } catch (e) {
        debugPrint("Audio Playback Error: $e");
      } finally {
        _isProcessing = false;
      }
    }
  }

  Future<void> startContinuousListening() async {
    if (_isListening || _isProcessing) return;

    if (!_speechReady) {
      await init();
    }

    final available = _speechReady;

    if (!available) {
      debugPrint("Speech recognition unavailable on this device");
      return;
    }

    _isListening = true;
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
        cancelOnError: false,
        autoPunctuation: true,
      ),
      onResult: (result) {
        final recognized = result.recognizedWords.trim();
        if (recognized.isEmpty) return;

        _textController.add(recognized);

        if (result.finalResult && recognized != _lastSentText) {
          _lastSentText = recognized;
          BackendService.instance.sendVoiceText(recognized);
        }
      },
    );
  }

  Future<void> stopListening() async {
    _isListening = false;
    _lastSentText = "";
    await _speech.stop();
  }

  Future<void> pauseListening() async {
    _isListening = false;
    await _speech.stop();
  }

  Future<void> resumeListening() async {
    if (_isProcessing || _isListening) return;
    await startContinuousListening();
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      _resumeListeningAfterTts = _isListening;
      await pauseListening();
      await _tts.stop();
      final isArabic = text.contains(RegExp(r'[\u0600-\u06FF]'));
      await _tts.setLanguage(isArabic ? "ar-SA" : "en-US");
      await _tts.setSpeechRate(0.45);
      await _tts.speak(text);
    } catch (e) {
      debugPrint("TTS Error: $e");
    } finally {
      _isProcessing = false;
      if (_resumeListeningAfterTts) {
        _resumeListeningAfterTts = false;
        await startContinuousListening();
      }
    }
  }
}

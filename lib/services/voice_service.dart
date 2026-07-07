import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'localized_speech_text.dart';

/// VoiceService — always-on STT + independent TTS.
///
/// Design:
///   • STT runs continuously and NEVER pauses.
///   • TTS runs independently on its own "lane".
///   • During TTS playback a flag [_isTTSSpeaking] is set so that any
///     STT results picked up from the phone's own speaker (echo) are
///     silently discarded.
///   • If STT is disrupted by the OS audio-focus system, a heartbeat
///     timer restarts it within 500ms.
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  // ── Stream controllers ──────────────────────────────────────────────
  final _commandController = StreamController<String>.broadcast();
  Stream<String> get commandStream => _commandController.stream;

  final _textController = StreamController<String>.broadcast();
  Stream<String> get textStream => _textController.stream;

  final _responseController = StreamController<String>.broadcast();
  Stream<String> get responseStream => _responseController.stream;

  // ── State flags ─────────────────────────────────────────────────────
  bool _isListening = false;
  bool _isInitialized = false;
  bool _speechReady = false;
  bool _ttsReady = false;
  String _lastSentText = "";
  String _preferredLanguage = "en";
  Timer? _promptRetryTimer;
  Timer? _heartbeatTimer;
  final List<String> _speechQueue = [];
  bool _isSpeakingQueued = false;
  int _speechSessionId = 0;

  /// Whether continuous listening should be active.
  bool _shouldBeListening = false;

  /// True while TTS is actively playing audio.
  /// STT results received during this window are treated as echo and discarded.
  bool _isTTSSpeaking = false;

  /// Exposes whether TTS is currently speaking so callers can suppress
  /// command handling during self-audio windows.
  bool get isSpeaking => _isTTSSpeaking;

  /// Timestamp when TTS last finished — used to add a short echo-guard buffer.
  DateTime _ttsFinishedAt = DateTime(2000);

  /// Echo guard duration after TTS finishes (ignore STT for this long).
  static const _echoGuardMs = 1500;

  bool get isListening => _isListening;

  // ════════════════════════════════════════════════════════════════════
  // INIT
  // ════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    if (!_isInitialized) {
      await _loadPreferredLanguage();
      _isInitialized = true;
    }
    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onStatus: (status) {
          debugPrint('[VoiceService] STT status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            // Always try to restart — no _isProcessing check anymore
            if (_shouldBeListening) {
              debugPrint('[VoiceService] STT stopped, auto-restarting in 50ms...');
              Future.delayed(const Duration(milliseconds: 50), () {
                _restartListeningIfNeeded();
              });
            }
          }
        },
        onError: (error) {
          debugPrint('[VoiceService] STT error: $error');
          _isListening = false;
          if (_shouldBeListening) {
            debugPrint('[VoiceService] STT error recovery, restarting in 300ms...');
            Future.delayed(const Duration(milliseconds: 300), () {
              _restartListeningIfNeeded();
            });
          }
        },
      );
      debugPrint('[VoiceService] STT initialized: $_speechReady');
    }
    if (!_ttsReady) {
      await _configureTts();
      _ttsReady = true;
    }

    _startHeartbeat();
  }

  // ════════════════════════════════════════════════════════════════════
  // HEARTBEAT — aggressive STT keep-alive
  // ════════════════════════════════════════════════════════════════════

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_shouldBeListening && !_isListening) {
        debugPrint('[VoiceService] Heartbeat: STT not listening, restarting...');
        _restartListeningIfNeeded();
      }
    });
  }

  void _restartListeningIfNeeded() {
    if (!_shouldBeListening) return;
    if (_isListening) return;
    debugPrint('[VoiceService] _restartListeningIfNeeded -> starting STT');
    _startSTT();
  }

  // ════════════════════════════════════════════════════════════════════
  // LANGUAGE
  // ════════════════════════════════════════════════════════════════════

  Future<void> _loadPreferredLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _preferredLanguage = prefs.getString('language') ??
          (prefs.getString('voice_language')?.startsWith('ar') == true ? 'ar' : 'ar');
    } catch (_) {}
  }

  Future<void> _configureTts() async {
    try {
      await _tts.setSharedInstance(true);
      await _tts.awaitSpeakCompletion(true);
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _applyVoiceLanguage(_preferredLanguage);
    } catch (e) {
      debugPrint("[VoiceService] TTS config error: $e");
    }
  }

  Future<void> _applyVoiceLanguage(String language) async {
    try {
      if (language.startsWith('ar')) {
        final locales = await _tts.getLanguages;
        final arabicLocale = locales.cast<dynamic>().map((e) => e.toString()).firstWhere(
              (value) => value.toLowerCase().startsWith('ar'),
              orElse: () => 'ar-EG',
            );
        await _tts.setLanguage(arabicLocale);
      } else {
        await _tts.setLanguage('en-US');
      }
    } catch (e) {
      debugPrint("[VoiceService] TTS language error: $e");
    }
  }

  Future<String?> _preferredSpeechLocaleId() async {
    try {
      if (!_preferredLanguage.startsWith('ar')) return 'en_US';
      final locales = await _speech.locales();
      final arabic = locales.map((e) => e.localeId).where((id) => id.toLowerCase().startsWith('ar')).toList();
      return arabic.isNotEmpty ? arabic.first : 'ar_EG';
    } catch (_) {
      return _preferredLanguage.startsWith('ar') ? 'ar_EG' : 'en_US';
    }
  }

  String _prepareTextForSpeech(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return cleaned;
    if (!_preferredLanguage.startsWith('ar')) return cleaned;
    final hasLatin = RegExp(r'[A-Za-z]').hasMatch(cleaned);
    if (!hasLatin) return cleaned;
    final translated = LocalizedSpeechText.sceneCaption(cleaned, language: 'ar');
    return translated.isEmpty ? cleaned : translated;
  }

  // ════════════════════════════════════════════════════════════════════
  // STT — always-on, never explicitly paused by TTS
  // ════════════════════════════════════════════════════════════════════

  /// Whether we should ignore the current STT result (echo guard).
  bool _isEchoWindow() {
    if (_isTTSSpeaking) return true;
    // Also guard for a short time after TTS finishes
    final msSinceTTS = DateTime.now().difference(_ttsFinishedAt).inMilliseconds;
    return msSinceTTS < _echoGuardMs;
  }

  Future<void> _startSTT() async {
    if (_isListening) return;
    if (!_speechReady) {
      debugPrint('[VoiceService] STT not ready, cannot start');
      return;
    }

    final localeId = await _preferredSpeechLocaleId();
    debugPrint('[VoiceService] Starting STT with locale=$localeId');

    try {
      _isListening = true;
      await _speech.listen(
        localeId: localeId,
        listenFor: const Duration(hours: 1),
        pauseFor: const Duration(minutes: 5),
        cancelOnError: false,
        partialResults: true,
        onDevice: false,
        listenMode: stt.ListenMode.dictation,
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          autoPunctuation: true,
          onDevice: false,
        ),
        onResult: (result) {
          final recognized = result.recognizedWords.trim();
          if (recognized.isEmpty) return;

          // ── Echo filter: discard anything heard while TTS was playing ──
          if (_isEchoWindow()) {
            debugPrint('[VoiceService] STT echo discarded (TTS active): "$recognized"');
            return;
          }

          debugPrint('[VoiceService] STT heard: "$recognized" (final=${result.finalResult})');
          _textController.add(recognized);

          if (result.finalResult && recognized != _lastSentText) {
            _lastSentText = recognized;
            debugPrint('[VoiceService] Final result: "$recognized"');
          }
        },
      );
    } catch (e) {
      debugPrint('[VoiceService] STT listen error: $e');
      _isListening = false;
    }
  }

  /// Pause STT without changing _shouldBeListening
  Future<void> _pauseSTT() async {
    _isListening = false;
    try {
      await _speech.stop();
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════════════
  // TTS — independent lane, does NOT pause STT
  // ════════════════════════════════════════════════════════════════════

  /// Internal: speak text locally. Does NOT pause STT.
  /// Sets [_isTTSSpeaking] so the echo filter discards mic-captured output.
  Future<void> _speakLocally(String text) async {
    final speechText = _prepareTextForSpeech(text);
    if (speechText.isEmpty) return;

    debugPrint('[VoiceService] _speakLocally: "$speechText"');

    // Mark TTS as active — echo filter will discard STT results
    _isTTSSpeaking = true;

    try {
      await _applyVoiceLanguage(_preferredLanguage);
      await _tts.stop();
      await _tts.speak(speechText);
      debugPrint('[VoiceService] TTS finished speaking');
    } catch (e) {
      debugPrint("[VoiceService] TTS error: $e");
    }

    // TTS done — start echo-guard countdown
    _isTTSSpeaking = false;
    _ttsFinishedAt = DateTime.now();

    // If STT was disrupted by OS audio focus during TTS, restart it
    if (_shouldBeListening && !_isListening) {
      debugPrint('[VoiceService] STT disrupted during TTS, restarting...');
      Future.delayed(const Duration(milliseconds: 100), () {
        _restartListeningIfNeeded();
      });
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ════════════════════════════════════════════════════════════════════

  /// Start always-on continuous listening.
  Future<void> startContinuousListening() async {
    debugPrint('[VoiceService] startContinuousListening called');
    _shouldBeListening = true;
    if (_isListening) return;
    if (!_speechReady) {
      await init();
    }
    if (!_speechReady) {
      debugPrint("[VoiceService] Speech recognition unavailable on this device");
      return;
    }
    await _startSTT();
  }

  /// Fully stop listening (e.g. when leaving the screen).
  Future<void> stopListening() async {
    debugPrint('[VoiceService] stopListening called (full stop)');
    _shouldBeListening = false;
    _isListening = false;
    _lastSentText = "";
    _promptRetryTimer?.cancel();
    _promptRetryTimer = null;
    await _speech.stop();
  }

  Future<void> stopSpeech() async {
    _speechSessionId++;
    _promptRetryTimer?.cancel();
    _promptRetryTimer = null;
    _speechQueue.clear();
    _isSpeakingQueued = false;
    _isTTSSpeaking = false;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Pause listening temporarily (keeps _shouldBeListening true).
  Future<void> pauseListening() async {
    debugPrint('[VoiceService] pauseListening called');
    await _pauseSTT();
  }

  /// Resume listening if _shouldBeListening is true.
  Future<void> resumeListening() async {
    debugPrint('[VoiceService] resumeListening called');
    _shouldBeListening = true;
    if (_isListening) return;
    await _startSTT();
  }

  /// Speak text. STT stays running — echo filter handles self-hearing.
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _loadPreferredLanguage();
    final sessionId = _speechSessionId;
    _speechQueue.add(text);
    if (_isSpeakingQueued) return;
    _isSpeakingQueued = true;
    try {
      while (_speechQueue.isNotEmpty && sessionId == _speechSessionId) {
        final nextText = _speechQueue.removeAt(0);
        if (sessionId != _speechSessionId) break;
        try {
          await _speakLocally(nextText);
        } catch (e) {
          debugPrint("[VoiceService] TTS Error: $e");
        }
      }
    } finally {
      _isSpeakingQueued = false;
    }
  }

  Future<void> speakWithRetry(
    String text, {
    Duration retryAfter = const Duration(seconds: 5),
    int maxRepeats = 1,
  }) async {
    await interruptAndSpeak(text);
    _promptRetryTimer?.cancel();
    if (maxRepeats <= 0) return;
    var repeatsLeft = maxRepeats;
    _promptRetryTimer = Timer.periodic(retryAfter, (timer) async {
      repeatsLeft--;
      if (repeatsLeft < 0) {
        timer.cancel();
        return;
      }
      await interruptAndSpeak(text);
      if (repeatsLeft == 0) {
        timer.cancel();
      }
    });
  }

  Future<void> interruptAndSpeak(String text) async {
    debugPrint('[VoiceService] interruptAndSpeak: "$text"');
    await stopSpeech();
    _speechSessionId++;
    await speak(text);
  }

  /// Speak a DANGER alert with highest priority.
  Future<void> speakDangerAlert(String text) async {
    if (text.isEmpty) return;
    debugPrint('[VoiceService] ⚠️ DANGER ALERT: "$text"');
    await stopSpeech();
    _speechSessionId++;
    await speak(text);
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _promptRetryTimer?.cancel();
    _commandController.close();
    _textController.close();
    _responseController.close();
  }
}

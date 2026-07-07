import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import '../../camera_ai/camera_stream_widget.dart';
import '../../camera_ai/detection_result.dart';
import '../../camera_ai/camera_service.dart';
import '../../camera_ai/detection_api_service.dart';
import '../../camera_ai/control_button.dart';

import '../../config.dart';
import '../../services/ai_lab_api_service.dart';
import '../../services/announcement_builder.dart';
import '../../services/backend_service.dart';
import '../../services/voice_service.dart';
import '../../services/translation_service.dart';
import '../../l10n.dart';

class Esp32CameraScreen extends StatefulWidget {
  final String? initialMode;
  const Esp32CameraScreen({super.key, this.initialMode});

  @override
  State<Esp32CameraScreen> createState() => _Esp32CameraScreenState();
}

class _Esp32CameraScreenState extends State<Esp32CameraScreen>
    with WidgetsBindingObserver {
  bool _isStreaming = false;
  bool _isLoading = false;
  bool _hasError = false;

  // Real-time Monitoring & Mode state
  String _aiMode =
      'object'; // 'object', 'scene_vit', 'scene_blip', 'scene_florence'
  late String _runningMode;
  bool _modeInitialized = false;
  Timer? _monitoringTimer;
  bool _isDetecting = false; // prevents overlapping requests
  int _captureIntervalSeconds = 3;
  int _captureMaxWidth = 1280;
  int _obstacleThresholdCm = 100;
  bool _debugMode = false;
  bool _isBackendHealthy = false;

  // Results
  List<DetectionItem> _latestDetections = [];
  String _latestSceneSummary = '';
  String _lastDetectionTime = '';
  double _lastProcessingTimeMs = 0;
  String _detectionErrorMessage = '';

  // Language & Alerts variables
  String? _lastSpeech;
  DateTime? _lastEmergencyAlertAt;
  DateTime? _lastUnknownAlertAt;
  final Map<String, DateTime> _dangerCooldown = {};
  DateTime? _lastObstacleAlertAt;
  String _language = 'en';
  bool _hasPlayedOnboarding = false;
  Future<void>? _settingsInitFuture;
  StreamSubscription<String>? _voiceSubscription;
  bool _isListeningVoice = false;
  DateTime? _lastVoiceTriggerAt;
  DateTime? _ignoreVoiceCommandsUntil;

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);

  _runningMode = widget.initialMode ?? 'safety';

  if (widget.initialMode != null) {
    _runningMode = widget.initialMode ?? 'safety';
    _applyInitialMode(widget.initialMode!);
    _modeInitialized = true;
  }

  _settingsInitFuture = _initLanguageAndSettings();
  _checkBackendHealthy();

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _settingsInitFuture;
    if (!mounted) return;
    if (mounted && !_isStreaming) {
      _startStream();
    }
    _playVoiceOnboarding();
  });

  _voiceSubscription =
      VoiceService.instance.textStream.listen(_handleVoiceCommand);
}

  void _handleVoiceCommand(String text) {
    if (text.isEmpty) return;
    if (_ignoreVoiceCommandsUntil != null &&
        DateTime.now().isBefore(_ignoreVoiceCommandsUntil!)) {
      debugPrint('[VoiceCommand] Ignored during app speech guard: "$text"');
      return;
    }
    if (VoiceService.instance.isSpeaking) {
      debugPrint('[VoiceCommand] Ignored while TTS is speaking: "$text"');
      return;
    }
    
    // Cooldown to prevent self-triggering loops (wait 3 seconds after last trigger)
    if (_lastVoiceTriggerAt != null && DateTime.now().difference(_lastVoiceTriggerAt!) < const Duration(seconds: 3)) {
      return;
    }

    final lower = text.toLowerCase();
    
    // Safety Mode
    if (lower.contains('أمان') || lower.contains('حماية') || lower.contains('سلامة') || lower.contains('safety') || lower.contains('default') || lower.contains('ارجع') || lower.contains('عادي')) {
      _lastVoiceTriggerAt = DateTime.now();
      debugPrint('[VoiceCommand] Triggered: Safety Mode');
      _switchModeVoice('safety', 'object', 'حسنا، العودة لوضع الأمان.', 'Okay, returning to safety mode.');
      return;
    }
    
    // Explore Mode
    if (lower.contains('استكشاف') || lower.contains('حاجات') || lower.contains('أشياء') || lower.contains('إيه اللي قدامي') || lower.contains('explore') || lower.contains('objects') || lower.contains('around me') || lower.contains('what is in front of me')) {
      _lastVoiceTriggerAt = DateTime.now();
      debugPrint('[VoiceCommand] Triggered: Explore Mode');
      _switchModeVoice('explore', 'object', 'حسنا، الآن وضع الاستكشاف.', 'Okay, now in exploration mode.');
      return;
    }
    
    // Brief Scene
    if (lower.contains('مختصر') || lower.contains('سريع') || lower.contains('نظرة') || lower.contains('صورة') || lower.contains('brief') || lower.contains('quick') || lower.contains('fast')) {
      _lastVoiceTriggerAt = DateTime.now();
      debugPrint('[VoiceCommand] Triggered: Brief Scene');
      _switchModeVoice('scene_brief', 'scene_blip', 'حسنا، الآن أخذ لقطة سريعة.', 'Okay, now taking a brief look.');
      return;
    }
    
    // Detailed Scene
    if (lower.contains('مفصل') || lower.contains('تفصيل') || lower.contains('دقيق') || lower.contains('وصف كامل') || lower.contains('أوصف') || lower.contains('detailed') || lower.contains('describe') || lower.contains('full')) {
      _lastVoiceTriggerAt = DateTime.now();
      debugPrint('[VoiceCommand] Triggered: Detailed Scene');
      _switchModeVoice('scene_detailed', 'scene_florence', 'حسنا، أنت الآن في وضع الوصف المفصل.', 'Okay, now giving a detailed description.');
      return;
    }
    
    // "What is your name?" handler
    if (lower.contains('اسمك') || lower.contains('إسمك') || lower.contains('your name') || lower.contains('what is your name') || lower.contains('who are you')) {
      _lastVoiceTriggerAt = DateTime.now();
      debugPrint('[VoiceCommand] Triggered: What is your name');
      _answerNameQuestion();
      return;
    }
  }

  void _switchModeVoice(String modeKey, String aiModeKey, String arMessage, String enMessage) {
    debugPrint('[esp32_camera] Switching mode to: $modeKey, AI mode: $aiModeKey');
    if (_runningMode == modeKey) return; 
    _ignoreVoiceCommandsUntil = DateTime.now().add(const Duration(seconds: 6));
    setState(() {
      _runningMode = modeKey;
      _lastSpeech = null; // Reset so first frame in new mode always speaks
    });
    _applyInitialMode(modeKey);
    _setAiMode(aiModeKey);
    
    final isAr = _language == 'ar' || L10n.isArabic;
    VoiceService.instance.interruptAndSpeak(isAr ? arMessage : enMessage);
  }

  Future<void> _answerNameQuestion() async {
    final prefs = await SharedPreferences.getInstance();
    final childName = prefs.getString('child_name') ?? '';
    final isAr = _language == 'ar' || L10n.isArabic;
    
    String answer;
    if (childName.isNotEmpty) {
      answer = isAr
          ? 'أنا بصيرة، مساعدك الذكي. وأنت اسمك $childName.'
          : 'I am Basira, your smart assistant. And your name is $childName.';
    } else {
      answer = isAr
          ? 'أنا بصيرة، مساعدك الذكي.'
          : 'I am Basira, your smart assistant.';
    }
    debugPrint('[VoiceCommand] 🔊 Answering name: $answer');
    await VoiceService.instance.interruptAndSpeak(answer);
  }

  Future<void> _playVoiceOnboarding() async {
    if (_hasPlayedOnboarding) return;
    await _settingsInitFuture;
    final mode = widget.initialMode ?? 'safety';
    if (mode != 'safety') {
      // If not safety, still we should start capturing
      if (!_isDetecting) {
        _processNextFrame();
      }
      return;
    }
    
    _hasPlayedOnboarding = true;
    await VoiceService.instance.init();
    
    final prefs = await SharedPreferences.getInstance();
    final childName = prefs.getString('child_name') ?? '';
    final isAr = _language == 'ar' || L10n.isArabic;
    
    final greeting = isAr
        ? 'مرحبا $childName. وضع الأمان يعمل الآن.'
        : 'Welcome $childName. Safety mode is now active.';

    debugPrint('[ESP32] 🔊 Speaking greeting: $greeting');
    _ignoreVoiceCommandsUntil = DateTime.now().add(const Duration(seconds: 6));
    await VoiceService.instance.speakWithRetry(greeting, maxRepeats: 0);
    _ignoreVoiceCommandsUntil = DateTime.now().add(const Duration(seconds: 2));
    
    // Start capturing after greeting finishes
    if (!mounted) return;
    setState(() => _isListeningVoice = true);
    await VoiceService.instance.startContinuousListening();
    
    if (!_isDetecting) {
      _processNextFrame();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      if (_isStreaming) {
        _startMonitoringTimer();
      } else {
        _startStream();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopMonitoringTimer();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_modeInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      final mode = args?['mode'] as String?;
      if (mode != null) {
        _runningMode = mode;
        _applyInitialMode(mode);
      } else {
        _runningMode = widget.initialMode ?? 'safety';
        _applyInitialMode(_runningMode);
      }
      _modeInitialized = true;
    }
  }

  void _applyInitialMode(String mode) {
    if (mode == 'safety') {
      _aiMode = 'object';
    } else if (mode == 'explore' || mode == 'object') {
      _aiMode = 'object';
    } else if (mode == 'scene_brief') {
      _aiMode = 'scene_blip';
    } else if (mode == 'scene_detailed') {
      _aiMode = 'scene_florence';
    } else {
      _aiMode = 'object';
    }
  }

  Future<void> _initLanguageAndSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _language = prefs.getString('language') ??
            (prefs.getString('voice_language')?.startsWith('ar') == true
                ? 'ar'
                : 'en');
        _captureIntervalSeconds =
            prefs.getInt('esp32_capture_interval') ?? _captureIntervalSeconds;
        _captureMaxWidth =
            prefs.getInt('esp32_capture_max_width') ?? _captureMaxWidth;
        _obstacleThresholdCm =
            prefs.getInt('esp32_obstacle_threshold_cm') ?? _obstacleThresholdCm;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isStreaming = false;
    _stopMonitoringTimer();
    _voiceSubscription?.cancel();
    VoiceService.instance.stopListening();
    VoiceService.instance.stopSpeech();
    super.dispose();
  }

  Future<void> _checkBackendHealthy() async {
    final healthy = await AILabApiService.instance.ping();
    if (mounted) {
      setState(() {
        _isBackendHealthy = healthy;
      });
    }
  }

  void _startStream() {
    setState(() {
      _isStreaming = true;
      _hasError = false;
      _detectionErrorMessage = '';
      _latestDetections = [];
      _latestSceneSummary = '';
    });
    _startMonitoringTimer();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _stopStream() {
    _stopMonitoringTimer();
    setState(() {
      _isStreaming = false;
      _isLoading = false;
      _hasError = false;
      _isDetecting = false;
      _latestDetections = [];
      _latestSceneSummary = '';
    });
  }

  Future<void> _setAiMode(String mode) async {
    if (_aiMode == mode) return;

    _stopMonitoringTimer();
    setState(() {
      _aiMode = mode;
      _isDetecting = false;
      _latestDetections = [];
      _latestSceneSummary = '';
      _detectionErrorMessage = '';
    });

    if (_isStreaming) {
      _startMonitoringTimer(triggerImmediately: true);
    }
  }

  void _startMonitoringTimer({bool triggerImmediately = false}) {
    _stopMonitoringTimer();
    if (triggerImmediately) {
      _processNextFrame();
    }
    _monitoringTimer = Timer.periodic(
      Duration(seconds: _captureIntervalSeconds),
      (_) => _processNextFrame(),
    );
  }

  void _stopMonitoringTimer() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  Future<void> _updateInterval(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('esp32_capture_interval', seconds);
    setState(() {
      _captureIntervalSeconds = seconds;
    });
    if (_isStreaming) {
      _startMonitoringTimer();
    }
  }

  Future<void> _updateImagePrefs({int? quality, int? maxWidth}) async {
    final prefs = await SharedPreferences.getInstance();
    if (quality != null) {
      await prefs.setInt('esp32_capture_quality', quality);
    }
    if (maxWidth != null) {
      await prefs.setInt('esp32_capture_max_width', maxWidth);
    }
    if (mounted) {
      setState(() {
        if (maxWidth != null) _captureMaxWidth = maxWidth;
      });
    }
  }

  Future<File> _prepareImageFile(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return file;
    final resized = decoded.width > _captureMaxWidth
        ? img.copyResize(decoded, width: _captureMaxWidth)
        : decoded;
    final quality = 85;
    final encoded = img.encodeJpg(resized, quality: quality);
    final processed = File(
        '${file.parent.path}/${file.uri.pathSegments.last.replaceFirst('.jpg', '')}_p.jpg');
    await processed.writeAsBytes(encoded);
    return processed;
  }

  double _estimateSharpness(img.Image source) {
    final gray = img.grayscale(source);
    double total = 0;
    int count = 0;
    for (int y = 1; y < gray.height - 1; y += 2) {
      for (int x = 1; x < gray.width - 1; x += 2) {
        final c = gray.getPixel(x, y).r.toDouble();
        final dx = (c - gray.getPixel(x + 1, y).r).abs();
        final dy = (c - gray.getPixel(x, y + 1).r).abs();
        total += dx + dy;
        count += 2;
      }
    }
    return count == 0 ? 0 : total / count;
  }

  String _midasSpeech(Map<String, dynamic> result) {
    final severity =
        (result['midas_severity'] ?? '').toString().toLowerCase().trim();
    final midasDistanceCm = result['midas_distance_cm'];
    final distanceValue = midasDistanceCm is num
        ? midasDistanceCm.toDouble()
        : double.tryParse('${midasDistanceCm ?? ''}');
    const obstacleThresholdCm = 100;

    if (distanceValue != null && distanceValue > obstacleThresholdCm) return '';
    if (severity.isEmpty) return '';

    final distStr =
        distanceValue != null ? '${distanceValue.round()} cm' : '';
    final hasDistance = distStr.isNotEmpty;

    if (_language == 'ar') {
      if (severity == 'critical') {
        return hasDistance
            ? 'تنبيه خطر، يوجد عائق قريب جدًا أمامك على مسافة $distStr.'
            : 'تنبيه خطر، يوجد عائق قريب جدًا أمامك.';
      }
      if (severity == 'warning') {
        return hasDistance
            ? 'احذر، يوجد عائق أمامك على مسافة $distStr.'
            : 'احذر، يوجد عائق أمامك.';
      }
      return '';
    }

    if (severity == 'critical') {
      return hasDistance
          ? 'Danger! Very close obstacle ahead, at $distStr.'
          : 'Danger! Very close obstacle ahead.';
    }
    if (severity == 'warning') {
      return hasDistance
          ? 'Caution, obstacle ahead at $distStr.'
          : 'Caution, obstacle ahead.';
    }
    return '';
  }

  String _speechText(Map<String, dynamic> result) {
    // Check if MiDaS detected an obstacle within threshold
    final midasSpeech = _midasSpeech(result);
    if (midasSpeech.isNotEmpty) return midasSpeech;

    // No obstacle → use YOLO result (spoken_text already built on backend)
    final spokenText = (result['spoken_text'] ?? '').toString().trim();
    final spokenTextAr = (result['spoken_text_ar'] ?? '').toString().trim();
    if (_language == 'ar' && spokenTextAr.isNotEmpty) return spokenTextAr;
    if (spokenText.isNotEmpty) return spokenText;
    if (_language == 'ar' &&
        (result['speech_ar'] ?? '').toString().trim().isNotEmpty) {
      return (result['speech_ar'] ?? '').toString().trim();
    }
    if ((result['speech'] ?? '').toString().trim().isNotEmpty) {
      return (result['speech'] ?? '').toString().trim();
    }
    return '';
  }

  bool _isDangerousLabel(String value) {
    switch (value.toLowerCase().trim()) {
      case 'knife':
      case 'scissors':
      case 'glass':
      case 'fire':
      case 'blade':
      case 'gun':
        return true;
      default:
        return false;
    }
  }

  List<String> _orderedDetectionsForSpeech(List<String> detectedObjects) {
    final seen = <String>{};
    final ordered = <String>[];
    final priority = <String>[
      'knife',
      'scissors',
      'glass',
      'fire',
      'person',
    ];

    for (final label in priority) {
      for (final obj in detectedObjects) {
        if (obj.toLowerCase() == label && seen.add(obj)) {
          ordered.add(obj);
        }
      }
    }

    for (final obj in detectedObjects) {
      if (seen.add(obj)) {
        ordered.add(obj);
      }
    }
    return ordered;
  }

  String _formatLabelForSpeech(String value) {
    final trimmed = value.trim();
    if (_language == 'ar') {
      return _arLabel(trimmed);
    }
    return trimmed;
  }

  String _buildObjectSentence(List<String> objects, {required bool onDemand}) {
    if (objects.isEmpty) return '';
    final ordered = _orderedDetectionsForSpeech(objects)
        .map(_formatLabelForSpeech)
        .toList();
    if (ordered.isEmpty) return '';
    if (_language == 'ar') {
      final joined = ordered.join('، ');
      return onDemand ? 'يوجد $joined أمامك.' : joined;
    }
    final joined = ordered.join(', ');
    return onDemand ? 'I can see $joined in front of you.' : joined;
  }

  Future<void> _speakQueued(List<String> messages) async {
    for (final message in messages) {
      final cleaned = message.trim();
      if (cleaned.isEmpty) continue;
      await VoiceService.instance.speak(cleaned);
    }
  }

  String _speechPosition(Map<String, dynamic> result) {
    final value = (result['position'] ?? result['spatial_position'] ?? '')
        .toString()
        .trim();
    if (value.isNotEmpty) return value;
    return 'center';
  }

  String _speechDistance(Map<String, dynamic> result) {
    final value = (result['distance_text'] ?? result['distanceText'] ?? '')
        .toString()
        .trim();
    if (value.isNotEmpty) return value;
    final scoreValue = result['best_score'] ?? result['bestScore'];
    final score = scoreValue is num ? scoreValue.toDouble() : 0.0;
    if (score >= 0.8) return 'very close';
    if (score >= 0.6) return 'close';
    return 'far';
  }

  String _arPosition(String value) {
    switch (value) {
      case 'left':
        return 'يسارك';
      case 'right':
        return 'يمينك';
      case 'center':
        return 'أمامك';
      default:
        return value;
    }
  }

  String _arLabel(String value) {
    switch (value) {
      case 'chair':
        return 'كرسي';
      case 'hanger':
        return 'شماعة';
      case 'fork':
        return 'شوكة';
      case 'knife':
        return 'سكين';
      case 'scissors':
        return 'مقص';
      case 'person':
        return 'شخص';
      default:
        return value;
    }
  }

  String _arDistance(String value) {
    switch (value) {
      case 'very close':
        return 'قريبة جدًا';
      case 'close':
        return 'قريبة';
      case 'far':
        return 'بعيدة';
      default:
        return value;
    }
  }

  String _arEmotion(String value) {
    switch (value.toLowerCase()) {
      case 'happy':
        return 'سعيد';
      case 'sad':
        return 'حزين';
      case 'angry':
        return 'غاضب';
      case 'fear':
        return 'خائف';
      case 'surprise':
        return 'مندهش';
      case 'disgust':
        return 'مشمئز';
      case 'neutral':
        return 'طبيعي';
      default:
        return value;
    }
  }

  Future<void> _processNextFrame() async {
    if (!_isStreaming || _isDetecting) return;

    setState(() {
      _isDetecting = true;
    });

    try {
      debugPrint('[ESP32] ─── Frame capture start ───');
      final Uint8List? imageBytes = await DetectionApiService.captureFrame();

      if (imageBytes == null) {
        debugPrint('[ESP32] ✗ Frame capture FAILED (null bytes)');
        if (mounted && _isStreaming) {
          setState(() {
            _detectionErrorMessage = 'Failed to capture frame from ESP32';
          });
        }
        return;
      }

      if (!_isStreaming) return;

      debugPrint('[ESP32] ✓ Frame captured (${imageBytes.length} bytes), mode=$_runningMode, aiMode=$_aiMode');
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/esp32_captured.jpg');
      await tempFile.writeAsBytes(imageBytes);
      File uploadFile = await _prepareImageFile(tempFile);
      debugPrint('[ESP32] ✓ Image prepared for upload');

      if (_runningMode == 'object' || _runningMode == 'safety' || _runningMode == 'explore') {
        Map<String, dynamic> result = {
          'success': false,
          'detections': [],
          'detected_objects': [],
          'objects': [],
          'person_detected': false,
          'timestamp': DateTime.now().toIso8601String()
        };

        // ── Server (MiDaS + Face + YOLO) ──
        try {
          final timeoutSecs = AppConfig.serverTimeoutSeconds;
          debugPrint('[ESP32] Sending image to server (timeout=${timeoutSecs}s)...');
          final serverResult = await AILabApiService.instance
              .runObjectDetection(uploadFile.path)
              .timeout(Duration(seconds: timeoutSecs));

          if (serverResult['success'] == true) {
            result['success'] = true;
            result['midas_distance_cm'] = serverResult['midas_distance_cm'];
            if (serverResult['person_detected'] == true) {
              result['person_detected'] = true;
            }
            result['best_match'] = serverResult['best_match'];
            result['best_score'] = serverResult['best_score'];
            
            // Override with server detections if present
            if (serverResult['detections'] != null) {
              result['detections'] = serverResult['detections'];
            }
            if (serverResult['detected_objects'] != null) {
              result['detected_objects'] = serverResult['detected_objects'];
              result['objects'] = serverResult['detected_objects'];
            }
            if (serverResult['spoken_text'] != null) {
              result['spoken_text'] = serverResult['spoken_text'];
            }
            if (serverResult['spoken_text_ar'] != null) {
              result['spoken_text_ar'] = serverResult['spoken_text_ar'];
            }
            if (serverResult['alert_message'] != null) {
              result['alert_message'] = serverResult['alert_message'];
              result['alert_type'] = serverResult['alert_type'];
            }

            if (serverResult['timings'] != null) {
              result['timings'] = serverResult['timings'];
            }
            debugPrint('[ESP32] ✓ Server OK — MiDaS: ${serverResult['midas_distance_cm']}cm, Match: ${serverResult['best_match']}, ServerSpeech: ${serverResult['spoken_text_ar']}');
          } else {
            debugPrint('[ESP32] ✗ Server returned error: ${serverResult['error']}');
          }
        } catch (e) {
          debugPrint('[ESP32] ✗ Server unreachable: $e (using local YOLO only)');
        }

        if (!mounted || !_isStreaming) return;
        if (_runningMode != 'object' && _runningMode != 'safety' && _runningMode != 'explore') return;

        // ── Update UI ──
        setState(() {
          if (result['success'] == true) {
            final list = result['detections'] as List<dynamic>? ?? [];
            _latestDetections = list.map((i) => DetectionItem.fromJson(i)).toList();
            _lastDetectionTime = result['timestamp'] ?? DateTime.now().toIso8601String();
            final timings = result['timings'] as Map<String, dynamic>?;
            if (timings != null && timings['Total Time'] != null) {
              final timeStr = timings['Total Time'].toString().replaceAll('s', '');
              _lastProcessingTimeMs = (double.tryParse(timeStr) ?? 0.0) * 1000.0;
            } else {
              _lastProcessingTimeMs = 0.0;
            }
            _detectionErrorMessage = '';
          } else {
            _detectionErrorMessage = result['error'] ?? 'Detection failure';
          }
        });

        if (result['success'] != true) return;

        // ── DANGER CHECK (highest priority — pauses STT, speaks, resumes) ──
        final detectedObjects2 = List<String>.from(result['detected_objects'] ?? result['objects'] ?? []);
        final dangerousObjects = detectedObjects2.where(_isDangerousLabel).toList();

        if (dangerousObjects.isNotEmpty) {
          debugPrint('[ESP32] ⚠️ DANGER DETECTED: $dangerousObjects');
          final now = DateTime.now();
          if (_lastEmergencyAlertAt == null ||
              now.difference(_lastEmergencyAlertAt!) >= const Duration(seconds: 10)) {
            final prefs = await SharedPreferences.getInstance();
            final childId = prefs.getString('linked_child_id') ??
                prefs.getString('child_id') ??
                prefs.getString('auth_id') ?? '0';
            for (final obj in dangerousObjects) {
              final last = _dangerCooldown[obj];
              if (last == null || now.difference(last) >= const Duration(seconds: 15)) {
                _dangerCooldown[obj] = now;
                _lastEmergencyAlertAt = now;
                final arabicLabel = obj == 'knife' ? 'سكين' : 'مقص';
                // Danger speech — this pauses STT, speaks, then auto-resumes
                final dangerSpeech = _language == 'ar'
                    ? 'تحذير! يوجد $arabicLabel أمامك. ابتعد فوراً!'
                    : 'Warning! A $obj is in front of you. Move away immediately!';
                debugPrint('[ESP32] 🔊 Speaking danger alert: $dangerSpeech');
                await VoiceService.instance.speakDangerAlert(dangerSpeech);
                // Also send to parent
                final alertMsg = _language == 'ar'
                    ? 'تنبيه خطر! تم رصد $arabicLabel أمام الطفل.'
                    : 'Danger alert! $obj detected in front of the child.';
                unawaited(BackendService.instance.sendChildAlert(
                  childId: childId, message: alertMsg, type: 'Emergency',
                ));
              }
            }
          }
        }

        // ── MiDaS Obstacle Alert (backend is the single source of truth) ──
        final alertType = (result['alert_type'] ?? '').toString();
        final alertMessage = (result['alert_message'] ?? '').toString().trim();
        if ((alertType == 'warning' || alertType == 'critical') && alertMessage.isNotEmpty) {
          debugPrint('[ESP32] ⚠️ Backend obstacle alert type=$alertType message=$alertMessage');
          final now = DateTime.now();
          if (_lastObstacleAlertAt == null ||
              now.difference(_lastObstacleAlertAt!) >= const Duration(seconds: 8)) {
            _lastObstacleAlertAt = now;

            debugPrint('[ESP32] 🔊 Speaking obstacle alert: $alertMessage');
            await VoiceService.instance.speakDangerAlert(alertMessage);

            final prefs = await SharedPreferences.getInstance();
            final childId = prefs.getString('linked_child_id') ??
                prefs.getString('child_id') ??
                prefs.getString('auth_id') ?? '0';
            unawaited(BackendService.instance.sendChildAlert(
              childId: childId,
              message: alertMessage,
              type: alertType == 'critical' ? 'Emergency' : 'Obstacle',
            ));
          }
        }

        // ── Person Detection (Known + Unknown) ──
        final isPerson = (result['person_detected'] ?? result['personDetected']) == true;
        final bestMatch = (result['best_match'] ?? result['bestMatch'] ?? 'Unknown').toString().trim();
        final scoreValue = result['best_score'] ?? result['bestScore'];
        final bestScore = scoreValue is num ? scoreValue.toDouble() : 0.0;
        final isRecognizedPerson = isPerson &&
            bestMatch.isNotEmpty && bestMatch.toLowerCase() != 'unknown' && bestScore >= 0.5;
        final isUnknownPerson = isPerson && !isRecognizedPerson;

        if (isRecognizedPerson) {
          // Known person: announce their name
          final now = DateTime.now();
          if (_lastUnknownAlertAt == null ||
              now.difference(_lastUnknownAlertAt!) >= const Duration(seconds: 10)) {
            _lastUnknownAlertAt = now;
            final distText = result['midas_distance_text'] ?? '';
            final personSpeech = _language == 'ar'
                ? 'يوجد $bestMatch أمامك${distText.toString().isNotEmpty ? " $distText" : ""}.'
                : '$bestMatch is in front of you${distText.toString().isNotEmpty ? " at $distText" : ""}.'
                ;
            debugPrint('[ESP32] 🔊 Recognized person: $personSpeech');
            await _speakQueued([personSpeech]);
          }
        } else if (isUnknownPerson) {
          // Unknown person: alert child + send to parent
          final now = DateTime.now();
          if (_lastUnknownAlertAt == null ||
              now.difference(_lastUnknownAlertAt!) >= const Duration(seconds: 20)) {
            _lastUnknownAlertAt = now;
            final unknownSpeech = _language == 'ar'
                ? 'تنبيه! يوجد شخص غير معروف أمامك.'
                : 'Alert! An unknown person is in front of you.';
            debugPrint('[ESP32] 🔊 Unknown person alert: $unknownSpeech');
            await VoiceService.instance.speakDangerAlert(unknownSpeech);
            final prefs = await SharedPreferences.getInstance();
            final childId = prefs.getString('linked_child_id') ??
                prefs.getString('child_id') ??
                prefs.getString('auth_id') ?? '0';
            unawaited(BackendService.instance.recordCapturedPhotoAsUnknown(tempFile.path));
            unawaited(BackendService.instance.sendChildAlert(
              childId: childId,
              message: _language == 'ar'
                  ? 'تنبيه! تم رصد شخص مجهول أمام الطفل.'
                  : 'Alert! An unknown person was detected in front of the child.',
              type: 'Unknown',
            ));
          }
        }

        // ── Normal object announcements ──
        // Safety checks (danger objects, MiDaS obstacles, unknown persons) already ran above
        // and always run in ALL modes. Now handle normal object announcements:
        //   - EXPLORE: announce objects using the detailed server speech (which includes distance)
        //   - SAFETY: do nothing (only safety alerts matter, already spoken above)
        final isExploreMode = _runningMode == 'explore';
        
        if (isExploreMode) {
          // First try server-built speech (includes object + distance)
          String serverSpeech = (_language == 'ar'
              ? (result['spoken_text_ar'] ?? result['speech_ar'] ?? '')
              : (result['spoken_text'] ?? result['speech'] ?? '')).toString().trim();
          debugPrint('[ESP32] 📋 Explore — serverSpeech: "$serverSpeech"');
          
          // If server speech is empty, build local announcement from detected objects
          if (serverSpeech.isEmpty && detectedObjects2.isNotEmpty) {
            debugPrint('[ESP32] 📋 Explore — server speech empty, building local speech from ${detectedObjects2.length} objects');
            // Use the detections list to build rich speech with positions & distances
            final detList = result['detections'] as List<dynamic>? ?? [];
            List<String> objectParts = [];
            for (final det in detList) {
              if (det is! Map) continue;
              final label = (det['label'] ?? '').toString();
              if (label.isEmpty || label == 'person') continue;
              final box = det['box'];
              if (box is List && box.length >= 4) {
                final cx = ((box[0] as num) + (box[2] as num)) / 2.0;
                // Simple position estimation
                String pos;
                if (_language == 'ar') {
                  pos = cx < 213 ? 'شمالك' : (cx > 427 ? 'يمينك' : 'قدامك');
                } else {
                  pos = cx < 213 ? 'left' : (cx > 427 ? 'right' : 'center');
                }
                final arLabel = _arLabel(label);
                if (_language == 'ar') {
                  objectParts.add('يوجد $arLabel في $pos');
                } else {
                  final article = 'aeiou'.contains(label[0].toLowerCase()) ? 'an' : 'a';
                  objectParts.add('I see $article $label on your $pos');
                }
              } else {
                final arLabel = _arLabel(label);
                if (_language == 'ar') {
                  objectParts.add('يوجد $arLabel أمامك');
                } else {
                  objectParts.add('I see $label in front of you');
                }
              }
            }
            if (objectParts.isNotEmpty) {
              serverSpeech = _language == 'ar'
                  ? objectParts.join('، ') + '.'
                  : objectParts.join(', ') + '.';
            }
          }
          
          List<String> announcements = [];
          if (serverSpeech.isNotEmpty) {
            announcements = [serverSpeech];
          }
          
          if (announcements.isNotEmpty) {
            final signature = announcements.join(' | ');
            if (signature != _lastSpeech) {
              _lastSpeech = signature;
              debugPrint('[ESP32] 🔊 Explore speaking: $announcements');
              await _speakQueued(announcements);
              // Reset so next frame speaks again even if same objects
              _lastSpeech = null;
            }
          }
        }
        // Safety mode: normal objects are NOT announced. Only danger/obstacle/person alerts
        // (already handled above) are spoken.

        // Explore mode runs continuously until explicitly switched by voice or button.
        // It does NOT revert to safety automatically after one frame.

      } else if (_runningMode.startsWith('scene')) {
        String modelType = 'blip';
        if (_aiMode == 'scene_florence') modelType = 'florence';

        Map<String, dynamic> result;
        try {
          debugPrint('[ESP32] Querying Server for Scene ($modelType)...');
          final timeoutSecs = AppConfig.serverTimeoutSeconds;
          result = await AILabApiService.instance
              .runSceneSummaryModel(uploadFile.path, modelType)
              .timeout(Duration(seconds: timeoutSecs));
          debugPrint('[ESP32] ✓ Scene result: ${result['caption_sentence'] ?? result['caption'] ?? 'empty'}');
        } catch (e) {
          debugPrint('[ESP32] ✗ Scene server error: $e');
          result = {'error': 'timeout or server offline'};
        }

        if (mounted && _isStreaming && _runningMode.startsWith('scene')) {
          setState(() {
            if (result['error'] == null) {
              _latestSceneSummary = result['caption_sentence'] ?? result['caption'] ?? '';
              _lastDetectionTime = DateTime.now().toIso8601String();
              _lastProcessingTimeMs = (result['time_ms'] as num?)?.toDouble() ?? 0.0;
              _detectionErrorMessage = '';
            } else {
              _detectionErrorMessage = result['error'] ?? 'Scene summary failure';
            }
          });

          if (result['error'] == null) {
            String speech = result['caption_sentence']?.toString() ?? result['caption']?.toString() ?? '';
            
            if (speech.isNotEmpty && _language == 'ar') {
              speech = await LocalTranslationService.instance.translate(speech);
            }

            if (speech.isNotEmpty && speech != _lastSpeech) {
              _lastSpeech = speech;
              debugPrint('[ESP32] 🔊 Scene speech: $speech');
              await _speakQueued([speech]);
            }
          }
          
          _revertToSafetyIfNeeded();
        }
      }

      debugPrint('[ESP32] ─── Frame done ───');
    } finally {
      // ALWAYS reset detecting flag
      if (mounted) {
        setState(() {
          _isDetecting = false;
        });
      } else {
        _isDetecting = false;
      }
    }
  }

  String _formatTimestamp(String timestamp) {
    if (timestamp.isEmpty) return '--';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.maybePop(context),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        centerTitle: true,
        title: Text(
          _runningMode == 'safety'
              ? 'Safety Mode'
              : _runningMode == 'explore'
                  ? 'Explore Mode'
                  : 'Scene Mode',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isListeningVoice)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.mic, color: Colors.greenAccent, size: 20),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  Icons.dns_rounded,
                  size: 16,
                  color:
                      _isBackendHealthy ? Colors.greenAccent : Colors.redAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  _isBackendHealthy ? 'API OK' : 'API ERR',
                  style: TextStyle(
                    color: _isBackendHealthy
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      size: 18, color: Colors.white70),
                  onPressed: _checkBackendHealthy,
                  tooltip: 'Check Backend Health',
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_2,
                      size: 18, color: Colors.white70),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/child-qr'),
                  tooltip: 'Child QR Code',
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Top Status Bar: Streaming Indicator & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: _isStreaming
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isStreaming ? 'Live Monitoring' : 'Stream Offline',
                        style: TextStyle(
                          color: _isStreaming
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (_isDetecting)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blueAccent,
                            ),
                          ),
                        )
                    ],
                  ),
                  // Mode Indicator & Interval
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _aiMode == 'object'
                              ? 'YOLO (3s)'
                              : (_aiMode == 'scene_vit'
                                  ? 'ViT Scene (5s)'
                                  : (_aiMode == 'scene_blip'
                                      ? 'BLIP Scene (5s)'
                                      : 'Florence (5s)')),
                          style: const TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_aiMode == 'object')
                        Tooltip(
                          message:
                              'Debug Mode (Save annotated images on backend)',
                          child: FilterChip(
                            label: const Text('Debug',
                                style: TextStyle(fontSize: 11)),
                            selected: _debugMode,
                            selectedColor: Colors.blueAccent.withOpacity(0.3),
                            checkmarkColor: Colors.blueAccent,
                            onSelected: (val) =>
                                setState(() => _debugMode = val),
                            backgroundColor: Colors.white12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Stream preview card
              Expanded(
                flex: 5,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isStreaming
                          ? Colors.blueAccent.withOpacity(0.6)
                          : Colors.white12,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      if (_isStreaming) CameraStreamWidget(
 				 streamUrl: CameraService.streamUrl,
 				 isStreaming: _isStreaming,
						),
                      if (!_isStreaming)
                        const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam_off,
                                  color: Colors.white24, size: 72),
                              SizedBox(height: 12),
                              Text('Stream is Off',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 18)),
                              SizedBox(height: 6),
                              Text('Press ON to start real-time monitoring',
                                  style: TextStyle(
                                      color: Colors.white24, fontSize: 13)),
                            ],
                          ),
                        ),
                      if (_isLoading && _isStreaming)
                        Container(
                          color: Colors.black87,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                    color: Colors.blueAccent),
                                SizedBox(height: 14),
                                Text('Connecting to ESP32-CAM Stream...',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      if (_hasError && _isStreaming)
                        Container(
                          color: Colors.black87,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.redAccent, size: 56),
                                const SizedBox(height: 12),
                                const Text(
                                  'Cannot reach ESP32-CAM\nCheck WiFi connection',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.redAccent, fontSize: 15),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _startStream,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reconnect'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildModeButton(
                          title: 'Safety / أمان',
                          icon: Icons.shield_rounded,
                          modeKey: 'safety',
                          aiModeKey: 'object',
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(width: 8),
                        _buildModeButton(
                          title: 'Explore / استكشاف',
                          icon: Icons.search_rounded,
                          modeKey: 'explore',
                          aiModeKey: 'object',
                          color: Colors.blueAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildModeButton(
                          title: 'Brief Scene / مختصر',
                          icon: Icons.image_rounded,
                          modeKey: 'scene_brief',
                          aiModeKey: 'scene_blip',
                          color: Colors.orangeAccent,
                        ),
                        const SizedBox(width: 8),
                        _buildModeButton(
                          title: 'Detailed Scene / مفصل',
                          icon: Icons.auto_awesome_rounded,
                          modeKey: 'scene_detailed',
                          aiModeKey: 'scene_florence',
                          color: Colors.purpleAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // AI Results UI Card
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _aiMode == 'object'
                                    ? Icons.insights_rounded
                                    : Icons.auto_awesome_rounded,
                                color: Colors.blueAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _aiMode == 'object'
                                    ? 'YOLO Detections (${_latestDetections.length})'
                                    : (_aiMode == 'scene_vit'
                                        ? 'ViT Scene Summary'
                                        : (_aiMode == 'scene_blip'
                                            ? 'BLIP Scene Summary'
                                            : 'Florence Scene Summary')),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                            ],
                          ),
                          if (_lastDetectionTime.isNotEmpty)
                            Text(
                              'Updated: ${_formatTimestamp(_lastDetectionTime)} (${_lastProcessingTimeMs}ms)',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_detectionErrorMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.redAccent.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Colors.redAccent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _detectionErrorMessage,
                                  style: const TextStyle(
                                      color: Colors.redAccent, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Mode Specific Results
                      if (_runningMode == 'safety' || _runningMode == 'explore')
                        Expanded(
                          child: !_isStreaming
                              ? const Center(
                                  child: Text(
                                      'Start monitoring to see object detections',
                                      style: TextStyle(
                                          color: Colors.white38, fontSize: 14)),
                                )
                              : _latestDetections.isEmpty
                                  ? Center(
                                      child: Text(
                                          _isDetecting
                                              ? 'Analyzing frame...'
                                              : 'No objects detected in view',
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 14)),
                                    )
                                  : ListView.builder(
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: _latestDetections.length,
                                      itemBuilder: (context, index) {
                                        final item = _latestDetections[index];
                                        final isHighConf =
                                            item.confidence >= 0.70;
                                        return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.black26,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: isHighConf
                                                    ? Colors.greenAccent
                                                        .withOpacity(0.4)
                                                    : Colors.white12),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .center_focus_strong_rounded,
                                                    color: isHighConf
                                                        ? Colors.greenAccent
                                                        : Colors.blueAccent,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    item.label.toUpperCase(),
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  SizedBox(
                                                    width: 60,
                                                    child:
                                                        LinearProgressIndicator(
                                                      value: item.confidence,
                                                      backgroundColor:
                                                          Colors.white12,
                                                      color: isHighConf
                                                          ? Colors.greenAccent
                                                          : Colors.blueAccent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    '${(item.confidence * 100).toInt()}%',
                                                    style: TextStyle(
                                                        color: isHighConf
                                                            ? Colors.greenAccent
                                                            : Colors.white70,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13),
                                                  ),
                                                ],
                                              )
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                        ),

                      if (_runningMode.startsWith('scene'))
                        Expanded(
                          child: !_isStreaming
                              ? const Center(
                                  child: Text(
                                      'Start monitoring to see scene summary',
                                      style: TextStyle(
                                          color: Colors.white38, fontSize: 14)),
                                )
                              : _latestSceneSummary.isEmpty
                                  ? Center(
                                      child: Text(
                                          _isDetecting
                                              ? 'Generating scene summary...'
                                              : 'No summary generated yet',
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 14)),
                                    )
                                  : Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.blueAccent.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color: Colors.blueAccent
                                                .withOpacity(0.4),
                                            width: 1.5),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.auto_awesome_rounded,
                                              color: Colors.blueAccent,
                                              size: 36),
                                          const SizedBox(height: 16),
                                          Text(
                                            _latestSceneSummary,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                height: 1.4),
                                          ),
                                        ],
                                      ),
                                    ),
                        ),
                    ],
                  ),
                ),
              ),

              if (_lastSpeech != null && _lastSpeech!.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                  ),
                  child: Text(
                    '🗣️ $_lastSpeech',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),

              const SizedBox(height: 16),

              Text(
                'Stream: ${CameraService.streamUrl} | AI Lab: ${AppConfig.aiLabBaseUrl}',
                style: const TextStyle(color: Colors.white24, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildModeButton({
    required String title,
    required IconData icon,
    required String modeKey,
    required String aiModeKey,
    required Color color,
  }) {
    final isActive = _runningMode == modeKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_runningMode == modeKey) return;
          setState(() {
            _runningMode = modeKey;
            _lastSpeech = null;
          });
          _applyInitialMode(modeKey);
          _setAiMode(aiModeKey);
          
          final isAr = _language == 'ar' || L10n.isArabic;
          String arMsg = '';
          String enMsg = '';
          if (modeKey == 'safety') {
            arMsg = 'حسنا، العودة لوضع الأمان.';
            enMsg = 'Okay, returning to safety mode.';
          } else if (modeKey == 'explore') {
            arMsg = 'حسنا، الآن وضع الاستكشاف.';
            enMsg = 'Okay, now in exploration mode.';
          } else if (modeKey == 'scene_brief') {
            arMsg = 'حسنا، الآن أخذ لقطة سريعة.';
            enMsg = 'Okay, now taking a brief look.';
          } else if (modeKey == 'scene_detailed') {
            arMsg = 'حسنا، أنت الآن في وضع الوصف المفصل.';
            enMsg = 'Okay, now giving a detailed description.';
          }
          if (arMsg.isNotEmpty) {
            VoiceService.instance.interruptAndSpeak(isAr ? arMsg : enMsg);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? color : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: isActive ? color : Colors.white70),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isActive ? color : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _revertToSafetyIfNeeded() {
    if (_runningMode != 'safety' && mounted) {
      setState(() {
        _runningMode = 'safety';
      });
      _applyInitialMode('safety');
      _setAiMode('object');
    }
  }
}

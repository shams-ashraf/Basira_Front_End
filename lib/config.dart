import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static String serverIp = "192.168.100.58:5000";
  static String aiLabServerIp = "172.20.10.3:8000";
  static String esp32Ip = "10.168.48.140";
  static int captureIntervalSeconds = 3;
  static int captureMaxWidth = 1280;
  static int serverTimeoutSeconds = 8;
  static String generationMode = 'greedy';

  static String get baseUrl {
    final trimmed = serverIp.trim();
    if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
      return trimmed;
    }
    return "http://$trimmed";
  }

  static String get aiLabBaseUrl {
    final trimmed = aiLabServerIp.trim();
    if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
      return trimmed;
    }
    return "http://$trimmed";
  }

  static String get cameraUrl => "http://$esp32Ip:81/stream";

  static String normalizeHost(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.tryParse(trimmed.contains('://') ? trimmed : 'http://$trimmed');
    if (uri != null && uri.host.isNotEmpty) {
      return uri.host;
    }
    return trimmed.split(':').first.trim();
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    serverIp = (prefs.getString('server_ip') ?? "172.20.10.3:5000").trim();
    
    String defaultAi = "172.20.10.3:8000";
    if (prefs.getString('server_ip') != null) {
      final rawServer = prefs.getString('server_ip')!;
      final hostOnly = normalizeHost(rawServer);
      defaultAi = "$hostOnly:8000";
    }
    
    aiLabServerIp = (prefs.getString('ai_lab_server_ip') ?? defaultAi).trim();
    esp32Ip = normalizeHost(prefs.getString('esp32_ip') ?? "192.168.1.100");
    captureIntervalSeconds = prefs.getInt('esp32_capture_interval') ?? 3;
    captureMaxWidth = prefs.getInt('esp32_capture_max_width') ?? 1280;
    serverTimeoutSeconds = prefs.getInt('server_timeout_seconds') ?? 2;
    generationMode = prefs.getString('ai_generation_mode') ?? 'greedy';
  }

  static Future<void> saveSettings({
    required String server,
    required String esp,
    String? aiServer,
    int? interval,
    int? maxWidth,
    int? timeout,
    int? obstacleThresholdCm,
    double? faceRecognitionThreshold,
    double? yoloConfidenceThreshold,
    String? generationMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmedServer = server.trim();
    final normalizedEsp = normalizeHost(esp);
    await prefs.setString('server_ip', trimmedServer);
    await prefs.setString('esp32_ip', normalizedEsp);
    serverIp = trimmedServer;
    esp32Ip = normalizedEsp;

    if (aiServer != null) {
      final trimmedAi = aiServer.trim();
      await prefs.setString('ai_lab_server_ip', trimmedAi);
      aiLabServerIp = trimmedAi;
    }
    if (interval != null) {
      await prefs.setInt('esp32_capture_interval', interval);
      captureIntervalSeconds = interval;
    }
    if (maxWidth != null) {
      await prefs.setInt('esp32_capture_max_width', maxWidth);
      captureMaxWidth = maxWidth;
    }
    if (timeout != null) {
      await prefs.setInt('server_timeout_seconds', timeout);
      serverTimeoutSeconds = timeout;
    }
    if (obstacleThresholdCm != null) {
      await prefs.setInt('esp32_obstacle_threshold_cm', obstacleThresholdCm);
    }
    if (faceRecognitionThreshold != null) {
      await prefs.setDouble('face_recognition_threshold', faceRecognitionThreshold);
    }
    if (yoloConfidenceThreshold != null) {
      await prefs.setDouble('yolo_confidence_threshold', yoloConfidenceThreshold);
    }
    if (generationMode != null) {
      await prefs.setString('ai_generation_mode', generationMode);
      AppConfig.generationMode = generationMode;
    }
  }
}

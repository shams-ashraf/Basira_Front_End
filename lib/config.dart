import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static String serverIp = "192.168.100.58";
  static String aiLabServerIp = "192.168.100.58";
  static String esp32Ip = "192.168.1.100";

  static String get baseUrl => "http://$serverIp:5000";
  static String get aiLabBaseUrl => "http://$aiLabServerIp:6000";
  static String get websocketUrl => "ws://$serverIp:5000/voice/stream";
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
    serverIp = normalizeHost(prefs.getString('server_ip') ?? "192.168.100.58");
    aiLabServerIp = normalizeHost(prefs.getString('ai_lab_server_ip') ?? serverIp);
    esp32Ip = normalizeHost(prefs.getString('esp32_ip') ?? "192.168.1.100");
  }

  static Future<void> saveSettings({required String server, required String esp}) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedServer = normalizeHost(server);
    final normalizedEsp = normalizeHost(esp);
    await prefs.setString('server_ip', normalizedServer);
    await prefs.setString('esp32_ip', normalizedEsp);
    serverIp = normalizedServer;
    esp32Ip = normalizedEsp;
  }
}

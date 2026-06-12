import '../config.dart';

class CameraService {
  static String get espIp => AppConfig.esp32Ip;
  static String get streamUrl => AppConfig.cameraUrl;
  static String get snapshotUrl => 'http://$espIp/capture';
  static String get backendUrl => AppConfig.baseUrl;

  static Future<void> loadIp() async {
    await AppConfig.load();
  }

  static Future<void> saveIp(String ip) async {
    await AppConfig.saveSettings(server: AppConfig.serverIp, esp: ip);
  }
}

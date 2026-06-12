import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../config.dart';

class SceneService {
  SceneService._();
  static final SceneService instance = SceneService._();

  // For Android Emulator, 10.0.2.2 points to the host machine (your PC)
  // For physical devices, you must use your PC's local IP address (e.g. 192.168.1.5)
  static String get _baseUrl => AppConfig.baseUrl;
  Future<String> getSceneDescription(File imageFile) async {
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$_baseUrl/vision/caption'));
      request.files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['caption'] ?? "I couldn't describe the scene.";
      } else {
        final body = response.body.trim();
        return body.isNotEmpty
            ? "Server error: ${response.statusCode} - $body"
            : "Server error: ${response.statusCode}";
      }
    } catch (e) {
      debugPrint("SceneService Error: $e");
      return "Could not connect to the local inference server. Make sure it is running on your PC.";
    }
  }

  /// Helper to process a CameraImage, save to temp file, and get caption
  Future<String> getSceneFromImage(img.Image image) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/scene_${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Save as JPEG for the server
      await tempFile.writeAsBytes(img.encodeJpg(image, quality: 85));

      final result = await getSceneDescription(tempFile);

      // Clean up
      await tempFile.delete();

      return result;
    } catch (e) {
      return "Error processing image: $e";
    }
  }
}

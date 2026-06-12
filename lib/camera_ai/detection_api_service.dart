import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'detection_result.dart';
import 'camera_service.dart';

class DetectionApiService {
  // Check backend health
  static Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('${CameraService.backendUrl}/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'ok';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Fetch single snapshot frame from ESP32-CAM
  static Future<Uint8List?> captureFrame() async {
    try {
      final uri = Uri.parse(CameraService.snapshotUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Resize image to max width 640px to optimize transmission and processing latency
  static Uint8List resizeImageIfNeeded(Uint8List imageBytes, {int maxWidth = 640}) {
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded != null && decoded.width > maxWidth) {
        final resized = img.copyResize(decoded, width: maxWidth);
        return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
      }
    } catch (_) {
      // Return original bytes on error
    }
    return imageBytes;
  }

  // Send image frame to FastAPI YOLOv8 backend
  static Future<DetectionResponse> detectObject(Uint8List rawBytes, {bool debug = false}) async {
    try {
      final imageBytes = resizeImageIfNeeded(rawBytes);
      final uri = Uri.parse('${CameraService.backendUrl}/vision/detect');
      final request = http.MultipartRequest('POST', uri);
      
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'frame.jpg',
      ));
      
      request.fields['debug'] = debug ? 'true' : 'false';

      // Scene models lazy-load on first call (30-60s). Use 120s timeout.
      final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return DetectionResponse.fromJson(json);
      } else {
        return DetectionResponse(
          success: false,
          detections: [],
          timestamp: DateTime.now().toIso8601String(),
          processingTimeMs: 0.0,
          error: 'Server returned status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return DetectionResponse(
        success: false,
        detections: [],
        timestamp: DateTime.now().toIso8601String(),
        processingTimeMs: 0.0,
        error: 'Connection error: $e',
      );
    }
  }

  // Send image frame to FastAPI backend for scene summary
  static Future<SceneSummaryResponse> generateSceneSummary(Uint8List rawBytes, {String modelType = 'vit'}) async {
    try {
      final imageBytes = resizeImageIfNeeded(rawBytes);
      final uri = Uri.parse('${CameraService.backendUrl}/vision/caption');
      final request = http.MultipartRequest('POST', uri);
      
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'scene.jpg',
      ));
      
      request.fields['model_type'] = modelType;

      // Scene models lazy-load on first call (30-60s). Use generous timeout.
      final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return SceneSummaryResponse.fromJson(json);
      } else {
        return SceneSummaryResponse(
          success: false,
          summary: '',
          timestamp: DateTime.now().toIso8601String(),
          processingTimeMs: 0.0,
          error: 'Server returned status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return SceneSummaryResponse(
        success: false,
        summary: '',
        timestamp: DateTime.now().toIso8601String(),
        processingTimeMs: 0.0,
        error: 'Connection error: $e',
      );
    }
  }
}

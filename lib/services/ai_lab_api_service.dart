import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class AILabApiService {
  AILabApiService._();

  static final AILabApiService instance = AILabApiService._();

  Future<String> _childId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('linked_child_id') ??
        prefs.getString('child_id') ??
        prefs.getString('auth_id') ??
        'unknown';
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> runObjectDetection(String imagePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.aiLabBaseUrl}/object-detection/run'),
    );
    request.headers.addAll(await _headers());
    request.fields['child_id'] = await _childId();

       final prefs = await SharedPreferences.getInstance();
       request.fields['language'] =
   	 prefs.getString('language') ??
    	(prefs.getString('voice_language')?.startsWith('ar') == true
        	? 'ar'
        	: 'en');

      final obstacleThreshold = prefs.getInt('esp32_obstacle_threshold_cm') ?? 100;
      final faceThreshold = prefs.getDouble('face_recognition_threshold') ?? 0.5;
      final yoloThreshold = prefs.getDouble('yolo_confidence_threshold') ?? 0.3;

      request.fields['obstacle_threshold_cm'] = obstacleThreshold.toString();
      request.fields['face_recognition_threshold'] = faceThreshold.toString();
      request.fields['yolo_confidence_threshold'] = yoloThreshold.toString();
  
      request.files.add(
     await http.MultipartFile.fromPath('file', imagePath));
     final response = await request.send();
     final body = await response.stream.bytesToString();
     return jsonDecode(body) as Map<String, dynamic>;
   }

  Future<Map<String, dynamic>> runSceneSummary(String imagePath) async {
    final childId = await _childId();
    final headers = await _headers();

    Future<Map<String, dynamic>> post(String path) async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.aiLabBaseUrl}$path'),
      );
      request.headers.addAll(headers);
      request.fields['child_id'] = childId;
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));
      final response = await request.send();
      final body = await response.stream.bytesToString();
      return jsonDecode(body) as Map<String, dynamic>;
    }

    final blip = await post('/scene-summary/blip/run');
    final vit = await post('/scene-summary/vit/run');
    final florence = await post('/scene-summary/florence/run');
    return {
      'blip_caption': blip['blip_caption'],
      'blip_time': blip['blip_time'],
      'vit_caption': vit['vit_caption'],
      'vit_time': vit['vit_time'],
      'florence_caption': florence['florence_caption'],
      'florence_time': florence['florence_time'],
    };
  }

  Future<Map<String, dynamic>> runSceneSummaryModel(
    String imagePath,
    String modelType,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.aiLabBaseUrl}/scene-summary/run'),
    );
    request.headers.addAll(await _headers());
    request.fields['child_id'] = await _childId();
    request.fields['model_type'] = modelType;
    request.fields['generation_mode'] = AppConfig.generationMode;
    // Force English from server so we can translate locally on the mobile device
    request.fields['language'] = 'en'; 
    request.files.add(await http.MultipartFile.fromPath('file', imagePath));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<void> unloadModels() async {
    try {
      await http.post(
        Uri.parse('${AppConfig.aiLabBaseUrl}/scene-summary/unload'),
        headers: await _headers(),
      );
    } catch (_) {}
  }

  Future<bool> ping() async {
    try {
      final response =
          await http.get(Uri.parse('${AppConfig.aiLabBaseUrl}/health'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

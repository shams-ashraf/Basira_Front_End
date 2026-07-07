import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config.dart';
import 'ai_lab_storage_service.dart';
import 'face_recognition_service.dart';

class BackendService {
  BackendService._();
  static final BackendService instance = BackendService._();

  WebSocketChannel? _channel;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Exception _handleHttpError(dynamic e) {
    if (e is SocketException) {
      return Exception(
          "Backend server is not running. Cannot connect to FastAPI server.");
    } else if (e is TimeoutException) {
      return Exception(
          "Server timeout. Please start the backend and try again.");
    }
    return Exception("Network or Server Error: $e");
  }

  Exception _handleServerResponse(int statusCode, [String? body]) {
    final detail = body?.trim();
    if (detail != null && detail.isNotEmpty) {
      return Exception("Server error: $statusCode - $detail");
    }
    return Exception("Server error: $statusCode");
  }

  Future<void> initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  Future<void> _addAuthHeader(http.MultipartRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      request.headers["Authorization"] = "Bearer $token";
    }
  }

  Future<bool> _refreshAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null) return false;
      final uri = Uri.parse("${AppConfig.baseUrl}/auth/refresh");
      final response = await http.post(uri, body: {"refresh_token": refreshToken}).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newAccess = data['access_token'];
        if (newAccess != null) {
          await prefs.setString('access_token', newAccess);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> connectWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final wsValue = prefs.getString('websocket_url');
    final wsUrl = Uri.parse(wsValue ?? AppConfig.baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://'));
    _channel = WebSocketChannel.connect(wsUrl);

    _channel!.stream.listen((message) async {
      try {
        final data = jsonDecode(message);
        if (data['type'] == 'unknown') {
          final childId = (data['child_id'] ?? data['childId'] ?? '0').toString();
          final imageName = (data['image'] ?? data['filename'] ?? '').toString();
          final imageUrl = imageName.contains('/')
              ? '${AppConfig.baseUrl}/$imageName'
              : '${AppConfig.baseUrl}/unknown_image/$childId/$imageName';
          final timestamp = data['timestamp'];

          await FaceRecognitionService.instance.addUnknownPerson(
            imageName,
            imageUrl,
            timestamp,
          );

          const AndroidNotificationDetails androidPlatformChannelSpecifics =
              AndroidNotificationDetails(
            'unknown_channel',
            'Unknown Persons',
            channelDescription: 'Alerts for unknown persons detected',
            importance: Importance.max,
            priority: Priority.high,
          );
          const NotificationDetails platformChannelSpecifics =
              NotificationDetails(android: androidPlatformChannelSpecifics);
          await flutterLocalNotificationsPlugin.show(
            0,
            'Unknown Person Detected!',
            'An unknown person was seen by the camera.',
            platformChannelSpecifics,
          );
        }
      } catch (e) {
        debugPrint("WS Error: $e");
      }
    }, onError: (e) {
      debugPrint("WS Error: $e");
      Future.delayed(const Duration(seconds: 3), connectWebSocket);
    }, onDone: () {
      debugPrint("WS Done. Reconnecting...");
      Future.delayed(const Duration(seconds: 3), connectWebSocket);
    });
  }

  // Voice WebSocket
  Future<Map<String, dynamic>> detectObjects(String imagePath) async {
    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse("${AppConfig.baseUrl}/vision/detect"));
      await _addAuthHeader(request);
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));
      final response =
          await request.send().timeout(const Duration(seconds: 15));
      final resBody = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        throw _handleServerResponse(response.statusCode, resBody);
      }
      return jsonDecode(resBody);
    } catch (e) {
      throw _handleHttpError(e);
    }
  }

  Future<bool> validateFace(String imagePath) async {
    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse("${AppConfig.baseUrl}/validate_face"));
      await _addAuthHeader(request);
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));
      final response =
          await request.send().timeout(const Duration(seconds: 15));
      final resBody = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        throw _handleServerResponse(response.statusCode, resBody);
      }
      final data = jsonDecode(resBody);
      return data['valid'] == true;
    } catch (e) {
      debugPrint("Validate face error: $e");
      throw _handleHttpError(e);
    }
  }

  Future<String> generateCaption(String imagePath) async {
    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse("${AppConfig.baseUrl}/vision/caption"));
      await _addAuthHeader(request);
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));
      final response =
          await request.send().timeout(const Duration(seconds: 15));
      final resBody = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        throw _handleServerResponse(response.statusCode, resBody);
      }
      return jsonDecode(resBody)['caption'];
    } catch (e) {
      throw _handleHttpError(e);
    }
  }

  Future<Map<String, dynamic>> registerPerson(
      String name, List<String> imagePaths) async {
    final uri = Uri.parse("${AppConfig.baseUrl}/register");
    final request = http.MultipartRequest('POST', uri);
    await _addAuthHeader(request);

    request.fields['name'] = name;
    final prefs = await SharedPreferences.getInstance();
    final childId = prefs.getString('linked_child_id') ??
        prefs.getString('child_id') ??
        '0';
    request.fields['child_id'] = childId;

    for (String path in imagePaths) {
      request.files.add(await http.MultipartFile.fromPath('files', path));
    }

    try {
      final response =
          await request.send().timeout(const Duration(seconds: 15));
      final resBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        final detail = _extractServerMessage(resBody) ??
            "Registration failed with status ${response.statusCode}.";
        throw Exception(detail);
      }

      return jsonDecode(resBody);
    } catch (e) {
      throw _handleHttpError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getAllPersons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final childId = prefs.getString('linked_child_id') ??
          prefs.getString('child_id');
      final uri = Uri.parse(childId == null || childId.isEmpty
          ? "${AppConfig.baseUrl}/persons"
          : "${AppConfig.baseUrl}/persons?child_id=$childId");
      final headers = await _getHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      throw _handleServerResponse(response.statusCode, response.body);
    } catch (e) {
      throw _handleHttpError(e);
    }
  }

  Future<List<String>> getPersonImages(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final childId = prefs.getString('linked_child_id') ??
          prefs.getString('child_id');
      final uri = Uri.parse(childId == null || childId.isEmpty
          ? "${AppConfig.baseUrl}/person_images?name=$name"
          : "${AppConfig.baseUrl}/person_images?name=$name&child_id=$childId");
      final headers = await _getHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return List<String>.from(jsonDecode(response.body));
      }
      throw _handleServerResponse(response.statusCode, response.body);
    } catch (e) {
      throw _handleHttpError(e);
    }
  }

  Future<void> deletePerson(int id) async {
    try {
      final uri = Uri.parse("${AppConfig.baseUrl}/person/$id");
      final headers = await _getHeaders();
      final response = await http
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw _handleServerResponse(response.statusCode, response.body);
      }
    } catch (e) {
      throw _handleHttpError(e);
    }
  }

  Future<void> uploadUnknownFace(String localImagePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final childId = prefs.getString('linked_child_id') ??
          prefs.getString('child_id') ??
          prefs.getString('auth_id') ??
          '0';

      final uri = Uri.parse("${AppConfig.baseUrl}/upload_unknown");
      final request = http.MultipartRequest('POST', uri);
      await _addAuthHeader(request);
      request.fields['child_id'] = childId;
      request.files
          .add(await http.MultipartFile.fromPath('file', localImagePath));

      final response =
          await request.send().timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        debugPrint("✅ Unknown face uploaded to backend");
      } else {
        debugPrint("⚠️ Upload unknown failed: ${response.statusCode}");
        throw Exception("Upload failed with status ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("uploadUnknownFace Error: $e. Saving pending upload.");
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_unknowns') ?? [];
      if (!pending.contains(localImagePath)) {
        pending.add(localImagePath);
        await prefs.setStringList('pending_unknowns', pending);
      }
      throw _handleHttpError(e);
    }
  }

  Future<void> recordCapturedPhotoAsUnknown(String localImagePath) async {
    final timestamp = DateTime.now().toIso8601String();

    try {
      await FaceRecognitionService.instance.init();
    } catch (e) {
      debugPrint("FaceRecognition init failed before saving unknown: $e");
    }

    await FaceRecognitionService.instance.addUnknownPerson(
      localImagePath,
      localImagePath,
      timestamp,
    );

    try {
      await AILabStorageService.instance.copyCapturedImage(localImagePath);
    } catch (e) {
      debugPrint("AI Lab copy skipped: $e");
    }

    try {
      await uploadUnknownFace(localImagePath);
    } catch (e) {
      debugPrint("recordCapturedPhotoAsUnknown upload deferred: $e");
    }
  }

  Future<void> retryPendingUploads() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList('pending_unknowns') ?? [];
    if (pending.isEmpty) return;

    final remaining = <String>[];
    for (var path in pending) {
      try {
        if (!File(path).existsSync()) continue;
        final childId = prefs.getString('linked_child_id') ??
            prefs.getString('child_id') ??
            prefs.getString('auth_id') ??
            '0';
        final uri = Uri.parse("${AppConfig.baseUrl}/upload_unknown");
        final request = http.MultipartRequest('POST', uri);
        await _addAuthHeader(request);
        request.fields['child_id'] = childId;
        request.files.add(await http.MultipartFile.fromPath('file', path));

        final response =
            await request.send().timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          debugPrint("✅ Recovered upload for $path");
        } else {
          remaining.add(path);
        }
      } catch (e) {
        remaining.add(path);
      }
    }
    await prefs.setStringList('pending_unknowns', remaining);
  }

  Future<List<Map<String, dynamic>>> getUnknown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final childId = prefs.getString('linked_child_id') ??
          prefs.getString('child_id');
      final uri = Uri.parse(childId == null || childId.isEmpty
          ? "${AppConfig.baseUrl}/unknown"
          : "${AppConfig.baseUrl}/unknown?child_id=$childId");
      final headers = await _getHeaders();
      var response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      // If unauthorized, try refreshing token once
      if (response.statusCode == 401) {
        bool refreshed = await _refreshAccessToken();
        if (refreshed) {
          final newHeaders = await _getHeaders();
          response = await http.get(uri, headers: newHeaders).timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            return List<Map<String, dynamic>>.from(jsonDecode(response.body));
          }
        }
      }
      return [];
    } catch (e) {
      throw _handleHttpError(e);
    }
  }

  Future<bool> convertUnknown(
      {required String name, required String unknownId}) async {
    try {
      final uri = Uri.parse("${AppConfig.baseUrl}/unknown_to_person");
      final headers = await _getHeaders();
      final prefs = await SharedPreferences.getInstance();
      final childId = prefs.getString('linked_child_id') ??
          prefs.getString('child_id') ??
          '0';
      var response = await http.post(uri, headers: headers, body: {
        "name": name,
        "unknown_id": unknownId,
        "child_id": childId,
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return true;
      // If unauthorized, try token refresh
      if (response.statusCode == 401) {
        bool refreshed = await _refreshAccessToken();
        if (refreshed) {
          final newHeaders = await _getHeaders();
          response = await http.post(uri, headers: newHeaders, body: {
            "name": name,
            "unknown_id": unknownId,
            "child_id": childId,
          }).timeout(const Duration(seconds: 15));
          return response.statusCode == 200;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getSettings() async {
    try {
      final uri = Uri.parse("${AppConfig.baseUrl}/settings");
      final headers = await _getHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return {};
  }

  Future<bool> updateSettings(Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse("${AppConfig.baseUrl}/settings");
      final headers = await _getHeaders();
      final response = await http
          .post(
            uri,
            headers: headers,
            body: body.map((key, value) => MapEntry(key, value.toString())),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  String? _extractServerMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return (decoded['detail'] ?? decoded['message'] ?? decoded['error'])
            ?.toString();
      }
    } catch (_) {}
    return body.trim().isEmpty ? null : body.trim();
  }

  Future<List<Map<String, dynamic>>> getSystemLogs({int limit = 100}) async {
    try {
      final uri = Uri.parse("${AppConfig.baseUrl}/system_logs?limit=$limit");
      final headers = await _getHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      throw _handleHttpError(e);
    }
  }

  Future<bool> linkChild(String childId, String childName) async {
    try {
      final uri = Uri.parse("${AppConfig.baseUrl}/parent/link_child");
      final headers = await _getHeaders();
      var response = await http.post(uri, headers: headers, body: {
        "child_id": childId,
        "child_name": childName,
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return true;
      if (response.statusCode == 401) {
        bool refreshed = await _refreshAccessToken();
        if (refreshed) {
          final newHeaders = await _getHeaders();
          response = await http.post(uri, headers: newHeaders, body: {
            "child_id": childId,
            "child_name": childName,
          }).timeout(const Duration(seconds: 15));
          return response.statusCode == 200;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendChildAlert({
    required String childId,
    required String message,
    String type = "SOS",
  }) async {
    try {
      final uri = Uri.parse("${AppConfig.baseUrl}/alerts");
      final headers = await _getHeaders();
      final response = await http.post(
        uri,
        headers: headers,
        body: {
          "type": type,
          "message": message,
          "child_id": childId,
        },
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAlerts({String? childId}) async {
    try {
      final uri = Uri.parse(
        childId == null || childId.isEmpty
            ? "${AppConfig.baseUrl}/alerts"
            : "${AppConfig.baseUrl}/alerts?child_id=$childId",
      );
      final headers = await _getHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (_) {}
    return [];
  }

  void disconnect() {
  _channel?.sink.close();
   }
}

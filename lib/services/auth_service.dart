import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class AuthResult {
  AuthResult({
    required this.success,
    this.message,
    this.statusCode,
  });

  final bool success;
  final String? message;
  final int? statusCode;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Future<void> init() async {
    await AppConfig.load();
  }
  Future<void> linkChild(String childId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('linked_child_id', childId);
      await prefs.setString('child_id', childId);
      await prefs.setString('linked_child_name', 'Child');
    } catch (e) {
      throw Exception('Failed to link child: $e');
    }
  }

  Future<AuthResult> login(String email, String password) async {
    try {
      await AppConfig.load();
      final response = await http.post(
        Uri.parse("${AppConfig.baseUrl}/auth/login"),
        body: {
          "email": email,
          "password": password,
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        await prefs.setString('refresh_token', data['refresh_token']);
        await prefs.setString('role', data['role']);
        await prefs.setString('auth_id', data['user_id'].toString());
        await prefs.setString('email', data['email']);
        await AppConfig.load();
        return AuthResult(success: true, message: "Login successful");
      }
      return AuthResult(
        success: false,
        statusCode: response.statusCode,
        message: _extractErrorMessage(response.body) ?? "Incorrect email or password.",
      );
    } catch (e) {
      return AuthResult(success: false, message: "Cannot reach the server: $e");
    }
  }

  Future<AuthResult> signup(String email, String password, String role) async {
    try {
      final response = await http.post(
        Uri.parse("${AppConfig.baseUrl}/auth/signup"),
        body: {
          "email": email,
          "password": password,
          "role": role,
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return AuthResult(success: true, message: "Account created successfully.");
      }
      return AuthResult(
        success: false,
        statusCode: response.statusCode,
        message: _extractErrorMessage(response.body) ??
            "Signup failed. Please verify the email, password, and selected role.",
      );
    } catch (e) {
      return AuthResult(success: false, message: "Cannot reach the server: $e");
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('role');
    await prefs.remove('auth_id');
    await prefs.remove('email');
    await prefs.remove('linked_child_id');
    await prefs.remove('child_id');
    await prefs.remove('linked_child_name');
  }

  Future<Map<String, String>?> getAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    final id = prefs.getString('auth_id');
    final token = prefs.getString('access_token');
    if (role != null && id != null && token != null) {
      return {'role': role, 'auth_id': id, 'access_token': token};
    }
    return null;
  }

  Future<bool> validateToken() async {
    final auth = await getAuth();
    if (auth == null) return false;
    try {
      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}/auth/me"),
        headers: {
          "Authorization": "Bearer ${auth['access_token']}"
        },
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  String? _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return (decoded['detail'] ?? decoded['message'] ?? decoded['error'])?.toString();
      }
    } catch (_) {}
    return body.trim().isEmpty ? null : body.trim();
  }
}

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'backend_service.dart';
import '../config.dart';

class ApiService {
  static Future<List> getPersons() async {
    return await BackendService.instance.getAllPersons();
  }

  static Future<void> addPerson({
    required String name,
    required List<String> paths,
  }) async {
    await BackendService.instance.registerPerson(name, paths);
  }

  static Future<void> deletePerson(int id) async {
    await BackendService.instance.deletePerson(id);
  }

  static Future<void> editPerson(int id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final url = Uri.parse("${AppConfig.baseUrl}/person/$id");
    await http.put(
      url,
      headers: {
        if (token != null) "Authorization": "Bearer $token",
      },
      body: {"name": name},
    );
  }

  static Future<List> getPersonImages(String name) async {
    return await BackendService.instance.getPersonImages(name);
  }

  static Future<List> getUnknown() async {
    return await BackendService.instance.getUnknown();
  }

  static Future<void> convertUnknown({
    required String name,
    required String fileId,
  }) async {
    await BackendService.instance.convertUnknown(name: name, unknownId: fileId);
  }
}

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AILabStorageService {
  AILabStorageService._();

  static final AILabStorageService instance = AILabStorageService._();

  Future<Directory> _baseDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'ai_lab_storage'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> childDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final childId = prefs.getString('linked_child_id') ??
        prefs.getString('child_id') ??
        prefs.getString('auth_id') ??
        'unknown';
    final base = await _baseDirectory();
    final dir = Directory(p.join(base.path, 'child_$childId'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> copyCapturedImage(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('Source image does not exist: $sourcePath');
    }

    final targetDir = await childDirectory();
    final fileName = 'ai_${DateTime.now().millisecondsSinceEpoch}${p.extension(sourcePath)}';
    return sourceFile.copy(p.join(targetDir.path, fileName));
  }

  Future<List<FileSystemEntity>> listChildImages() async {
    final dir = await childDirectory();
    if (!await dir.exists()) {
      return [];
    }

    final files = await dir
        .list()
        .where((entity) =>
            entity is File &&
            (entity.path.endsWith('.jpg') ||
                entity.path.endsWith('.jpeg') ||
                entity.path.endsWith('.png')))
        .toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }
}

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceRecognitionService {
  FaceRecognitionService._();
  static final FaceRecognitionService instance = FaceRecognitionService._();

  static const String _modelPath = 'assets/models/mobilefacenet.tflite';
  Interpreter? _interpreter;
  late FaceDetector _faceDetector;
  Database? _db;
  bool _isInitialized = false;
  List<Map<String, dynamic>> _cachedPersons = [];

  Future<void> init() async {
    if (_isInitialized) return;

    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'faces.db'),
      onCreate: (db, version) async {
        await db.execute(
            'CREATE TABLE persons(id INTEGER PRIMARY KEY, child_id INTEGER, name TEXT, embedding TEXT, images TEXT)');
        await db.execute(
            'CREATE TABLE unknown_persons(id INTEGER PRIMARY KEY, child_id INTEGER, image_path TEXT, embedding TEXT, timestamp TEXT)');
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 5) {
          await db.execute(
              'CREATE TABLE IF NOT EXISTS persons(id INTEGER PRIMARY KEY, child_id INTEGER, name TEXT, embedding TEXT, images TEXT)');
          await db.execute(
              'CREATE TABLE IF NOT EXISTS unknown_persons(id INTEGER PRIMARY KEY, child_id INTEGER, image_path TEXT, embedding TEXT, timestamp TEXT)');
        }
        if (oldV < 6) {
          try {
            await db.execute('ALTER TABLE persons ADD COLUMN child_id INTEGER');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE unknown_persons ADD COLUMN child_id INTEGER');
          } catch (_) {}
        }
      },
      version: 6,
    );

    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(_modelPath, options: options);
      _interpreter!.allocateTensors();
    } catch (e) {
      debugPrint('FaceNet model error: $e');
    }

    // High performance detector
    _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast, // Faster for mobile devices
      enableLandmarks: false, // Not needed for registration
      enableClassification: false, // Not needed
    ));
    _isInitialized = true;
    await reloadCache();
  }

  Future<void> reloadCache() async {
    _cachedPersons = await getAllPersons();
  }

  Future<int> _currentChildId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('linked_child_id') ??
        prefs.getString('child_id') ??
        prefs.getString('auth_id') ??
        '0';
    return int.tryParse(raw) ?? 0;
  }

  // --- RECOGNITION ---

  Future<String?> recognize(Float32List embedding) async {
    double bestSimilarity = 0.0;
    String? name;

    for (var p in _cachedPersons) {
      final String? embField = p['embedding'] as String?;
      if (embField == null) continue;
      final List<String> embStrings = embField.split('|');
      for (var embStr in embStrings) {
        if (embStr.isEmpty) continue;
        try {
          final List<double> savedEmb =
              embStr.split(',').map((e) => double.parse(e)).toList();
          if (savedEmb.length != embedding.length) {
            debugPrint(
                "Skipping embedding for person ${p['name']} with length ${savedEmb.length} != ${embedding.length}");
            continue;
          }
          final dist =
              _cosineDistance(embedding, Float32List.fromList(savedEmb));
          final similarity = 1.0 - dist;
          if (similarity >= 0.5 && similarity > bestSimilarity) {
            bestSimilarity = similarity;
            name = p['name'] as String;
          }
        } catch (e) {
          debugPrint("Failed to parse embedding for person ${p['name']}: $e");
        }
      }
    }
    return name;
  }

  // --- CRUD METHODS ---
  Future<Database> _databaseOrThrow() async {
    final db = _db;
    if (db == null) {
      throw StateError(
          'Face recognition database is not initialized yet. Call FaceRecognitionService.instance.init() first.');
    }
    return db;
  }

  Future<List<Map<String, dynamic>>> getAllPersons() async {
    final db = await _databaseOrThrow();
    return db.query('persons');
  }

  Future<void> savePerson(
      String name, List<Map<String, dynamic>> faceData) async {
    final db = await _databaseOrThrow();
    final childId = await _currentChildId();
    final embeddingStr = faceData.map((e) {
      final emb = e['embedding'];
      if (emb == null) return '';
      if (emb is Float32List) {
        return emb.join(',');
      }
      if (emb is List) {
        return emb.join(',');
      }
      return emb.toString();
    }).join('|');
    final imagesStr = faceData.map((e) => e['image_path'] ?? '').join('|');
    await db.insert('persons',
        {'child_id': childId, 'name': name, 'embedding': embeddingStr, 'images': imagesStr});
    await reloadCache();
  }

  Future<void> updatePerson(int id, String newName) async {
    final db = await _databaseOrThrow();
    await db.update('persons', {'name': newName},
        where: 'id = ?', whereArgs: [id]);
    await reloadCache();
  }

  Future<void> deletePerson(dynamic id) async {
    final db = await _databaseOrThrow();
    await db.delete('persons', where: 'id = ?', whereArgs: [id]);
    await reloadCache();
  }

  Future<List<Map<String, dynamic>>> getPersonImages(dynamic id) async {
    final db = await _databaseOrThrow();
    final res = await db.query('persons', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return [];
    final imagesStr = res.first['images'] as String;
    if (imagesStr.isEmpty) return [];
    final paths = imagesStr.split('|');
    return List.generate(
        paths.length, (i) => {'id': i, 'image_path': paths[i]});
  }

  Future<void> deletePersonImage(dynamic personId, int imageIndex) async {
    final db = await _databaseOrThrow();
    final res =
        await db.query('persons', where: 'id = ?', whereArgs: [personId]);
    if (res.isEmpty) return;

    List<String> embs = (res.first['embedding'] as String).split('|');
    List<String> imgs = (res.first['images'] as String).split('|');

    if (imageIndex >= 0 && imageIndex < imgs.length) {
      embs.removeAt(imageIndex);
      imgs.removeAt(imageIndex);
    }

    await db.update(
        'persons',
        {
          'embedding': embs.join('|'),
          'images': imgs.join('|'),
        },
        where: 'id = ?',
        whereArgs: [personId]);
    await reloadCache();
  }

  Future<void> appendPersonImage(
      dynamic id, Map<String, dynamic> faceData) async {
    final db = await _databaseOrThrow();
    final res = await db.query('persons', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return;

    String embs = res.first['embedding'] as String;
    String imgs = res.first['images'] as String;
    final emb = faceData['embedding'];
    String newEmb = '';
    if (emb != null) {
      if (emb is Float32List) {
        newEmb = emb.join(',');
      } else if (emb is List) {
        newEmb = emb.join(',');
      } else {
        newEmb = emb.toString();
      }
    }
    String newImg = faceData['image_path'] ?? '';

    await db.update(
        'persons',
        {
          'embedding': embs.isEmpty ? newEmb : '$embs|$newEmb',
          'images': imgs.isEmpty ? newImg : '$imgs|$newImg',
        },
        where: 'id = ?',
        whereArgs: [id]);
    await reloadCache();
  }

  Future<void> addUnknownPerson(dynamic arg1, dynamic arg2,
      [dynamic arg3]) async {
    final db = await _databaseOrThrow();
    String imagePath = arg1.toString();
    String embeddingStr = "";
    String timestamp = arg3?.toString() ?? DateTime.now().toIso8601String();
    final childId = await _currentChildId();

    if (arg2 is Float32List) {
      embeddingStr = arg2.join(',');
    } else {
      imagePath = arg2.toString();
    }

    await db.insert('unknown_persons', {
      'child_id': childId,
      'image_path': imagePath,
      'embedding': embeddingStr,
      'timestamp': timestamp,
    });
  }

  Future<void> deleteUnknownPerson(dynamic id) async {
    final db = await _databaseOrThrow();
    await db.delete('unknown_persons', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getUnknownPersons({int? childId}) async {
    final db = await _databaseOrThrow();
    if (childId == null) {
      return db.query('unknown_persons', orderBy: 'timestamp DESC');
    }
    return db.query(
      'unknown_persons',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'timestamp DESC',
    );
  }

  // --- IMAGE PROCESSING ---

  Future<img.Image> validateAndCropFaceFromFile(String path) async {
    // 1. Try ML Kit directly on the file (fastest)
    List<Face> faces =
        await _faceDetector.processImage(InputImage.fromFilePath(path));

    final bytes = await File(path).readAsBytes();
    img.Image? fullImage = img.decodeImage(bytes);
    if (fullImage == null) throw FaceValidationError("Failed to decode image");

    // 2. If not detected, try baking orientation (common issue with camera EXIF)
    if (faces.isEmpty) {
      fullImage = img.bakeOrientation(fullImage);
      // Save temp file to process with ML Kit again
      final tempPath = path + "_baked.jpg";
      await File(tempPath).writeAsBytes(img.encodeJpg(fullImage, quality: 90));
      faces =
          await _faceDetector.processImage(InputImage.fromFilePath(tempPath));
      try {
        await File(tempPath).delete();
      } catch (_) {}
    }

    if (faces.isEmpty) {
      // 3. Last resort: resize down if it's too huge and try again
      if (fullImage.width > 1200 || fullImage.height > 1200) {
        fullImage = img.copyResize(fullImage,
            width: fullImage.width > fullImage.height ? 1024 : null,
            height: fullImage.height >= fullImage.width ? 1024 : null);
        final tempPath = path + "_resized.jpg";
        await File(tempPath)
            .writeAsBytes(img.encodeJpg(fullImage, quality: 85));
        faces =
            await _faceDetector.processImage(InputImage.fromFilePath(tempPath));
        try {
          await File(tempPath).delete();
        } catch (_) {}
      }
    }

    if (faces.isEmpty) {
      throw FaceValidationError(
          "Face not detected. Please make sure your face is clearly visible and well-lit.");
    }

    // Crop the first face
    final rect = faces.first.boundingBox;

    // Ensure rect is within image bounds to prevent crashes
    int x = rect.left.toInt().clamp(0, fullImage.width - 1);
    int y = rect.top.toInt().clamp(0, fullImage.height - 1);
    int w = rect.width.toInt().clamp(1, fullImage.width - x);
    int h = rect.height.toInt().clamp(1, fullImage.height - y);

    return img.copyCrop(fullImage, x: x, y: y, width: w, height: h);
  }



  Float32List? getEmbedding(img.Image faceImage) {
    if (_interpreter == null) return null;
    final resized = img.copyResize(faceImage, width: 112, height: 112);
    final input = List.generate(
        1,
        (_) => List.generate(
            112,
            (y) => List.generate(112, (x) {
                  final p = resized.getPixel(x, y);
                  return [
                    (p.r - 127.5) / 128.0,
                    (p.g - 127.5) / 128.0,
                    (p.b - 127.5) / 128.0
                  ];
                })));
    final output = List.generate(1, (_) => List.filled(128, 0.0));
    _interpreter!.run(input, output);
    return Float32List.fromList(output[0].map((e) => e.toDouble()).toList());
  }

  double _cosineDistance(Float32List a, Float32List b) {
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return 1.0 - (dot / (sqrt(normA) * sqrt(normB)));
  }


  void dispose() {
    _faceDetector.close();
    _interpreter?.close();
  }
}

class FaceValidationError implements Exception {
  final String message;
  FaceValidationError(this.message);
  @override
  String toString() => message;
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' hide context;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/backend_service.dart';
import '../../services/face_recognition_service.dart';
import '../../l10n.dart';

class UnknownScreen extends StatefulWidget {
  const UnknownScreen({super.key});

  @override
  State<UnknownScreen> createState() => _UnknownScreenState();
}

class _UnknownScreenState extends State<UnknownScreen> with WidgetsBindingObserver {
  final Map<String, TextEditingController> nameControllers = {};
  final List<Map<String, dynamic>> data = [];
  bool loading = true;
  String? error;
  Timer? _pollTimer;
  String? userRole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FaceRecognitionService.instance.init().catchError((e) {
      if (mounted) {
        setState(() {
          error = "Failed to initialize local face database.\nReason: $e";
          loading = false;
        });
      }
    });
    load();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !loading) {
        load();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in nameControllers.values) {
      controller.dispose();
    }
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    final merged = <Map<String, dynamic>>[];
    int currentChildId = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      userRole = prefs.getString('role');
      currentChildId = int.tryParse(
            prefs.getString('linked_child_id') ??
                prefs.getString('child_id') ??
                prefs.getString('auth_id') ??
                '0',
          ) ??
          0;
      final token = prefs.getString('access_token');
      debugPrint('Unknown load role=$userRole token=${token != null}');

      final backendUnknowns = await BackendService.instance.getUnknown();
      for (final item in backendUnknowns) {
        final id = item['id']?.toString() ?? '';
        final imageUrl = (item['url'] ?? item['image_path'] ?? '').toString();
        if (id.isEmpty || imageUrl.isEmpty) continue;
        nameControllers.putIfAbsent(id, () => TextEditingController());
        final cacheBuster = DateTime.now().millisecondsSinceEpoch;
        merged.add({
          'id': id,
          'image_path': imageUrl.contains('?') ? '$imageUrl&cb=$cacheBuster' : '$imageUrl?cb=$cacheBuster',
          'source': 'backend',
          'child_id': item['child_id']?.toString() ?? '',
          'child_name': item['child_name']?.toString() ?? '',
          'created_at': item['detected_at']?.toString() ?? '',
        });
      }
    } catch (e) {
      debugPrint("Backend unknown fetch error: $e");
    }

    try {
      final localUnknowns = await FaceRecognitionService.instance.getUnknownPersons(childId: currentChildId);
      for (final item in localUnknowns) {
        final id = item['id']?.toString() ?? '';
        final imagePath = item['image_path']?.toString() ?? '';
        if (id.isEmpty || imagePath.isEmpty) continue;
        if (merged.any((entry) => entry['id'] == id)) continue;
        nameControllers.putIfAbsent(id, () => TextEditingController());
        merged.add({
          'id': id,
          'image_path': imagePath,
          'source': 'local',
          'child_id': '',
          'child_name': '',
          'created_at': item['timestamp']?.toString() ?? '',
        });
      }
    } catch (e) {
      debugPrint("Local unknown fetch error: $e");
    }

    if (mounted) {
      setState(() {
        data
          ..clear()
          ..addAll(merged);
        loading = false;
        error = merged.isEmpty ? error : null;
      });
    }
  }

  Future<void> _captureUnknown() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null) return;
    await BackendService.instance.recordCapturedPhotoAsUnknown(picked.path);
    await load();
  }

  Future<void> save(String id, String imagePath, String source) async {
    final name = nameControllers[id]?.text.trim() ?? '';
    if (name.isEmpty) {
      _snack(L10n.tr('unknown_name_required'), isError: true);
      return;
    }

    setState(() => loading = true);
    try {
      File fileToSave;
      if (source == 'backend') {
        final response = await http.get(Uri.parse(imagePath)).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw Exception("Failed to download image from backend.");
        }
        final tempDir = await getTemporaryDirectory();
        fileToSave = File(join(tempDir.path, 'unk_$id.jpg'));
        await fileToSave.writeAsBytes(response.bodyBytes);
      } else {
        fileToSave = File(imagePath);
      }

      img.Image? croppedImg;
      Float32List? embedding;
      try {
        croppedImg = await FaceRecognitionService.instance.validateAndCropFaceFromFile(fileToSave.path);
        embedding = FaceRecognitionService.instance.getEmbedding(croppedImg);
      } catch (e) {
        debugPrint("Face crop failed: $e");
      }

      final savedDir = await getApplicationDocumentsDirectory();
      final savedPath = join(savedDir.path, '${DateTime.now().millisecondsSinceEpoch}.png');

      if (croppedImg != null && embedding != null) {
        await File(savedPath).writeAsBytes(img.encodePng(croppedImg));
        await FaceRecognitionService.instance.savePerson(name, [
          {'embedding': embedding, 'image_path': savedPath}
        ]);
      } else {
        final bytes = await fileToSave.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          await File(savedPath).writeAsBytes(img.encodePng(decoded));
        } else {
          await fileToSave.copy(savedPath);
        }
        await FaceRecognitionService.instance.savePerson(name, [
          {'embedding': Float32List(128), 'image_path': savedPath}
        ]);
      }

      await FaceRecognitionService.instance.reloadCache();

      if (source == 'backend') {
        final ok = await BackendService.instance.convertUnknown(name: name, unknownId: id);
        if (!ok) {
          throw Exception("Backend conversion failed");
        }
      } else {
        await FaceRecognitionService.instance.deleteUnknownPerson(int.tryParse(id) ?? 0);
      }

      _snack("${L10n.tr('success')} $name");
    } catch (e) {
      _snack("${L10n.tr('error')}: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
      await load();
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Widget _buildImage(Map<String, dynamic> item) {
    final source = item['source']?.toString() ?? 'local';
    final path = item['image_path']?.toString() ?? '';
    if (path.isEmpty) {
      return const SizedBox(height: 220, child: Center(child: Icon(Icons.broken_image, size: 60, color: Colors.grey)));
    }

    if (source == 'backend') {
      return Image.network(
        path,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(height: 220, child: Center(child: Icon(Icons.broken_image, size: 60, color: Colors.grey))),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
        },
      );
    }

    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, height: 220, width: double.infinity, fit: BoxFit.cover);
    }

    return const SizedBox(height: 220, child: Center(child: Icon(Icons.image_not_supported, size: 60, color: Colors.grey)));
  }

  @override
  Widget build(BuildContext context) {
    if (loading && data.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEEF4FB),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(L10n.tr('unknown_title')),
        backgroundColor: const Color(0xFF5B8DEF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loading ? null : load,
          ),
        ],
      ),
      floatingActionButton: userRole == 'child'
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF5B8DEF),
              onPressed: _captureUnknown,
              child: const Icon(Icons.camera_alt),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: load,
        child: data.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Center(child: Text(L10n.tr('unknown_none'))),
                  const SizedBox(height: 8),
                  Center(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(L10n.tr('unknown_desc'), textAlign: TextAlign.center),
                  )),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: data.length,
                itemBuilder: (_, index) {
                  final item = data[index];
                  final id = item['id']?.toString() ?? '';
                  final source = item['source']?.toString() ?? 'local';
                  final imagePath = item['image_path']?.toString() ?? '';
                  final controller = nameControllers[id] ??= TextEditingController();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildImage(item),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (userRole != 'child') ...[
                                TextField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    labelText: L10n.tr('unknown_name_label'),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: loading ? null : () => save(id, imagePath, source),
                                    icon: const Icon(Icons.save),
                                    label: Text(L10n.tr('unknown_save_known')),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF5B8DEF),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              if ((item['child_name']?.toString() ?? '').isNotEmpty)
                                Text("Child Name: ${item['child_name']}", style: const TextStyle(fontWeight: FontWeight.bold))
                              else if ((item['child_id']?.toString() ?? '').isNotEmpty)
                                Text("Child ID: ${item['child_id']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                              if ((item['created_at']?.toString() ?? '').isNotEmpty)
                                Text("Detected: ${item['created_at']}", style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

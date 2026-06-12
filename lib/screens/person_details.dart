import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' hide context;
import 'package:image/image.dart' as img;
import '../services/backend_service.dart';
import '../services/face_recognition_service.dart';

class PersonDetailsScreen extends StatefulWidget {
  final int id;
  final String name;

  const PersonDetailsScreen({super.key, required this.id, required this.name});

  @override
  State<PersonDetailsScreen> createState() => _PersonDetailsScreenState();
}

class _PersonDetailsScreenState extends State<PersonDetailsScreen> {
  List<Map<String, dynamic>> imagesData = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role');
      final backendName = widget.name;
      final res = role == 'parent'
          ? await BackendService.instance.getPersonImages(backendName)
          : await FaceRecognitionService.instance.getPersonImages(widget.id);
      setState(() {
        imagesData = res.map((item) {
          final dynamic dataItem = item;
          if (dataItem is String) {
            return {'id': 0, 'image_path': dataItem, 'source': 'backend'};
          }
          if (dataItem is Map) {
            return {
              'id': dataItem['id'] ?? dataItem['image_id'] ?? dataItem['index'] ?? 0,
              'image_path': dataItem['image_path']?.toString() ?? dataItem['image']?.toString() ?? '',
              'source': dataItem['source']?.toString() ?? 'backend',
            };
          }
          return {'id': 0, 'image_path': '', 'source': 'backend'};
        }).toList();
      });
    } catch (e) {
      debugPrint("ERROR: $e");
      try {
        final res = await FaceRecognitionService.instance.getPersonImages(widget.id);
        setState(() {
          imagesData = res.map((item) {
            if (item is Map) {
              return {
                'id': item['id'] ?? 0,
                'image_path': item['image_path']?.toString() ?? '',
                'source': 'local',
              };
            }
            return {'id': 0, 'image_path': item.toString(), 'source': 'local'};
          }).toList();
        });
      } catch (fallbackErr) {
        debugPrint("Fallback ERROR: $fallbackErr");
      }
    }
    if (mounted) setState(() => loading = false);
  }

  void _deleteImage(int imageIndex) async {
    await FaceRecognitionService.instance.deletePersonImage(widget.id, imageIndex);
    await FaceRecognitionService.instance.reloadCache();
    if (mounted) load();
  }

  void _addImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => loading = true);
    try {
      final crop = await FaceRecognitionService.instance.validateAndCropFaceFromFile(pickedFile.path);
      final emb = FaceRecognitionService.instance.getEmbedding(crop);
      if (emb != null) {
        // Save the raw crop to disk for displaying later
        final directory = await getApplicationDocumentsDirectory();
        final path = join(directory.path, '${DateTime.now().millisecondsSinceEpoch}.png');
        await File(path).writeAsBytes(img.encodePng(crop));

        await FaceRecognitionService.instance.appendPersonImage(widget.id, {
          'embedding': emb,
          'image_path': path,
        });
        await FaceRecognitionService.instance.reloadCache();
        if (mounted) load();
      }
    } catch(e) {
      debugPrint("Add Image Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFEEF4FB),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Embeddings Count: ${imagesData.length}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: imagesData.length,
                    itemBuilder: (context, index) {
                      final item = imagesData[index];
                      final path = item['image_path'] as String?;
                      final source = item['source']?.toString() ?? 'local';
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (path != null && path.isNotEmpty && source == 'backend')
                            Image.network(
                              path,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.broken_image, color: Colors.white),
                              ),
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(child: CircularProgressIndicator()),
                                );
                              },
                            )
                          else if (path != null && File(path).existsSync())
                            Image.file(File(path), fit: BoxFit.cover)
                          else
                            Container(color: Colors.grey, child: const Icon(Icons.person, color: Colors.white)),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteImage(item['id']),
                            ),
                          )
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addImage,
        child: const Icon(Icons.add_photo_alternate),
      ),
    );
  }
}

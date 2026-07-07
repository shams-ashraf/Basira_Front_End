import 'dart:io';
import 'dart:typed_data';


import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_header.dart';
import '../../services/backend_service.dart';
import '../../services/face_recognition_service.dart';
import '../../l10n.dart';

class AddPersonScreen extends StatefulWidget {
  const AddPersonScreen({super.key});

  @override
  State<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends State<AddPersonScreen> {

  final TextEditingController nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> images = [];

  bool loading = false;
  String? _bannerError;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await FaceRecognitionService.instance.init();
    } catch (e) {
      if (mounted) {
        setState(() {
          _bannerError = _friendlyError("Face service failed to start", e);
        });
      }
    }

  }

  String _friendlyError(String context, Object error) {
    final message = error.toString();
    if (message.contains("SocketException")) {
      return "$context.\nReason: the backend server cannot be reached.";
    }
    if (message.contains("TimeoutException")) {
      return "$context.\nReason: the request timed out.";
    }
    if (message.contains("Face not detected")) {
      return "$context.\nReason: no clear face was detected in the image.";
    }
    if (message.toLowerCase().contains("null")) {
      return "$context.\nReason: a required value was null during processing.";
    }
    return "$context.\nReason: $message";
  }



  Future<void> _addImage(XFile image) async {
    setState(() {
      images.add(image);
    });
  }

  Future<void> capture() async {
    try {
      setState(() {
        loading = true;
      });
      final picture = await _picker.pickImage(source: ImageSource.camera);
      if (picture != null) {
        await _addImage(picture);
        _showMsg("Image added successfully.");
      }
    } catch (e) {
      _showMsg(_friendlyError("Capture failed", e), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> upload() async {
    try {
      final pickedImages = await _picker.pickMultiImage();
      if (pickedImages.isEmpty) return;

      setState(() {
        images.addAll(pickedImages);
      });
      _showMsg("Added ${pickedImages.length} image(s) successfully.");
    } catch (e) {
      _showMsg(_friendlyError("Image upload failed", e), isError: true);
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Future<void> save() async {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      _showMsg(L10n.tr('add_person_name_required'), isError: true);
      return;
    }

    if (images.isEmpty) {
      _showMsg(L10n.tr('add_person_image_required'), isError: true);
      return;
    }

    setState(() {
      loading = true;
      _bannerError = null;
      _statusMessage = null;
    });

    final paths = images.map((e) => e.path).toList();

    try {
      final quickFaceData = paths
          .map(
            (path) => <String, dynamic>{
              'embedding': Float32List(128),
              'image_path': path,
            },
          )
          .toList();

      await FaceRecognitionService.instance.savePerson(name, quickFaceData);
      await FaceRecognitionService.instance.reloadCache();

      _showMsg("$name ${L10n.tr('add_person_success')}");
      if (!mounted) return;
      setState(() {
        loading = false;
      });
      Navigator.pop(context);

      _backgroundProcess(name, paths);
    } catch (e) {
      debugPrint("Immediate save error: $e");
      if (mounted) {
        setState(() {
          loading = false;
          _bannerError = _friendlyError("Save failed", e);
        });
      }
    }
  }

  Future<void> _backgroundProcess(String name, List<String> paths) async {
    try {
      final faceDataList = <Map<String, dynamic>>[];
      for (final path in paths) {
        Float32List? embedding;
        try {
          final croppedImage = await FaceRecognitionService.instance
              .validateAndCropFaceFromFile(path);
          embedding =
              FaceRecognitionService.instance.getEmbedding(croppedImage);
        } catch (e) {
          debugPrint("Background face processing for $path: $e");
        }

        faceDataList.add({
          'embedding': embedding,
          'image_path': path,
        });
      }

      await FaceRecognitionService.instance.savePerson(name, faceDataList);
      await FaceRecognitionService.instance.reloadCache();

      if (mounted) {
        setState(() {
          _statusMessage = "Local face data updated successfully.";
        });
      }
    } catch (e) {
      debugPrint("Background face processing error: $e");
      if (mounted) {
        setState(() {
          _statusMessage =
              _friendlyError("Background face processing failed", e);
        });
      }
    }

    try {
      await BackendService.instance.registerPerson(name, paths);
      if (mounted) {
        setState(() {
          _statusMessage = "Backend sync completed successfully.";
        });
      }
    } catch (e) {
      debugPrint("Background: backend sync failed for $name: $e");
      if (mounted) {
        setState(() {
          _statusMessage = _friendlyError("Backend sync failed", e);
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(title: L10n.tr('add_person_title')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (images.isNotEmpty)
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.file(
                      File(images.last.path),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: L10n.tr('add_person_name'),
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: loading ? null : capture,
                          icon: const Icon(Icons.camera_front),
                          label: Text(L10n.tr('add_person_capture')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B8DEF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: loading ? null : upload,
                          icon: const Icon(Icons.photo_library),
                          label: Text(L10n.tr('add_person_upload')),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Captured Samples (${images.length}/3)",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (images.isNotEmpty)
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        itemBuilder: (_, index) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(images[index].path),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.check,
                                      size: 12, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (_statusMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(color: Colors.amber.shade900),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: loading ? null : save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            L10n.tr('add_person_register'),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2),
                          ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

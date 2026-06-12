import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/backend_service.dart';
import '../services/face_recognition_service.dart';

class ChildPhoneCameraScreen extends StatefulWidget {
  const ChildPhoneCameraScreen({super.key});

  @override
  State<ChildPhoneCameraScreen> createState() => _ChildPhoneCameraScreenState();
}

class _ChildPhoneCameraScreenState extends State<ChildPhoneCameraScreen> {
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    FaceRecognitionService.instance.init().catchError((e) {
      debugPrint("Face DB init error in phone camera: $e");
    });
  }

  Future<void> _captureAndUpload() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return;

    setState(() => uploading = true);
    try {
      await BackendService.instance.recordCapturedPhotoAsUnknown(photo.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Photo sent to server and saved as unknown"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF4FB),
      appBar: AppBar(
        title: const Text("Phone Camera"),
        backgroundColor: const Color(0xFF5B8DEF),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: uploading
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                onPressed: _captureAndUpload,
                icon: const Icon(Icons.camera_alt),
                label: const Text("Take Photo"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B8DEF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
      ),
    );
  }
}

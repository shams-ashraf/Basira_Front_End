import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/backend_service.dart';

class ChildUnknownCaptureScreen extends StatefulWidget {
  const ChildUnknownCaptureScreen({super.key});

  @override
  State<ChildUnknownCaptureScreen> createState() => _ChildUnknownCaptureScreenState();
}

class _ChildUnknownCaptureScreenState extends State<ChildUnknownCaptureScreen> {
  bool _capturing = false;

  Future<void> _captureAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() => _capturing = true);
      try {
        await BackendService.instance.recordCapturedPhotoAsUnknown(picked.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Photo saved as unknown person'),
            backgroundColor: Colors.green,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ));
        }
      } finally {
        if (mounted) setState(() => _capturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Unknown Person'),
        backgroundColor: const Color(0xFF5B8DEF),
      ),
      backgroundColor: const Color(0xFFEEF4FB),
      body: Center(
        child: _capturing
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                onPressed: _captureAndUpload,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Capture & Upload'),
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

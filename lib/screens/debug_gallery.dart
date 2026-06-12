import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class DebugGalleryScreen extends StatefulWidget {
  const DebugGalleryScreen({super.key});

  @override
  State<DebugGalleryScreen> createState() => _DebugGalleryScreenState();
}

class _DebugGalleryScreenState extends State<DebugGalleryScreen> {
  List<File> debugImages = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => loading = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir.listSync();
      
      final images = files
          .whereType<File>()
          .where((f) => f.path.contains('yolo_debug_'))
          .toList();
          
      // Sort by newest first
      images.sort((a, b) => b.path.compareTo(a.path));
      
      setState(() {
        debugImages = images;
      });
    } catch (e) {
      debugPrint("Load debug images error: $e");
    }
    setState(() => loading = false);
  }

  Future<void> _clearGallery() async {
    for (var f in debugImages) {
      if (f.existsSync()) f.deleteSync();
    }
    _loadImages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Vision Debug Gallery"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _clearGallery,
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
          ),
          IconButton(
            onPressed: _loadImages,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : debugImages.isEmpty
              ? const Center(
                  child: Text(
                    "No debug images yet.\nTry to detect objects first!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: debugImages.length,
                  itemBuilder: (context, index) {
                    final file = debugImages[index];
                    return GestureDetector(
                      onTap: () => _showFullImage(file),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(file, fit: BoxFit.cover),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black54,
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                child: Text(
                                  file.path.split('/').last.replaceAll('yolo_debug_', ''),
                                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showFullImage(File file) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(child: Image.file(file)),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

import '../services/face_recognition_service.dart';
import '../services/voice_service.dart';
import '../services/backend_service.dart';
import '../services/yolo_detector.dart';
import '../services/scene_service.dart';
import 'package:image/image.dart' as img;
import 'dart:io';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  YoloDetector? detector;
  List<YoloDetection> detections = const [];

  int _frameCount = 0;
  String? _error;
  String? _mode;
  
  bool _isProcessingFace = false;
  Timer? _objectModeTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    _mode = args?['mode'];
  }

  @override
  void initState() {
    super.initState();
    initCam();
  }

  Future<void> initCam() async {
    try {
      await FaceRecognitionService.instance.init();
      detector = await YoloDetector.load();

      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => _error = 'No camera found');
        return;
      }

      controller = CameraController(
        cams[0],
        ResolutionPreset.medium, // Medium for faster processing (standard for real-time YOLO)
        enableAudio: false,
      );

      await controller!.initialize();
      await controller!.startImageStream(_processCameraImage);

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    _frameCount++;
    // Process every 2nd frame for better responsiveness (was every 3rd)
    if (_frameCount % 2 != 0) return; 
    if (detector == null || detector!.isProcessing) return;

    try {
      final results = await detector!.detect(image);
      if (!mounted) return;
      setState(() {
        detections = results;
      });

      _handleDetections(results, image);
    } catch (e) {
      debugPrint('Detection Error: $e');
    }
  }

  Future<void> _handleDetections(List<YoloDetection> results, CameraImage image) async {
    if (results.isEmpty) return;

    // Check for persons first
    bool personFound = false;
    for (var d in results) {
      if (d.label == 'person' && d.score > 0.45) { // Slightly lower threshold for early detection
        personFound = true;
        // Adjusted bbox size check for medium resolution
        if (d.box.width > 60 && d.box.height > 60 && !_isProcessingFace) {
          _processFace(image, d);
          break; 
        }
      }
    }

    // Voice announcement logic
    if (!personFound && _mode == "object" && results.isNotEmpty) {
      final best = results.first;
      if (best.score > 0.5) {
        String pos = _getSpatialPosition(best.box, image.width.toDouble());
        VoiceService.instance.speak("Found a ${best.label} on your $pos");
      }
    } else if (!personFound && _mode == "scene" && results.isNotEmpty) {
      if (_frameCount % 40 == 0) { 
        final items = results.take(3).map((e) => e.label).toSet().join(" and ");
        VoiceService.instance.speak("I see $items");
      }
    }
  }

  String _getSpatialPosition(Rect box, double imageWidth) {
    double centerX = box.left + (box.width / 2);
    double ratio = centerX / imageWidth;
    
    if (ratio < 0.35) return "left";
    if (ratio > 0.65) return "right";
    return "center";
  }

  Future<void> _processFace(CameraImage image, YoloDetection personDetection) async {
    _isProcessingFace = true;
    try {
      // Convert sensor orientation to ML Kit rotation
      InputImageRotation rotation = InputImageRotation.rotation90deg;
      final sensorOri = controller!.description.sensorOrientation;
      if (sensorOri == 90) rotation = InputImageRotation.rotation90deg;
      if (sensorOri == 180) rotation = InputImageRotation.rotation180deg;
      if (sensorOri == 270) rotation = InputImageRotation.rotation270deg;

      final faceCrop = await FaceRecognitionService.instance.detectAndCropFace(image, rotation);
      if (faceCrop != null) {
        final emb = FaceRecognitionService.instance.getEmbedding(faceCrop);
        if (emb != null) {
          final name = await FaceRecognitionService.instance.recognize(emb);
          String pos = _getSpatialPosition(personDetection.box, image.width.toDouble());
          
          if (name != null) {
            VoiceService.instance.speak("$name is on your $pos");
          } else {
            // Save the cropped face locally
            final appDir = await getApplicationDocumentsDirectory();
            final unknownFolder = Directory('${appDir.path}/unknown_faces');
            if (!await unknownFolder.exists()) {
              await unknownFolder.create(recursive: true);
            }
            final localPath = '${unknownFolder.path}/unk_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final jpegBytes = img.encodeJpg(faceCrop);
            await File(localPath).writeAsBytes(jpegBytes);

            // Add to local database
            await FaceRecognitionService.instance.addUnknownPerson(localPath, localPath);

            // Upload to backend
            try {
              await BackendService.instance.uploadUnknownFace(localPath);
            } catch (backendErr) {
              debugPrint("Failed to upload unknown face to backend: $backendErr");
            }

            // Reload local cache
            await FaceRecognitionService.instance.reloadCache();

            VoiceService.instance.speak("Unknown person ahead");
            if (mounted) {
              // Wait a bit so the voice can finish before popping
              await Future.delayed(const Duration(seconds: 1));
              Navigator.pushNamed(context, "/unknown");
            }
          }
        }
      }
    } finally {
      // Cooldown for face processing (3 seconds)
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _isProcessingFace = false;
      });
    }
  }

  @override
  void dispose() {
    _objectModeTimer?.cancel();
    controller?.stopImageStream();
    controller?.dispose();
    detector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text(_error!, style: const TextStyle(color: Colors.white))),
      );
    }

    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 1 / controller!.value.aspectRatio,
              child: CameraPreview(controller!),
            ),
          ),
          CustomPaint(
            painter: _YoloOverlayPainter(
              detections: detections,
              imageSize: Size(
                controller!.value.previewSize!.height,
                controller!.value.previewSize!.width,
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 50,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                'VISION ACTIVE\nMode: ${_mode?.toUpperCase() ?? "SCAN"}',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_mode == "scene")
                    FloatingActionButton.extended(
                      onPressed: _captureAndDescribeScene,
                      backgroundColor: const Color(0xFF38BDF8),
                      icon: const Icon(Icons.description, color: Colors.white),
                      label: const Text("DESCRIBE SCENE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  FloatingActionButton.large(
                    onPressed: () => Navigator.pop(context),
                    backgroundColor: Colors.redAccent,
                    child: const Icon(Icons.close, size: 36, color: Colors.white),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _captureAndDescribeScene() async {
    if (controller == null || !controller!.value.isInitialized) return;

    try {
      final image = await controller!.takePicture();
      final bytes = await image.readAsBytes();
      final decoded = img.decodeImage(bytes);
      
      if (decoded != null) {
        final description = await SceneService.instance.getSceneDescription(File(image.path));
        VoiceService.instance.speak(description);
      }
    } catch (e) {
      debugPrint("Capture Error: $e");
    }
  }
}

class _YoloOverlayPainter extends CustomPainter {
  const _YoloOverlayPainter({required this.detections, required this.imageSize});

  final List<YoloDetection> detections;
  final Size imageSize; // This is the portrait preview size (e.g. 480x640)

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.isEmpty) return;

    // imageSize is portrait (e.g. 480x640), detections are in landscape (e.g. 640x480)
    // We need to map (lx, ly) in landscape 640x480 to (px, py) in portrait 480x640
    // lx: 0..640, ly: 0..480  => px = ly, py = 640 - lx
    
    final landscapeWidth = imageSize.height; // e.g. 640
    final landscapeHeight = imageSize.width; // e.g. 480

    final scale = math.max(size.width / imageSize.width, size.height / imageSize.height);
    final dx = (size.width - imageSize.width * scale) / 2;
    final dy = (size.height - imageSize.height * scale) / 2;

    final paint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (final d in detections) {
      // Map landscape coordinates to portrait
      // Landscape Rect: (left, top, right, bottom)
      // Portrait Rect:
      final pLeft = d.box.top;
      final pTop = landscapeWidth - d.box.right;
      final pRight = d.box.bottom;
      final pBottom = landscapeWidth - d.box.left;

      final rect = Rect.fromLTRB(
        pLeft * scale + dx,
        pTop * scale + dy,
        pRight * scale + dx,
        pBottom * scale + dy,
      );
      
      canvas.drawRect(rect, paint);
      
      final textSpan = TextSpan(
        text: '${d.label} ${(d.score * 100).toStringAsFixed(0)}%',
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      
      canvas.drawRect(Rect.fromLTWH(rect.left, rect.top - 20, textPainter.width + 10, 20), Paint()..color = const Color(0xFF38BDF8));
      textPainter.paint(canvas, Offset(rect.left + 5, rect.top - 18));
    }
  }

  @override
  bool shouldRepaint(covariant _YoloOverlayPainter oldDelegate) => true;
}

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class YoloDetection {
  YoloDetection({
    required this.label,
    required this.score,
    required this.box,
  });

  final String label;
  final double score;
  final Rect box;
}

class _IsolateData {
  final List<Uint8List> planes;
  final List<int> strides;
  final List<int> pixelStrides;
  final int width;
  final int height;
  final SendPort sendPort;

  _IsolateData({
    required this.planes,
    required this.strides,
    required this.pixelStrides,
    required this.width,
    required this.height,
    required this.sendPort,
  });
}

class _IsolateJpegData {
  final Uint8List bytes;
  final SendPort sendPort;
  _IsolateJpegData({required this.bytes, required this.sendPort});
}

class YoloDetector {
  YoloDetector._(this._sendPort, this._receivePort) {
    _receivePort.listen((message) async {
      if (message is List<YoloDetection>) {
        _isProcessing = false;
        _completer?.complete(message);
      } else if (message is Uint8List) {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final file = File("${dir.path}/yolo_debug_${DateTime.now().millisecondsSinceEpoch}.jpg");
          await file.writeAsBytes(message);
        } catch (_) {}
      }
    });
  }

  static YoloDetector? instance;
  static bool _isLoading = false;

  final SendPort _sendPort;
  final ReceivePort _receivePort;
  Completer<List<YoloDetection>>? _completer;
  bool _isProcessing = false;

  static const _modelPath = 'assets/models/yolov8n_float32.tflite';
  static const _confidenceThreshold = 0.35;

  bool get isProcessing => _isProcessing;

  static Future<YoloDetector> load() async {
    if (instance != null) return instance!;
    if (_isLoading) {
      while (instance == null) await Future.delayed(const Duration(milliseconds: 100));
      return instance!;
    }
    _isLoading = true;

    final initPort = ReceivePort();
    await Isolate.spawn(_isolateEntry, initPort.sendPort);

    final isolateSendPort = await initPort.first as SendPort;
    initPort.close();

    final receivePort = ReceivePort();
    instance = YoloDetector._(isolateSendPort, receivePort);
    _isLoading = false;
    return instance!;
  }

  Future<List<YoloDetection>> detect(CameraImage image) async {
    if (_isProcessing) return [];
    _isProcessing = true;
    _completer = Completer<List<YoloDetection>>();

    _sendPort.send(_IsolateData(
      planes: image.planes.map((p) => p.bytes).toList(),
      strides: image.planes.map((p) => p.bytesPerRow).toList(),
      pixelStrides: image.planes.map((p) => p.bytesPerPixel ?? 1).toList(),
      width: image.width,
      height: image.height,
      sendPort: _receivePort.sendPort,
    ));

    return _completer!.future;
  }

  Future<List<YoloDetection>> detectFromJpeg(Uint8List bytes) async {
    if (_isProcessing) return [];
    _isProcessing = true;
    _completer = Completer<List<YoloDetection>>();
    _sendPort.send(_IsolateJpegData(bytes: bytes, sendPort: _receivePort.sendPort));
    return _completer!.future;
  }

  void close() => _receivePort.close();

  static void _isolateEntry(SendPort mainSendPort) async {
    final commandPort = ReceivePort();
    mainSendPort.send(commandPort.sendPort);

    Interpreter? interpreter;
    int inputSize = 640;

    try {
      final options = InterpreterOptions()..threads = 2;
      interpreter = await Interpreter.fromAsset(_modelPath, options: options);
      interpreter.allocateTensors();
      inputSize = interpreter.getInputTensor(0).shape[1];
    } catch (e) {
      debugPrint("Yolo Isolate Init Error: $e");
    }

    commandPort.listen((message) {
      if (interpreter == null) return;
      
      try {
        img.Image? image;
        SendPort? replyPort;

        if (message is _IsolateData) {
          image = _cameraImageToRgb(message);
          replyPort = message.sendPort;
        } else if (message is _IsolateJpegData) {
          image = img.decodeJpg(message.bytes);
          replyPort = message.sendPort;
        }

        if (image == null || replyPort == null) return;

        final resized = img.copyResize(image, width: inputSize, height: inputSize);
        final input = [
          List.generate(inputSize, (y) {
            return List.generate(inputSize, (x) {
              final p = resized.getPixel(x, y);
              return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
            });
          }),
        ];

        final outputShape = interpreter!.getOutputTensor(0).shape;
        final output = List.generate(outputShape[0], (_) => List.generate(outputShape[1], (_) => List<double>.filled(outputShape[2], 0)));

        interpreter!.run(input, output);

        final detections = _parseYolov8Output(output, inputSize, Size(image.width.toDouble(), image.height.toDouble()));
        
        // Debug Capture
        if (math.Random().nextInt(15) == 0) {
          final debugImg = img.copyResize(image, width: 320);
          mainSendPort.send(img.encodeJpg(debugImg));
        }

        replyPort.send(detections);
      } catch (e) {
        debugPrint("Isolate Process Error: $e");
      }
    });
  }

  static img.Image _cameraImageToRgb(_IsolateData data) {
    final width = data.width, height = data.height;
    final out = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      final yRow = y * data.strides[0];
      final uvY = y >> 1;
      final uRow = uvY * data.strides[1];
      final vRow = uvY * data.strides[2];

      for (int x = 0; x < width; x++) {
        final yp = data.planes[0][yRow + x];
        final uvX = x >> 1;
        final uIndex = uRow + uvX * data.pixelStrides[1];
        final vIndex = vRow + uvX * data.pixelStrides[2];
        final up = data.planes[1][uIndex];
        final vp = data.planes[2][vIndex];

        final r = (yp + 1.402 * (vp - 128)).round().clamp(0, 255);
        final g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).round().clamp(0, 255);
        final b = (yp + 1.772 * (up - 128)).round().clamp(0, 255);

        out.setPixelRgba(x, y, r, g, b, 255);
      }
    }
    return out;
  }

  static List<YoloDetection> _parseYolov8Output(Object output, int inputSize, Size sourceSize) {
    final raw = (output as List).first as List;
    final predictions = _normalizePredictions(raw);
    final candidates = <YoloDetection>[];

    for (final data in predictions) {
      double bestScore = 0;
      int bestClass = 0;
      for (int i = 4; i < data.length; i++) {
        if (data[i] > bestScore) { bestScore = data[i]; bestClass = i - 4; }
      }
      if (bestScore < _confidenceThreshold) continue;

      final cx = data[0] / inputSize;
      final cy = data[1] / inputSize;
      final w = data[2] / inputSize;
      final h = data[3] / inputSize;

      candidates.add(YoloDetection(
        label: bestClass < _cocoLabels.length ? _cocoLabels[bestClass] : 'object',
        score: bestScore,
        box: Rect.fromLTRB(
          (cx - w / 2) * sourceSize.width,
          (cy - h / 2) * sourceSize.height,
          (cx + w / 2) * sourceSize.width,
          (cy + h / 2) * sourceSize.height,
        ),
      ));
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.take(10).toList();
  }

  static List<List<double>> _normalizePredictions(List raw) {
    if (raw.isEmpty) return const [];
    final first = (raw.first as List).cast<double>();
    if (raw.length < first.length && first.length > 100) {
      return List.generate(first.length, (column) => List.generate(raw.length, (row) => ((raw[row] as List)[column] as num).toDouble()));
    }
    return raw.map((p) => (p as List).map((v) => (v as num).toDouble()).toList()).toList();
  }
}

const _cocoLabels = [
  'person','bicycle','car','motorcycle','airplane','bus','train','truck','boat','traffic light',
  'fire hydrant','stop sign','parking meter','bench','bird','cat','dog','horse','sheep','cow',
  'elephant','bear','zebra','giraffe','backpack','umbrella','handbag','tie','suitcase','frisbee',
  'skis','snowboard','sports ball','kite','baseball bat','baseball glove','skateboard','surfboard',
  'tennis racket','bottle','wine glass','cup','fork','knife','spoon','bowl','banana','apple',
  'sandwich','orange','broccoli','carrot','hot dog','pizza','donut','cake','chair','couch',
  'potted plant','bed','dining table','toilet','tv','laptop','mouse','remote','keyboard',
  'cell phone','microwave','oven','toaster','sink','refrigerator','book','clock','vase',
  'scissors','teddy bear','hair drier','toothbrush',
];

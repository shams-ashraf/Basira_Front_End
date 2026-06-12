import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../config.dart';
import '../services/ai_lab_api_service.dart';

enum AILabMode { objectDetection, sceneSummary }

class AILabResultPage extends StatefulWidget {
  final File imageFile;
  final AILabMode mode;

  const AILabResultPage({
    super.key,
    required this.imageFile,
    required this.mode,
  });

  @override
  State<AILabResultPage> createState() => _AILabResultPageState();
}

class _AILabResultPageState extends State<AILabResultPage> {
  bool _done = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    unawaited(_runFlow());
  }

  Future<void> _runFlow() async {
    if (widget.mode == AILabMode.objectDetection) {
      await _runObjectDetection();
    } else {
      await _runSceneSummary();
    }
  }

  Future<void> _runObjectDetection() async {
    Map<String, dynamic> response;
    try {
      response = await AILabApiService.instance.runObjectDetection(widget.imageFile.path);
    } catch (e) {
      response = {
        'success': false,
        'error': e.toString(),
        'detected_objects': [],
        'person_detected': false,
        'similarity_scores': {},
        'timings': {},
        'step_logs': [
          {'title': 'Error', 'result': [e.toString()]},
        ],
      };
    }
    if (!mounted) return;
    setState(() {
      _result = response;
      _done = true;
    });
  }

  Future<void> _runSceneSummary() async {
    Map<String, dynamic> response;
    try {
      response = await AILabApiService.instance.runSceneSummary(widget.imageFile.path);
    } catch (e) {
      response = {
        'success': false,
        'error': e.toString(),
        'step_logs': [
          {'title': 'Error', 'result': [e.toString()]},
        ],
      };
    }
    if (!mounted) return;
    setState(() {
      _result = response;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == AILabMode.objectDetection
        ? 'Object Detection Result'
        : 'Scene Summary Result';

    return Scaffold(
      backgroundColor: const Color(0xFFEEF4FB),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF5B8DEF),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.file(widget.imageFile, height: 240, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Process Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (!_done)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_result != null) ...[
            const SizedBox(height: 8),
            _buildStepLog(),
            const SizedBox(height: 16),
            _buildResultCard(),
            if (_result!['error'] != null) ...[
              const SizedBox(height: 12),
              Text(
                'Error: ${_result!['error']}',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              if (_result!['traceback'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  _result!['traceback'].toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    if (widget.mode == AILabMode.objectDetection) {
      final result = _result!;
      final scores = Map<String, dynamic>.from(result['similarity_scores'] ?? result['scores'] ?? {});
      final timings = Map<String, dynamic>.from(result['timings'] ?? {});
      final detections = List<String>.from(result['detected_objects'] ?? result['objects'] ?? []);
      final processedImageUrl = result['processed_image_url']?.toString();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Original Image', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Image.file(widget.imageFile, height: 180, fit: BoxFit.cover),
              const SizedBox(height: 12),
              const Text('Processed Image', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (processedImageUrl != null && processedImageUrl.isNotEmpty)
                Image.network(
                  processedImageUrl.startsWith('http')
                      ? processedImageUrl
                      : '${AppConfig.aiLabBaseUrl}$processedImageUrl',
                  height: 180,
                  fit: BoxFit.cover,
                )
              else
                Image.file(widget.imageFile, height: 180, fit: BoxFit.cover),
              const SizedBox(height: 12),
              const Text('Detected Objects', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(detections.isEmpty ? 'None' : detections.join(', ')),
              const SizedBox(height: 8),
              const Text('Detected Person', style: TextStyle(fontWeight: FontWeight.bold)),
              Text((result['person_detected'] ?? result['personDetected']) == true ? 'Yes' : 'No'),
              const SizedBox(height: 8),
              Text('Best Match: ${result['best_match'] ?? result['bestMatch'] ?? 'Unknown'}'),
              Text('Best Similarity Score: ${result['best_score'] ?? result['bestScore'] ?? 0}'),
              const SizedBox(height: 8),
              const Text('Full Similarity Scores', style: TextStyle(fontWeight: FontWeight.bold)),
              ...scores.entries.map((entry) => Text('${entry.key} : ${entry.value}')),
              const SizedBox(height: 8),
              const Text('Performance Metrics', style: TextStyle(fontWeight: FontWeight.bold)),
              ...timings.entries.map((entry) => Text('${entry.key}: ${entry.value}')),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BLIP Caption: ${_result!['blip_caption'] ?? _result!['blipCaption'] ?? ''}'),
            Text('BLIP Time: ${_result!['blip_time'] ?? _result!['blipTime'] ?? ''}'),
            const SizedBox(height: 10),
            Text('ViT Caption: ${_result!['vit_caption'] ?? _result!['vitCaption'] ?? ''}'),
            Text('ViT Time: ${_result!['vit_time'] ?? _result!['vitTime'] ?? ''}'),
            const SizedBox(height: 10),
            Text('Florence Caption: ${_result!['florence_caption'] ?? _result!['florenceCaption'] ?? ''}'),
            Text('Florence Time: ${_result!['florence_time'] ?? _result!['florenceTime'] ?? ''}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStepLog() {
    final logs = List<Map<String, dynamic>>.from(_result?['step_logs'] ?? []);
    if (logs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Live Steps', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...logs.map(
          (log) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...List.from(log['result'] ?? []).map((line) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(line.toString()),
                      )),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

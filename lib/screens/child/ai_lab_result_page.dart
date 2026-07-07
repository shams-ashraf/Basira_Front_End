import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config.dart';
import '../../services/ai_lab_api_service.dart';
import '../../services/backend_service.dart';
import '../../services/voice_service.dart';
import '../../l10n.dart';

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
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    unawaited(_runFlow());
  }

  Future<void> _runFlow() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString('language') ??
        (prefs.getString('voice_language')?.startsWith('ar') == true
            ? 'ar'
            : 'en');
    L10n.setLanguage(_language);
    if (widget.mode == AILabMode.objectDetection) {
      await _runObjectDetection();
    } else {
      await _runSceneSummary();
    }
  }

  Future<void> _runObjectDetection() async {
    Map<String, dynamic> response;
    try {
      response = await AILabApiService.instance
          .runObjectDetection(widget.imageFile.path);

      final speech = (response['spoken_text'] ?? '').toString().trim();
      if (speech.isNotEmpty) {
        await VoiceService.instance.speak(speech);
      }
    } catch (e) {
      response = {
        'success': false,
        'error': e.toString(),
        'detected_objects': [],
        'timings': {},
        'step_logs': [
          {
            'title': 'Error',
            'result': [e.toString()]
          },
        ],
      };
    }
    if (!mounted) return;
    setState(() {
      _result = response;
      _done = true;
    });
  }

  String _arLabel(String label) {
    switch (label.toLowerCase()) {
      case 'chair':
        return 'كرسي';
      case 'hanger':
        return 'شماعة';
      case 'fork':
        return 'شوكة';
      case 'knife':
        return 'سكين';
      case 'scissors':
        return 'مقص';
      case 'person':
        return 'شخص';
      default:
        return label;
    }
  }

  String _arEmotion(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return 'سعيد';
      case 'sad':
        return 'حزين';
      case 'angry':
        return 'غاضب';
      case 'fear':
        return 'خائف';
      case 'surprise':
        return 'مندهش';
      case 'disgust':
        return 'مشمئز';
      case 'neutral':
        return 'طبيعي';
      default:
        return emotion;
    }
  }

  String _arPosition(String pos) {
    switch (pos.toLowerCase()) {
      case 'left':
        return 'على يسارك';
      case 'right':
        return 'على يمينك';
      case 'center':
        return 'أمامك مباشرة';
      default:
        return 'أمامك';
    }
  }

  String _arDistance(String value) {
    switch (value.toLowerCase()) {
      case 'very close':
      case '50 cm':
        return 'قريب جداً منك';
      case 'near':
      case 'close':
      case '3 meters':
        return 'قريب منك';
      case 'far':
      case 'more than 3 meters':
        return 'بعيد نوعاً ما';
      default:
        return value;
    }
  }

  String _emotionText(Map<String, dynamic> response) {
    final sentence = (response['emotion_sentence'] ?? '').toString().trim();
    if (sentence.isNotEmpty) return sentence;
    final label = (response['emotion_label'] ?? '').toString().trim();
    if (label.isEmpty) return '';
    return _language == 'ar'
        ? 'ويبدو أنه ${_arEmotion(label)}.'
        : 'Emotion: $label.';
  }

  Future<void> _runSceneSummary() async {
    Map<String, dynamic> response;
    try {
      response =
          await AILabApiService.instance.runSceneSummary(widget.imageFile.path);
    } catch (e) {
      response = {
        'success': false,
        'error': e.toString(),
        'step_logs': [
          {
            'title': 'Error',
            'result': [e.toString()]
          },
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
        ? L10n.tr('result_object_title')
        : L10n.tr('result_scene_title');

    return WillPopScope(
      onWillPop: () async {
        await VoiceService.instance.stopSpeech();
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEEF4FB),
        appBar: AppBar(
          automaticallyImplyLeading: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () async {
              await VoiceService.instance.stopSpeech();
              if (context.mounted) Navigator.maybePop(context);
            },
          ),
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
                child: Image.file(widget.imageFile,
                    height: 240, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 12),
            Text(L10n.tr('result_process_log'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
                if (_result!['traceback'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _result!['traceback'].toString(),
                    style:
                        const TextStyle(fontSize: 12, color: Colors.redAccent),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    if (widget.mode == AILabMode.objectDetection) {
      final result = _result!;
      final timings = Map<String, dynamic>.from(result['timings'] ?? {});
      final detections =
          List<Map<String, dynamic>>.from(result['detection_details'] ?? []);
      final primaryMode = (result['primary_mode'] ?? '').toString();
      final primaryLabel = (result['primary_label'] ?? '').toString();
      final primaryDistance = result['primary_distance_cm'];
      final bestMatch = (result['best_match'] ?? '').toString();
      final emotion =
          (result['primary_emotion'] ?? result['emotion_label'] ?? '')
              .toString()
              .trim();
      final processedImageUrl = result['processed_image_url']?.toString();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(L10n.tr('result_original'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Image.file(widget.imageFile, height: 180, fit: BoxFit.cover),
              const SizedBox(height: 12),
              Text(L10n.tr('result_processed'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
              Text(L10n.tr('result_objects'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(detections.isEmpty
                  ? L10n.tr('result_none')
                  : detections
                      .map((d) =>
                          '${L10n.isArabic ? _arLabel(d['label'].toString()) : d['label']} - ${d['distance_cm'] ?? 'unknown'} cm')
                      .join('\n')),
              const SizedBox(height: 8),
              Text('Primary: $primaryMode'),
              if (primaryLabel.isNotEmpty) Text('Primary label: $primaryLabel'),
              if (primaryDistance != null)
                Text('Primary distance: $primaryDistance cm'),
              if (bestMatch.isNotEmpty && bestMatch.toLowerCase() != 'unknown')
                Text('Recognized person: $bestMatch'),
              if (emotion.isNotEmpty)
                Text(L10n.isArabic
                    ? 'المشاعر: ${_arEmotion(emotion)}'
                    : 'Emotion: $emotion'),
              if (result['midas_distance_cm'] != null) ...[
                const SizedBox(height: 8),
                Text(L10n.isArabic
                    ? 'مسافة MiDaS: ${result['midas_distance_cm']} سم'
                    : 'MiDaS Distance: ${result['midas_distance_cm']} cm'),
                Text(L10n.isArabic
                    ? 'شدة MiDaS: ${result['midas_severity'] ?? 'unknown'}'
                    : 'MiDaS Severity: ${result['midas_severity'] ?? 'unknown'}'),
              ],
              if (result['emergency_triggered'] == true) ...[
                const SizedBox(height: 8),
                Text(
                  L10n.isArabic
                      ? 'تم إرسال تنبيه طوارئ لولي الأمر'
                      : 'Emergency alert sent to parents',
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: 8),
              Text(L10n.tr('result_performance'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ...timings.entries
                  .map((entry) => Text('${entry.key}: ${entry.value}')),
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
            Text(
                'BLIP: ${_result!['blip_caption_sentence'] ?? _result!['blip_caption'] ?? _result!['blipCaption'] ?? ''}'),
            Text(L10n.isArabic
                ? 'وقت BLIP: ${_result!['blip_time'] ?? _result!['blipTime'] ?? ''}'
                : 'BLIP Time: ${_result!['blip_time'] ?? _result!['blipTime'] ?? ''}'),
            const SizedBox(height: 10),
            Text(
                'ViT: ${_result!['vit_caption_sentence'] ?? _result!['vit_caption'] ?? _result!['vitCaption'] ?? ''}'),
            Text(L10n.isArabic
                ? 'وقت ViT: ${_result!['vit_time'] ?? _result!['vitTime'] ?? ''}'
                : 'ViT Time: ${_result!['vit_time'] ?? _result!['vitTime'] ?? ''}'),
            const SizedBox(height: 10),
            Text(
                'Florence: ${_result!['florence_caption_sentence'] ?? _result!['florence_caption'] ?? _result!['florenceCaption'] ?? ''}'),
            Text(L10n.isArabic
                ? 'وقت Florence: ${_result!['florence_time'] ?? _result!['florenceTime'] ?? ''}'
                : 'Florence Time: ${_result!['florence_time'] ?? _result!['florenceTime'] ?? ''}'),
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
        Text(L10n.tr('result_live_steps'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...logs.map(
          (log) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log['title']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
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

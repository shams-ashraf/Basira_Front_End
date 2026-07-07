import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/voice_service.dart';
import '../../services/ai_lab_storage_service.dart';
import '../../l10n.dart';
import 'ai_lab_result_page.dart';
import 'esp32_camera.dart';

class AILabPage extends StatefulWidget {
  const AILabPage({super.key});

  @override
  State<AILabPage> createState() => _AILabPageState();
}

class _AILabPageState extends State<AILabPage> {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _timeFormat = DateFormat('HH:mm:ss');
  bool _voiceStarted = false;

  Future<List<FileSystemEntity>> _loadImages() {
    return AILabStorageService.instance.listChildImages();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_announceAiLab());
  }

  Future<void> _announceAiLab() async {
    if (_voiceStarted) return;
    _voiceStarted = true;
    await VoiceService.instance.init();
    final prompt = L10n.isArabic
        ? 'أنت الآن داخل معمل الذكاء الاصطناعي. اختر صورة أو افتح البث المباشر.'
        : 'You are now in AI Lab. Choose an image or open the live stream.';
    await VoiceService.instance.speakWithRetry(prompt, maxRepeats: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF4FB),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(L10n.tr('ai_lab_title')),
        backgroundColor: const Color(0xFF5B8DEF),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<FileSystemEntity>>(
        future: _loadImages(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final images = snapshot.data ?? [];
          if (images.isEmpty) {
            return Center(child: Text(L10n.tr('ai_lab_no_images')));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final file = images[index] as File;
              final stat = file.statSync();
              final modified = stat.modified;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          file,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('${L10n.tr('ai_lab_capture_date')}: ${_dateFormat.format(modified)}'),
                      Text('${L10n.tr('ai_lab_capture_time')}: ${_timeFormat.format(modified)}'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AILabResultPage(
                                      imageFile: file,
                                      mode: AILabMode.objectDetection,
                                    ),
                                  ),
                                );
                              },
                              child: Text(L10n.tr('ai_lab_object_detect')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const Esp32CameraScreen(initialMode: 'object'),
                                  ),
                                );
                              },
                              child: Text(L10n.tr('ai_lab_object_live')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AILabResultPage(
                                      imageFile: file,
                                      mode: AILabMode.sceneSummary,
                                    ),
                                  ),
                                );
                              },
                              child: Text(L10n.tr('ai_lab_scene_summary')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const Esp32CameraScreen(initialMode: 'scene'),
                                  ),
                                );
                              },
                              child: Text(L10n.tr('ai_lab_scene_live')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/ai_lab_storage_service.dart';
import 'ai_lab_result_page.dart';

class AILabPage extends StatefulWidget {
  const AILabPage({super.key});

  @override
  State<AILabPage> createState() => _AILabPageState();
}

class _AILabPageState extends State<AILabPage> {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _timeFormat = DateFormat('HH:mm:ss');

  Future<List<FileSystemEntity>> _loadImages() {
    return AILabStorageService.instance.listChildImages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF4FB),
      appBar: AppBar(
        title: const Text('AI Lab'),
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
            return const Center(child: Text('No AI evaluation images yet.'));
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
                      Text('Capture Date: ${_dateFormat.format(modified)}'),
                      Text('Capture Time: ${_timeFormat.format(modified)}'),
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
                              child: const Text('Object Detection'),
                            ),
                          ),
                          const SizedBox(width: 12),
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
                              child: const Text('Scene Summary'),
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

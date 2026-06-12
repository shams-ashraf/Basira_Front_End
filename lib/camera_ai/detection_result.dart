class DetectionItem {
  final String label;
  final double confidence;
  final List<int> box;

  DetectionItem({
    required this.label,
    required this.confidence,
    required this.box,
  });

  factory DetectionItem.fromJson(Map<String, dynamic> json) {
    return DetectionItem(
      label: json['label'] ?? 'Unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      box: (json['box'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
    );
  }
}

class DetectionResponse {
  final bool success;
  final List<DetectionItem> detections;
  final String timestamp;
  final double processingTimeMs;
  final String? error;

  DetectionResponse({
    required this.success,
    required this.detections,
    required this.timestamp,
    required this.processingTimeMs,
    this.error,
  });

  factory DetectionResponse.fromJson(Map<String, dynamic> json) {
    var list = json['detections'] as List<dynamic>? ?? [];
    List<DetectionItem> items = list.map((i) => DetectionItem.fromJson(i)).toList();

    return DetectionResponse(
      success: json['success'] ?? false,
      detections: items,
      timestamp: json['timestamp'] ?? '',
      processingTimeMs: (json['processing_time_ms'] as num?)?.toDouble() ?? 0.0,
      error: json['error'],
    );
  }
}

class SceneSummaryResponse {
  final bool success;
  final String summary;
  final String timestamp;
  final double processingTimeMs;
  final String? error;

  SceneSummaryResponse({
    required this.success,
    required this.summary,
    required this.timestamp,
    required this.processingTimeMs,
    this.error,
  });

  factory SceneSummaryResponse.fromJson(Map<String, dynamic> json) {
    return SceneSummaryResponse(
      success: json['success'] ?? false,
      summary: json['summary'] ?? '',
      timestamp: json['timestamp'] ?? '',
      processingTimeMs: (json['processing_time_ms'] as num?)?.toDouble() ?? 0.0,
      error: json['error'],
    );
  }
}

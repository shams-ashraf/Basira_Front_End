class DetectionItem {
  final String label;
  final double confidence;
  final List<int> box;
  final int? midasDistanceCm;
  final String? midasSeverity;

  DetectionItem({
    required this.label,
    required this.confidence,
    required this.box,
    this.midasDistanceCm,
    this.midasSeverity,
  });

  factory DetectionItem.fromJson(Map<String, dynamic> json) {
    final boxValue = json['box'] ?? json['bbox'] ?? const [];
    final distanceValue = json['midas_distance_cm'] ?? json['distance'] ?? json['distance_cm'];
    return DetectionItem(
      label: (json['label'] ?? json['name'] ?? json['class_name'] ?? 'Unknown').toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ??
          (json['score'] as num?)?.toDouble() ??
          0.0,
      box: (boxValue as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? [],
      midasDistanceCm: distanceValue is num ? distanceValue.toInt() : int.tryParse('$distanceValue'),
      midasSeverity: json['midas_severity'] as String?,
    );
  }
}

class DetectionResponse {
  final bool success;
  final List<DetectionItem> detections;
  final String timestamp;
  final double processingTimeMs;
  final String? error;
  final String? alert;

  DetectionResponse({
    required this.success,
    required this.detections,
    required this.timestamp,
    required this.processingTimeMs,
    this.error,
    this.alert,
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
      alert: json['alert'],
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

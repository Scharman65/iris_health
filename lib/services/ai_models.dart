class AiZoneScore {
  final String name;
  final double score;
  final String? note;

  AiZoneScore({
    required this.name,
    required this.score,
    this.note,
  });

  factory AiZoneScore.fromJson(Map<String, dynamic> json) {
    return AiZoneScore(
      name: (json['name'] ?? '').toString(),
      score: (json['score'] is num)
          ? (json['score'] as num).toDouble()
          : double.tryParse(json['score'].toString()) ?? 0.0,
      note: json['note']?.toString(),
    );
  }
}

class AiAnalyzeResponse {
  final String status;
  final String? field;
  final String? filename;
  final String? contentType;
  final int sizeBytes;
  final double quality;
  final List<AiZoneScore> zones;
  final int tookMs;

  AiAnalyzeResponse({
    required this.status,
    this.field,
    this.filename,
    this.contentType,
    required this.sizeBytes,
    required this.quality,
    required this.zones,
    required this.tookMs,
  });

  factory AiAnalyzeResponse.fromJson(Map<String, dynamic> json) {
    final zonesJson = (json['zones'] as List?) ?? const [];
    return AiAnalyzeResponse(
      status: (json['status'] ?? '').toString(),
      field: json['field']?.toString(),
      filename: json['filename']?.toString(),
      contentType: json['content_type']?.toString(),
      sizeBytes: (json['size_bytes'] is num)
          ? (json['size_bytes'] as num).toInt()
          : int.tryParse(json['size_bytes']?.toString() ?? '') ?? 0,
      quality: (json['quality'] is num)
          ? (json['quality'] as num).toDouble()
          : double.tryParse(json['quality']?.toString() ?? '') ?? 0.0,
      zones: zonesJson
          .whereType<Map>()
          .map((m) => AiZoneScore.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      tookMs: (json['took_ms'] is num)
          ? (json['took_ms'] as num).toInt()
          : int.tryParse(json['took_ms']?.toString() ?? '') ?? 0,
    );
  }
}


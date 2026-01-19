import 'dart:convert';

class AiZoneScore {
  final String code;
  final String? title;
  final double score;
  final String? note;

  const AiZoneScore({
    required this.code,
    required this.score,
    this.title,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'score': score,
        'note': note,
      };

  factory AiZoneScore.fromJson(Map<String, dynamic> json) {
    return AiZoneScore(
      code: (json['code'] ?? '').toString(),
      title: json['title']?.toString(),
      score: (json['score'] is num)
          ? (json['score'] as num).toDouble()
          : double.tryParse(json['score']?.toString() ?? '') ?? 0.0,
      note: json['note']?.toString(),
    );
  }
}

class AiResult {
  final String requestId;
  final String modelVersion;
  final DateTime serverTime;

  final List<AiZoneScore> zones;
  final String? summaryText;
  final List<String> warnings;

  const AiResult({
    required this.requestId,
    required this.modelVersion,
    required this.serverTime,
    required this.zones,
    this.summaryText,
    required this.warnings,
  });

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'modelVersion': modelVersion,
        'serverTime': serverTime.toIso8601String(),
        'zones': zones.map((z) => z.toJson()).toList(),
        'summaryText': summaryText,
        'warnings': warnings,
      };

  factory AiResult.fromJson(Map<String, dynamic> json) {
    final zonesJson =
        (json['zones'] is List) ? (json['zones'] as List) : const [];

    final warningsJson =
        (json['warnings'] is List) ? (json['warnings'] as List) : const [];

    return AiResult(
      requestId: (json['requestId'] ?? '').toString(),
      modelVersion: (json['modelVersion'] ?? '').toString(),
      serverTime: DateTime.tryParse(json['serverTime']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      zones: zonesJson
          .whereType<Map>()
          .map((e) => AiZoneScore.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      summaryText: json['summaryText']?.toString(),
      warnings: warningsJson.map((e) => e.toString()).toList(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory AiResult.fromJsonString(String s) =>
      AiResult.fromJson(jsonDecode(s) as Map<String, dynamic>);
}


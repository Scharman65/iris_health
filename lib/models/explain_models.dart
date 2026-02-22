class ExplainBlock {
  final String type;
  final String title;
  final String body;
  final String severity;

  ExplainBlock({
    required this.type,
    required this.title,
    required this.body,
    required this.severity,
  });

  factory ExplainBlock.fromJson(Map<String, dynamic> j) {
    return ExplainBlock(
      type: (j['type'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      severity: (j['severity'] ?? 'info').toString(),
    );
  }
}

class ExplainResponse {
  final String schemaVersion;
  final String generatedAt;
  final String locale;
  final String explanationId;
  final List<ExplainBlock> blocks;
  final Map<String, dynamic> debug;

  ExplainResponse({
    required this.schemaVersion,
    required this.generatedAt,
    required this.locale,
    required this.explanationId,
    required this.blocks,
    required this.debug,
  });

  factory ExplainResponse.fromJson(Map<String, dynamic> j) {
    final blocksRaw = (j['blocks'] is List) ? (j['blocks'] as List) : <dynamic>[];

    return ExplainResponse(
      schemaVersion: (j['schema_version'] ?? '').toString(),
      generatedAt: (j['generated_at'] ?? '').toString(),
      locale: (j['locale'] ?? '').toString(),
      explanationId: (j['explanation_id'] ?? '').toString(),
      blocks: blocksRaw
          .whereType<Map>()
          .map((b) => ExplainBlock.fromJson(Map<String, dynamic>.from(b)))
          .toList(),
      debug: (j['debug'] is Map)
          ? Map<String, dynamic>.from(j['debug'] as Map)
          : <String, dynamic>{},
    );
  }
}

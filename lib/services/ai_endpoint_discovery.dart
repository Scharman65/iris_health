import 'dart:async';

import 'package:http/http.dart' as http;

/// Endpoint discovery for IRIDA AI server over local dev networks.
///
/// Strategy:
///  1) Try lastKnownBaseUrl (if present)
///  2) Try manualCandidateBaseUrl (if present)
///  3) Try common iPhone USB tethering range 172.20.10.1..15
///  4) Try localhost
///
/// We probe /health with short timeout and accept HTTP 200.
class AiEndpointDiscovery {
  const AiEndpointDiscovery();

  static String normalizeBaseUrl(String s) {
    final t = s.trim();
    if (t.isEmpty) return '';
    return t.replaceAll(RegExp(r'/+$'), '');
  }

  static Uri _healthUri(String baseUrl) {
    final b = normalizeBaseUrl(baseUrl);
    return Uri.parse('$b/health');
  }

  Future<bool> probeHealth(
    String baseUrl, {
    Duration timeout = const Duration(milliseconds: 1200),
  }) async {
    final b = normalizeBaseUrl(baseUrl);
    if (b.isEmpty) return false;

    try {
      final r = await http.get(_healthUri(b)).timeout(timeout);
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Returns first reachable baseUrl, or null.
  Future<String?> discover({
    String? lastKnownBaseUrl,
    String? manualCandidateBaseUrl,
    int port = 8010,
    Duration timeout = const Duration(milliseconds: 1200),
  }) async {
    final candidates = <String>[];

    void add(String? v) {
      final n = normalizeBaseUrl(v ?? '');
      if (n.isEmpty) return;
      if (candidates.contains(n)) return;
      candidates.add(n);
    }

    add(lastKnownBaseUrl);
    add(manualCandidateBaseUrl);

    for (int i = 1; i <= 15; i++) {
      add('http://172.20.10.$i:$port');
    }

    add('http://127.0.0.1:$port');
    add('http://localhost:$port');

    for (final c in candidates) {
      final ok = await probeHealth(c, timeout: timeout);
      if (ok) return c;
    }

    return null;
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_models.dart';
import 'ai_endpoint_discovery.dart';

class AiClient {
  static final AiClient instance = AiClient._();

  static const _prefsKey = 'ai_base_url';
  static const _prefsLastOkKey = 'ai_last_ok_base_url';

  final String _defaultBaseUrl = const String.fromEnvironment(
    'AI_BASE_URL',
    defaultValue: 'http://172.20.10.11:8010',
  );

  String _baseUrl = '';

  AiClient._() {
    _baseUrl = _normalize(_defaultBaseUrl);
  }

  String get baseUrl => _baseUrl;

  String _normalize(String s) {
    final t = s.trim();
    if (t.isEmpty) return '';
    return t.replaceAll(RegExp(r'/+$'), '');
  }

  Uri _u(String path) {
    final b = _normalize(_baseUrl);
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$b$p');
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _baseUrl = _normalize(saved);
    } else {
      _baseUrl = _normalize(_defaultBaseUrl);
    }
  }

  Future<void> setBaseUrl(String newBaseUrl) async {
    final n = _normalize(newBaseUrl);
    if (n.isEmpty) {
      throw Exception('baseUrl is empty');
    }
    _baseUrl = n;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _baseUrl);
  }

  Future<void> resetToDefault() async {
    _baseUrl = _normalize(_defaultBaseUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<String?> getLastOkBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_prefsLastOkKey);
    final n = _normalize(v ?? '');
    return n.isEmpty ? null : n;
  }

  Future<void> _setLastOkBaseUrl(String baseUrl) async {
    final n = _normalize(baseUrl);
    if (n.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLastOkKey, n);
  }

  Future<bool> healthWithTimeout(Duration timeout) async {
    try {
      final r = await http.get(_u('/health')).timeout(timeout);
      final ok = r.statusCode == 200;
      if (ok) {
        await _setLastOkBaseUrl(_baseUrl);
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> health() => healthWithTimeout(const Duration(seconds: 5));

  Future<String?> discoverAndSetBaseUrl({
    String? manualCandidateBaseUrl,
    int port = 8010,
    Duration probeTimeout = const Duration(milliseconds: 1200),
  }) async {
    final discovery = const AiEndpointDiscovery();
    final lastOk = await getLastOkBaseUrl();

    final found = await discovery.discover(
      lastKnownBaseUrl: lastOk,
      manualCandidateBaseUrl: manualCandidateBaseUrl,
      port: port,
      timeout: probeTimeout,
    );

    if (found == null) return null;

    await setBaseUrl(found);

    final ok = await healthWithTimeout(const Duration(seconds: 3));
    if (!ok) return null;

    return found;
  }

  Future<AiAnalyzeResponse> analyzeEye({
    required File file,
    required String side,
    required String examId,
    required int age,
    required String gender,
    String locale = 'ru',
  }) async {
    final b = _normalize(_baseUrl);
    if (b.contains('127.0.0.1') || b.contains('localhost')) {
      throw Exception(
        'AI baseUrl points to localhost. On iPhone use Mac LAN IP, e.g. http://172.20.10.11:8010',
      );
    }

    final uri = _u('/analyze-eye');
    final req = http.MultipartRequest('POST', uri);

    req.fields['eye'] = side;
    req.fields['exam_id'] = examId;
    req.fields['age'] = age.toString();
    req.fields['gender'] = gender;
    req.fields['locale'] = locale;
    req.fields['task'] = 'Iridodiagnosis';

    final bytes = await file.readAsBytes();
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: '${examId}_$side.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final streamed = await req.send().timeout(const Duration(seconds: 90));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw Exception('AI error ${streamed.statusCode}: $body');
    }

    final jsonMap = jsonDecode(body) as Map<String, dynamic>;
    await _setLastOkBaseUrl(_baseUrl);
    return AiAnalyzeResponse.fromJson(jsonMap);
  }
}

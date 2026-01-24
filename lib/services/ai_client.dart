import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
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

  void _dbg(String msg) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[AI] $msg');
    }
  }

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
    _dbg('init baseUrl=$_baseUrl');
  }

  Future<void> setBaseUrl(String newBaseUrl) async {
    final n = _normalize(newBaseUrl);
    if (n.isEmpty) {
      throw Exception('baseUrl is empty');
    }
    _baseUrl = n;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _baseUrl);
    _dbg('setBaseUrl -> $_baseUrl');
  }

  Future<void> resetToDefault() async {
    _baseUrl = _normalize(_defaultBaseUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _dbg('resetToDefault -> $_baseUrl');
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
    _dbg('lastOkBaseUrl <- $n');
  }

  Future<bool> healthWithTimeout(Duration timeout) async {
    try {
      final uri = _u('/health');
      final r = await http.get(uri).timeout(timeout);
      final ok = r.statusCode == 200;
      _dbg('GET $uri -> ${r.statusCode} ok=$ok');
      if (ok) {
        await _setLastOkBaseUrl(_baseUrl);
      }
      return ok;
    } catch (e) {
      _dbg('GET /health failed: $e');
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
    final swTotal = Stopwatch()..start();

    final req = http.MultipartRequest('POST', uri);

    req.fields['eye'] = side;
    req.fields['exam_id'] = examId;
    req.fields['age'] = age.toString();
    req.fields['gender'] = gender;
    req.fields['locale'] = locale;
    req.fields['task'] = 'Iridodiagnosis';

    _dbg('POST $uri');
    _dbg('fields=${Map<String, String>.from(req.fields)}');

    final swRead = Stopwatch()..start();
    final bytes = await file.readAsBytes();
    swRead.stop();

    final filename = '${examId}_$side.jpg';
    _dbg('file=${file.path} filename=$filename bytes=${bytes.length} readMs=${swRead.elapsedMilliseconds}');

    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    http.StreamedResponse streamed;
    try {
      final swSend = Stopwatch()..start();
      streamed = await req.send().timeout(const Duration(seconds: 90));
      swSend.stop();
      _dbg('response status=${streamed.statusCode} sendMs=${swSend.elapsedMilliseconds}');
    } catch (e) {
      _dbg('send failed: $e totalMs=${swTotal.elapsedMilliseconds}');
      rethrow;
    }

    final swBody = Stopwatch()..start();
    final body = await streamed.stream.bytesToString();
    swBody.stop();

    final headLen = min(body.length, 4096);
    final head = body.substring(0, headLen);
    _dbg('bodyMs=${swBody.elapsedMilliseconds} bodyLen=${body.length} bodyHead=${jsonEncode(head)}');

    swTotal.stop();

    if (streamed.statusCode != 200) {
      _dbg('AI non-200 status=${streamed.statusCode} totalMs=${swTotal.elapsedMilliseconds}');
      throw Exception('AI error ${streamed.statusCode}: $body');
    }

    try {
      final jsonMap = jsonDecode(body) as Map<String, dynamic>;
      await _setLastOkBaseUrl(_baseUrl);
      _dbg('AI OK totalMs=${swTotal.elapsedMilliseconds}');
      return AiAnalyzeResponse.fromJson(jsonMap);
    } catch (e) {
      _dbg('jsonDecode failed: $e totalMs=${swTotal.elapsedMilliseconds}');
      rethrow;
    }
  }
}

# CONTEXT HANDOFF — IRIDA

## What IRIDA does
- Capture L/R iris photos -> POST /analyze (FastAPI) -> show results + PDF
- request_id + idempotency_key, typed errors, AI Journal (Hive) + screen

## Current blocker (must fix next)
- lib/services/ai_client.dart: AiClient class braces broken; methods ended up outside class
- flutter analyze reports undefined_method for AiClient.init/setBaseUrl/health/analyzePair

## Commands/output

### flutter analyze
Analyzing iris_health...                                        

  error • The method 'init' isn't defined for the type 'AiClient' • lib/main.dart:16:31 • undefined_method
  error • The method 'getLastOkBaseUrl' isn't defined for the type 'AiClient' • lib/screens/ai_settings_screen.dart:34:39 • undefined_method
  error • The method 'setBaseUrl' isn't defined for the type 'AiClient' • lib/screens/ai_settings_screen.dart:54:31 • undefined_method
  error • The method 'healthWithTimeout' isn't defined for the type 'AiClient' • lib/screens/ai_settings_screen.dart:55:42 • undefined_method
  error • The method 'setBaseUrl' isn't defined for the type 'AiClient' • lib/screens/ai_settings_screen.dart:99:31 • undefined_method
  error • The method 'health' isn't defined for the type 'AiClient' • lib/screens/ai_settings_screen.dart:100:42 • undefined_method
  error • The method 'discoverAndSetBaseUrl' isn't defined for the type 'AiClient' • lib/screens/ai_settings_screen.dart:125:45 • undefined_method
  error • The method 'setBaseUrl' isn't defined for the type 'AiClient' • lib/screens/ai_settings_screen.dart:159:29 • undefined_method
  error • The method 'resetToDefault' isn't defined for the type 'AiClient' • lib/screens/ai_settings_screen.dart:168:29 • undefined_method
warning • Unused import: 'package:hive_flutter/hive_flutter.dart' • lib/services/ai_client.dart:8:8 • unused_import
  error • The method '_normalize' isn't defined for the type 'AiClient' • lib/services/ai_client.dart:34:16 • undefined_method
warning • The declaration 'init' isn't referenced • lib/services/ai_client.dart:84:18 • unused_element
warning • The declaration 'resetToDefault' isn't referenced • lib/services/ai_client.dart:106:18 • unused_element
warning • The declaration 'health' isn't referenced • lib/services/ai_client.dart:144:18 • unused_element
warning • The declaration 'discoverAndSetBaseUrl' isn't referenced • lib/services/ai_client.dart:146:21 • unused_element
warning • The declaration 'analyzePair' isn't referenced • lib/services/ai_client.dart:174:34 • unused_element
warning • The declaration 'analyzeEye' isn't referenced • lib/services/ai_client.dart:362:31 • unused_element
  error • The method 'health' isn't defined for the type 'AiClient' • lib/services/diagnosis_service.dart:10:36 • undefined_method
  error • The method 'analyzePair' isn't defined for the type 'AiClient' • lib/services/diagnosis_service.dart:23:29 • undefined_method


### ai_client.dart (top area)
     1	import 'dart:async';
     2	import 'dart:convert';
     3	import 'dart:io';
     4	import 'dart:math';
     5	
     6	import 'package:crypto/crypto.dart';
     7	import 'package:flutter/foundation.dart';
     8	import 'package:hive_flutter/hive_flutter.dart';
     9	import 'package:http/http.dart' as http;
    10	import 'package:http_parser/http_parser.dart';
    11	import 'package:shared_preferences/shared_preferences.dart';
    12	import 'package:uuid/uuid.dart';
    13	
    14	import 'ai_endpoint_discovery.dart';
    15	import 'ai_errors.dart';
    16	import 'hive_bootstrap.dart';
    17	import '../models/ai_journal_entry.dart';
    18	import 'ai_models.dart';
    19	
    20	class AiClient {
    21	  static final AiClient instance = AiClient._();
    22	
    23	  static const _prefsKey = 'ai_base_url';
    24	  static const _prefsLastOkKey = 'ai_last_ok_base_url';
    25	
    26	  final String _defaultBaseUrl = const String.fromEnvironment(
    27	    'AI_BASE_URL',
    28	    defaultValue: 'http://172.20.10.11:8010',
    29	  );
    30	
    31	  String _baseUrl = '';
    32	
    33	  AiClient._() {
    34	    _baseUrl = _normalize(_defaultBaseUrl);
    35	  }
    36	
    37	  String get baseUrl => _baseUrl;
    38	
    39	  void _dbg(String msg) {
    40	    if (kDebugMode) {
    41	      // ignore: avoid_print
    42	      print('[AI] $msg');
    43	    }
    44	  }
    45	
    46	  Future<void> _journal(AiJournalEntry e) async {
    47	    try {
    48	      final box = await HiveBootstrap.openBox<AiJournalEntry>('ai_journal');
    49	
    50	      await box.add(e);
    51	
    52	      // keep only last 50 entries
    53	      final extra = box.length - 50;
    54	      if (extra > 0) {
    55	        await box.deleteAll(List.generate(extra, (i) => i));
    56	      }
    57	    } catch (_) {
    58	      // Journal must never break AI flow.
    59	    }
    60	
    61	    String _normalize(String s) {
    62	      final t = s.trim();
    63	      if (t.isEmpty) return '';
    64	      return t.replaceAll(RegExp(r'/+$'), '');
    65	    }
    66	
    67	    Uri _u(String path) {
    68	      final b = _normalize(_baseUrl);
    69	      final p = path.startsWith('/') ? path : '/$path';
    70	      return Uri.parse('$b$p');
    71	    }
    72	
    73	    void _assertNotLocalhost() {
    74	      final b = _normalize(_baseUrl);
    75	      if (b.contains('127.0.0.1') || b.contains('localhost')) {
    76	        throw AiError(
    77	          'AI baseUrl points to localhost. On iPhone use Mac LAN IP, e.g. http://172.20.10.11:8010',
    78	        );
    79	      }
    80	    }
    81	
    82	    String _sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();
    83	
    84	    Future<void> init() async {
    85	      final prefs = await SharedPreferences.getInstance();
    86	      final saved = prefs.getString(_prefsKey);
    87	      if (saved != null && saved.trim().isNotEmpty) {
    88	        _baseUrl = _normalize(saved);
    89	      } else {
    90	        _baseUrl = _normalize(_defaultBaseUrl);
    91	      }
    92	      _dbg('init baseUrl=$_baseUrl');
    93	    }
    94	
    95	    Future<void> setBaseUrl(String newBaseUrl) async {
    96	      final n = _normalize(newBaseUrl);
    97	      if (n.isEmpty) {
    98	        throw AiError('baseUrl is empty');
    99	      }
   100	      _baseUrl = n;
   101	      final prefs = await SharedPreferences.getInstance();
   102	      await prefs.setString(_prefsKey, _baseUrl);
   103	      _dbg('setBaseUrl -> $_baseUrl');
   104	    }
   105	
   106	    Future<void> resetToDefault() async {
   107	      _baseUrl = _normalize(_defaultBaseUrl);
   108	      final prefs = await SharedPreferences.getInstance();
   109	      await prefs.remove(_prefsKey);
   110	      _dbg('resetToDefault -> $_baseUrl');
   111	    }
   112	
   113	    Future<String?> getLastOkBaseUrl() async {
   114	      final prefs = await SharedPreferences.getInstance();
   115	      final v = prefs.getString(_prefsLastOkKey);
   116	      final n = _normalize(v ?? '');
   117	      return n.isEmpty ? null : n;
   118	    }
   119	
   120	    Future<void> _setLastOkBaseUrl(String baseUrl) async {
   121	      final n = _normalize(baseUrl);
   122	      if (n.isEmpty) return;
   123	      final prefs = await SharedPreferences.getInstance();
   124	      await prefs.setString(_prefsLastOkKey, n);
   125	      _dbg('lastOkBaseUrl <- $n');
   126	    }
   127	
   128	    Future<bool> healthWithTimeout(Duration timeout) async {
   129	      try {
   130	        final uri = _u('/health');

### ai_client.dart (area around analyzePair)
   130	        final uri = _u('/health');
   131	        final r = await http.get(uri).timeout(timeout);
   132	        final ok = r.statusCode == 200;
   133	        _dbg('GET $uri -> ${r.statusCode} ok=$ok');
   134	        if (ok) {
   135	          await _setLastOkBaseUrl(_baseUrl);
   136	        }
   137	        return ok;
   138	      } catch (e) {
   139	        _dbg('GET /health failed: $e');
   140	        return false;
   141	      }
   142	    }
   143	
   144	    Future<bool> health() => healthWithTimeout(const Duration(seconds: 5));
   145	
   146	    Future<String?> discoverAndSetBaseUrl({
   147	      String? manualCandidateBaseUrl,
   148	      int port = 8010,
   149	      Duration probeTimeout = const Duration(milliseconds: 1200),
   150	    }) async {
   151	      final discovery = const AiEndpointDiscovery();
   152	      final lastOk = await getLastOkBaseUrl();
   153	
   154	      final found = await discovery.discover(
   155	        lastKnownBaseUrl: lastOk,
   156	        manualCandidateBaseUrl: manualCandidateBaseUrl,
   157	        port: port,
   158	        timeout: probeTimeout,
   159	      );
   160	
   161	      if (found == null) return null;
   162	
   163	      await setBaseUrl(found);
   164	
   165	      final ok = await healthWithTimeout(const Duration(seconds: 3));
   166	      if (!ok) return null;
   167	
   168	      return found;
   169	    }
   170	
   171	    /// Canonical: POST /analyze (multipart: file_left, file_right)
   172	    /// Hardening: request_id + idempotency_key
   173	    /// Errors: AiTimeoutError / AiNetworkError / AiServerError / AiParseError
   174	    Future<Map<String, dynamic>> analyzePair({
   175	      required File leftFile,
   176	      required File rightFile,
   177	      required String examId,
   178	      required int age,
   179	      required String gender,
   180	      String locale = 'ru',
   181	    }) async {
   182	      _assertNotLocalhost();
   183	
   184	      final uri = _u('/analyze');
   185	      final swTotal = Stopwatch()..start();
   186	
   187	      final req = http.MultipartRequest('POST', uri);
   188	
   189	      final requestId = const Uuid().v4();
   190	      final startedAt = DateTime.now();
   191	
   192	      final swRead = Stopwatch()..start();
   193	      final leftBytes = await leftFile.readAsBytes();
   194	      final rightBytes = await rightFile.readAsBytes();
   195	      swRead.stop();
   196	
   197	      final leftHash = _sha256Hex(leftBytes);
   198	      final rightHash = _sha256Hex(rightBytes);
   199	      final idempotencyKey =
   200	          _sha256Hex(utf8.encode('$examId|$leftHash|$rightHash'));
   201	
   202	      req.fields['exam_id'] = examId;
   203	      req.fields['age'] = age.toString();
   204	      req.fields['gender'] = gender;
   205	      req.fields['locale'] = locale;
   206	      req.fields['task'] = 'Iridodiagnosis';
   207	
   208	      req.fields['request_id'] = requestId;
   209	      req.fields['idempotency_key'] = idempotencyKey;
   210	
   211	      _dbg('POST $uri');
   212	      _dbg(
   213	        'request_id=${requestId.substring(0, 8)} '
   214	        'idk=${idempotencyKey.substring(0, 12)} '
   215	        'readMs=${swRead.elapsedMilliseconds} '
   216	        'leftBytes=${leftBytes.length} rightBytes=${rightBytes.length}',
   217	      );
   218	
   219	      req.files.add(
   220	        http.MultipartFile.fromBytes(
   221	          'file_left',
   222	          leftBytes,
   223	          filename: '${examId}_left.jpg',
   224	          contentType: MediaType('image', 'jpeg'),
   225	        ),
   226	      );
   227	
   228	      req.files.add(
   229	        http.MultipartFile.fromBytes(
   230	          'file_right',
   231	          rightBytes,
   232	          filename: '${examId}_right.jpg',
   233	          contentType: MediaType('image', 'jpeg'),
   234	        ),
   235	      );
   236	
   237	      http.StreamedResponse streamed;
   238	
   239	      Future<http.StreamedResponse> _sendOnce() async {
   240	        final swSend = Stopwatch()..start();
   241	        final r = await req.send().timeout(const Duration(seconds: 120));
   242	        swSend.stop();
   243	        _dbg('status=${r.statusCode} sendMs=${swSend.elapsedMilliseconds}');
   244	        return r;
   245	      }
   246	
   247	      try {
   248	        streamed = await _sendOnce();
   249	      } on TimeoutException catch (e) {
   250	        _dbg('send timeout: $e totalMs=${swTotal.elapsedMilliseconds} retry=1');
   251	        await Future<void>.delayed(const Duration(milliseconds: 350));
   252	        try {
   253	          streamed = await _sendOnce();
   254	        } on TimeoutException catch (e2) {
   255	          _dbg(
   256	              'send timeout (retry failed): $e2 totalMs=${swTotal.elapsedMilliseconds}');
   257	          throw AiTimeoutError('AI request timed out', cause: e2);
   258	        } on SocketException catch (e2) {
   259	          _dbg(
   260	              'send network error (retry failed): $e2 totalMs=${swTotal.elapsedMilliseconds}');

### ai_client.dart (EOF)
   371	      if (b.contains('127.0.0.1') || b.contains('localhost')) {
   372	        throw AiError(
   373	          'AI baseUrl points to localhost. On iPhone use Mac LAN IP, e.g. http://172.20.10.11:8010',
   374	        );
   375	      }
   376	
   377	      final uri = _u('/analyze-eye');
   378	      final swTotal = Stopwatch()..start();
   379	
   380	      final req = http.MultipartRequest('POST', uri);
   381	
   382	      req.fields['eye'] = side;
   383	      req.fields['exam_id'] = examId;
   384	      req.fields['age'] = age.toString();
   385	      req.fields['gender'] = gender;
   386	      req.fields['locale'] = locale;
   387	      req.fields['task'] = 'Iridodiagnosis';
   388	
   389	      _dbg('POST $uri');
   390	      _dbg('fields=${Map<String, String>.from(req.fields)}');
   391	
   392	      final swRead = Stopwatch()..start();
   393	      final bytes = await file.readAsBytes();
   394	      swRead.stop();
   395	
   396	      final filename = '${examId}_$side.jpg';
   397	      _dbg(
   398	        'file=${file.path} filename=$filename bytes=${bytes.length} readMs=${swRead.elapsedMilliseconds}',
   399	      );
   400	
   401	      req.files.add(
   402	        http.MultipartFile.fromBytes(
   403	          'file',
   404	          bytes,
   405	          filename: filename,
   406	          contentType: MediaType('image', 'jpeg'),
   407	        ),
   408	      );
   409	
   410	      http.StreamedResponse streamed;
   411	      try {
   412	        final swSend = Stopwatch()..start();
   413	        streamed = await req.send().timeout(const Duration(seconds: 90));
   414	        swSend.stop();
   415	        _dbg(
   416	            'response status=${streamed.statusCode} sendMs=${swSend.elapsedMilliseconds}');
   417	      } catch (e) {
   418	        _dbg('send failed: $e totalMs=${swTotal.elapsedMilliseconds}');
   419	        rethrow;
   420	      }
   421	
   422	      final swBody = Stopwatch()..start();
   423	      final body = await streamed.stream.bytesToString();
   424	      swBody.stop();
   425	
   426	      final headLen = min(body.length, 4096);
   427	      final head = body.substring(0, headLen);
   428	      _dbg(
   429	          'bodyMs=${swBody.elapsedMilliseconds} bodyLen=${body.length} bodyHead=${jsonEncode(head)}');
   430	
   431	      swTotal.stop();
   432	
   433	      if (streamed.statusCode != 200) {
   434	        _dbg(
   435	            'AI non-200 status=${streamed.statusCode} totalMs=${swTotal.elapsedMilliseconds}');
   436	        throw Exception('AI error ${streamed.statusCode}: $body');
   437	      }
   438	
   439	      try {
   440	        final jsonMap = jsonDecode(body) as Map<String, dynamic>;
   441	        await _setLastOkBaseUrl(_baseUrl);
   442	        _dbg('AI OK totalMs=${swTotal.elapsedMilliseconds}');
   443	        return AiAnalyzeResponse.fromJson(jsonMap);
   444	      } catch (e) {
   445	        _dbg('jsonDecode failed: $e totalMs=${swTotal.elapsedMilliseconds}');
   446	        rethrow;
   447	      }
   448	    }
   449	  }
   450	}

### git status
On branch feature/explain-ui
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   lib/services/ai_client.dart

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	CONTEXT_HANDOFF_IRIDA_20260222_112721.md
	ops_snapshots/

no changes added to commit (use "git add" and/or "git commit -a")

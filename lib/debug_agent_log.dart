// Temporary agent instrumentation — remove after debug session.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Writes one NDJSON line for debug session 2a231a. No PII.
void agentDebugLog({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, dynamic>? data,
}) {
  final payload = <String, dynamic>{
    'sessionId': '2a231a',
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'location': location,
    'message': message,
    'hypothesisId': hypothesisId,
    if (data != null) 'data': data,
  };
  final line = '${jsonEncode(payload)}\n';
  if (kDebugMode) {
    debugPrint('[agent-debug] $line');
  }

  // Try to send logs to the local ingest server. On Android emulator, host
  // localhost is reachable via 10.0.2.2.
  // #region agent log transport
  () async {
    try {
      final isAndroid = !kIsWeb && Platform.isAndroid;
      final host = isAndroid ? '10.0.2.2' : '127.0.0.1';
      final uri = Uri.parse(
        'http://$host:7713/ingest/9b37bd50-f27a-4fa9-b799-7856329768cb',
      );
      final client = HttpClient();
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.headers.add('X-Debug-Session-Id', '2a231a');
      req.write(jsonEncode(payload));
      await req.close();
      client.close(force: true);
      return;
    } catch (_) {
      // Fall back to file logging below.
    }
  }();
  // #endregion

  // Fall back: file append (works when app runs on host).
  const paths = <String>[r'debug-2a231a.log'];
  for (final path in paths) {
    try {
      File(path).writeAsStringSync(line, mode: FileMode.append, flush: true);
      break;
    } catch (_) {}
  }
}

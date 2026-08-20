import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> saveBytesToFile(
  List<int> bytes,
  String filename, {
  String mimeType = 'application/pdf',
}) async {
  // #region agent log
  try {
    final logFile = File('debug-210858.log');
    final logEntry = <String, dynamic>{
      'sessionId': '210858',
      'runId': 'pre-fix',
      'hypothesisId': 'IO-A',
      'location': 'file_download_helper_io.dart:saveBytesToFile',
      'message': 'saveBytesToFile_called',
      'data': {
        'filename': filename,
        'byteLength': bytes.length,
        'mimeType': mimeType,
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    logFile.writeAsStringSync(
      '${jsonEncode(logEntry)}\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {}
  // #endregion

  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/$filename';
  final file = File(path);
  await file.writeAsBytes(bytes);

  // #region agent log
  try {
    final logFile = File('debug-210858.log');
    final logEntry = <String, dynamic>{
      'sessionId': '210858',
      'runId': 'pre-fix',
      'hypothesisId': 'IO-B',
      'location': 'file_download_helper_io.dart:saveBytesToFile',
      'message': 'saveBytesToFile_completed',
      'data': {
        'path': path,
        'exists': await file.exists(),
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    logFile.writeAsStringSync(
      '${jsonEncode(logEntry)}\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {}
  // #endregion

  return path;
}

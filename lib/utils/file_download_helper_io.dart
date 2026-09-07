import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const _androidDownloadsChannel = MethodChannel('dhealth/downloads');

/// Writes [bytes] to a user-visible location.
///
/// Android: public Downloads via MediaStore (visible in Files / Downloads).
/// iOS/macOS: app Documents (Files app when iTunes/file sharing is enabled).
/// Other desktop: system Downloads folder when available.
Future<String> saveBytesToFile(
  List<int> bytes,
  String filename, {
  String mimeType = 'application/pdf',
}) async {
  if (Platform.isAndroid) {
    final path = await _androidDownloadsChannel.invokeMethod<String>(
      'saveToDownloads',
      {
        'filename': filename,
        'bytes': Uint8List.fromList(bytes),
        'mimeType': mimeType,
      },
    );
    if (path == null || path.isEmpty) {
      throw Exception('Could not save $filename to Downloads');
    }
    return path;
  }

  final dir = await _userVisibleDirectory();
  final path = '${dir.path}/$filename';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}

Future<Directory> _userVisibleDirectory() async {
  if (Platform.isIOS || Platform.isMacOS) {
    return getApplicationDocumentsDirectory();
  }
  return await getDownloadsDirectory() ??
      await getApplicationDocumentsDirectory();
}

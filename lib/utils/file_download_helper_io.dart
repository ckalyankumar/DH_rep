import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> saveBytesToFile(
  List<int> bytes,
  String filename, {
  String mimeType = 'application/pdf',
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/$filename';
  final file = File(path);
  await file.writeAsBytes(bytes);

  return path;
}
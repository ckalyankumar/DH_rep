import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

/// Web implementation: trigger browser download (package:web + dart:js_interop).
Future<String> saveBytesToFile(
  List<int> bytes,
  String filename, {
  String mimeType = 'application/pdf',
}) async {
  final u8 = Uint8List.fromList(bytes);
  final blobParts = [u8.toJS].toJS;
  final blob = Blob(blobParts, BlobPropertyBag(type: mimeType));
  final url = URL.createObjectURL(blob);
  final anchor = document.createElement('a') as HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.style.display = 'none';
  document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
  return 'downloaded:$filename';
}

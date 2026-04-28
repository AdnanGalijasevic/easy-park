import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes PDF bytes to Downloads when the OS allows it, else app documents.
/// Returns filesystem path (VM targets only).
Future<String?> exportStripePdfBytes(List<int> bytes, String filename) async {
  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      final file = File('${downloads.path}/$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    }
  } catch (_) {
    // Scoped storage / permissions: fall through.
  }
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  return file.path;
}

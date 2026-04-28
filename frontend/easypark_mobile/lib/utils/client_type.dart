import 'dart:io';

import 'package:flutter/foundation.dart';

String resolveClientType() {
  if (kIsWeb) {
    return 'mobile';
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return 'desktop';
  }

  return 'mobile';
}

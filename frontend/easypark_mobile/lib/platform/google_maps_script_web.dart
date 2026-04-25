// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

/// Injects the Maps JS API before [GoogleMap] builds. [apiKey] comes from main (env / dart-define).
Future<void> loadGoogleMapsScriptForWeb(String? apiKey) async {
  final key = apiKey?.trim() ?? '';
  if (key.isEmpty) return;
  if (html.document.querySelector('script[data-easypark-google-maps]') != null) {
    return;
  }
  final script = html.ScriptElement()
    ..setAttribute('data-easypark-google-maps', 'true')
    ..src =
        'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeComponent(key)}&loading=async'
    ..async = true;
  final completer = Completer<void>();
  script.onLoad.listen((_) {
    if (!completer.isCompleted) completer.complete();
  });
  script.onError.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('Google Maps script failed to load'));
    }
  });
  html.document.head!.append(script);
  await completer.future;
}

bool isGoogleMapsScriptReady() {
  try {
    final dynamic w = html.window;
    final dynamic google = w.google;
    if (google == null) return false;
    final dynamic maps = google.maps;
    if (maps == null) return false;
    final dynamic mapTypeId = maps.MapTypeId;
    return mapTypeId != null;
  } catch (_) {
    return false;
  }
}

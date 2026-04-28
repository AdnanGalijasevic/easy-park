import 'dart:async';

enum SessionEvent { unauthorized }

class SessionEvents {
  SessionEvents._();

  static final StreamController<SessionEvent> _controller =
      StreamController<SessionEvent>.broadcast();

  static Stream<SessionEvent> get stream => _controller.stream;

  static void emitUnauthorized() {
    if (!_controller.isClosed) {
      _controller.add(SessionEvent.unauthorized);
    }
  }
}


import 'dart:async';

/// Locks the vault after a period of no user interaction. Without
/// this, an unlocked vault stays unlocked indefinitely — which would
/// undermine the whole escalating-lockout design, since none of that
/// matters if someone can just walk up to an already-open session.
class IdleTimer {
  IdleTimer._();
  static final instance = IdleTimer._();

  static const timeout = Duration(minutes: 5);

  Timer? _timer;
  void Function()? onTimeout;

  void reset() {
    _timer?.cancel();
    final callback = onTimeout;
    if (callback != null) {
      _timer = Timer(timeout, callback);
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

import 'package:flutter/foundation.dart';

/// Debug-only logger that wraps [debugPrint] to satisfy `avoid_print` lint.
///
/// All log statements that should only be visible in development can call this
/// helper instead of using `print`. The message is emitted only when
/// `kDebugMode` is true.
void logDebug(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

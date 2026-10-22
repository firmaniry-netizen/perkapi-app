import 'dart:async';

import 'package:flutter/foundation.dart';

/// Membuat GoRouter mengevaluasi ulang redirect saat stream (auth) berubah.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

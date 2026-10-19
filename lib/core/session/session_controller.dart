import 'dart:async';

import 'package:diet_auth/diet_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionProvider = NotifierProvider<SessionController, OidcSession?>(
  SessionController.new,
);

/// 会话只驻内存；过期后不刷新，也不回退到演示登录。
class SessionController extends Notifier<OidcSession?> {
  Timer? _expiry;
  @override
  OidcSession? build() {
    ref.onDispose(() => _expiry?.cancel());
    return null;
  }

  void establish(OidcSession session) {
    _expiry?.cancel();
    if (!session.expiresAt.isAfter(DateTime.now())) {
      state = null;
      return;
    }
    state = session;
    _expiry = Timer(session.expiresAt.difference(DateTime.now()), clear);
  }

  void checkExpiry() {
    final current = state;
    if (current != null && !current.expiresAt.isAfter(DateTime.now())) clear();
  }

  void clear() {
    _expiry?.cancel();
    _expiry = null;
    state = null;
  }
}

bool hasActiveSession(OidcSession? session, {DateTime? now}) =>
    session != null && session.expiresAt.isAfter(now ?? DateTime.now());

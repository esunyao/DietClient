import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'client.dart';

Future<OidcSession> signInWithPopup(OidcClient client) {
  final current = Uri.parse(web.window.location.href);
  final redirect = client.config.redirectUri;
  final local =
      redirect.scheme == 'http' &&
      const ['localhost', '127.0.0.1', '::1', '[::1]'].contains(redirect.host);
  if ((redirect.scheme != 'https' && !local) ||
      redirect.origin != current.origin) {
    return Future.error(
      const OidcFailure(
        'invalid_redirect',
        'Popup callback must use the application origin and HTTPS (or local development HTTP).',
      ),
    );
  }
  // No await before open: browsers require the initiating user gesture.
  final window = web.window.open(
    'about:blank',
    '_blank',
    'popup,width=520,height=720',
  );
  if (window == null) {
    return Future.error(
      const OidcFailure(
        'popup_blocked',
        'The browser blocked the sign-in popup.',
      ),
    );
  }
  // Authorization pages do not need permission to navigate the application.
  window.opener = null;
  return _authorize(client, window, current.origin);
}

Future<OidcSession> _authorize(
  OidcClient client,
  web.Window window,
  String origin,
) async {
  final result = Completer<OidcSession>();
  OidcTransaction? transaction;
  web.BroadcastChannel? channel;
  Timer? timeout;
  bool received = false;
  bool closed = false;
  void Function()? unregister;
  void close() {
    if (closed) return;
    closed = true;
    unregister?.call();
    timeout?.cancel();
    channel?.close();
    window.close();
  }

  void fail(OidcFailure failure) {
    if (!result.isCompleted) result.completeError(failure);
    close();
    final tx = transaction;
    if (tx != null) client.cancel(tx);
  }

  timeout = Timer(
    const Duration(minutes: 5),
    () => fail(const OidcFailure('timeout', 'Authorization timed out.')),
  );
  unregister = client.registerPopupCancellation(
    () => fail(const OidcFailure('cancelled', 'Authorization was cancelled.')),
  );
  // Attach a handler immediately so timeout/dispose errors are observed while
  // discovery is still pending.
  final completion = result.future;
  unawaited(
    completion.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
  );
  unawaited(() async {
    try {
      final tx = await client.beginAuthorization();
      transaction = tx;
      if (closed) {
        client.cancel(tx);
        return;
      }
      channel = web.BroadcastChannel('diet-oidc-${tx.state}');
      client.attachPopupCancellation(tx, () {
        close();
        if (!received && !result.isCompleted) {
          result.completeError(
            const OidcFailure('cancelled', 'Authorization was cancelled.'),
          );
        }
      });
      channel!.onmessage = ((web.MessageEvent event) {
        if (closed || event.origin != origin || event.data == null) return;
        try {
          final raw = event.data.dartify();
          if (raw is! String) return;
          final data = jsonDecode(raw);
          if (data is! Map ||
              data['state'] != tx.state ||
              data['origin'] != origin ||
              data['type'] != 'oidc_callback' ||
              data['callback'] is! String) {
            return;
          }
          // Acknowledge every replay, but exchange only the first response.
          channel!.postMessage(
            jsonEncode({'type': 'oidc_ack', 'state': tx.state}).toJS,
          );
          if (received) return;
          received = true;
          final callback = Uri.parse(data['callback'] as String);
          unawaited(
            client
                .completeAuthorization(tx, callback)
                .then(
                  (session) {
                    if (!result.isCompleted) result.complete(session);
                    close();
                  },
                  onError: (Object error, StackTrace stack) {
                    if (!result.isCompleted) result.completeError(error, stack);
                    close();
                  },
                ),
          );
        } catch (_) {
          fail(
            const OidcFailure(
              'invalid_callback',
              'Popup returned an invalid authorization response.',
            ),
          );
        }
      }).toJS;
      window.location.href = tx.authorizationUri.toString();
    } on OidcFailure catch (error) {
      fail(error);
    } catch (_) {
      fail(
        const OidcFailure(
          'popup_failed',
          'Unable to start browser authorization.',
        ),
      );
    }
  }());
  return completion;
}

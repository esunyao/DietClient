import 'client.dart';

Future<OidcSession> signInWithPopup(OidcClient client) => Future.error(
  const OidcFailure(
    'unsupported_platform',
    'Browser popup authorization is only available on Web.',
  ),
);

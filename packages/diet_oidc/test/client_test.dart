import 'dart:async';
import 'dart:convert';

import 'package:diet_oidc/diet_oidc.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose/jose.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  late JsonWebKey signingKey;
  late JsonWebKey wrongKey;
  setUpAll(() {
    signingKey = JsonWebKey.generate('RS256');
    wrongKey = JsonWebKey.generate('RS256');
  });

  OidcConfig config() => OidcConfig(
    discoveryUri: Uri.parse(
      'https://id.example.test/application/o/demo/.well-known/openid-configuration',
    ),
    clientId: 'public-client',
    redirectUri: Uri.parse('dietclient://oauth/callback'),
  );

  Map<String, dynamic> metadata() => {
    // Global issuer deliberately differs from discovery's application path.
    'issuer': 'https://id.example.test/',
    'authorization_endpoint': 'https://id.example.test/authorize',
    'token_endpoint': 'https://id.example.test/token',
    'jwks_uri': 'https://id.example.test/jwks',
    'response_types_supported': ['code'],
    'id_token_signing_alg_values_supported': ['RS256'],
  };

  http.Response jsonResponse(Map<String, dynamic> json) => http.Response(
    jsonEncode(json),
    200,
    headers: {'content-type': 'application/json'},
  );

  Future<({OidcClient client, OidcTransaction tx, List<http.Request> requests})>
  setup({
    String? badClaim,
    bool badSignature = false,
    bool noExpiresIn = false,
  }) async {
    final requests = <http.Request>[];
    String? nonce;
    final client = OidcClient(
      config(),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url == config().discoveryUri) {
          return jsonResponse(metadata());
        }
        if (request.url.path == '/jwks') {
          return jsonResponse({
            'keys': [
              JsonWebKey.fromCryptoKeys(
                publicKey: signingKey.cryptoKeyPair.publicKey,
              ).toJson(),
            ],
          });
        }
        if (request.url.path == '/token') {
          final body = request.bodyFields;
          expect(body['grant_type'], 'authorization_code');
          expect(body['client_id'], 'public-client');
          expect(body.containsKey('client_secret'), isFalse);
          expect(
            body['code_verifier'],
            matches(RegExp(r'^[A-Za-z0-9._~-]{43,128}$')),
          );
          expect(request.followRedirects, isFalse);
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final claims = <String, dynamic>{
            'iss': 'https://id.example.test/',
            'aud': 'public-client',
            'sub': 'test-user',
            'iat': now,
            'exp': now + 600,
            'nonce': nonce,
          };
          if (badClaim == 'nonce') claims['nonce'] = 'incorrect';
          if (badClaim == 'aud') claims['aud'] = 'another-client';
          if (badClaim == 'exp') claims['exp'] = now - 60;
          final builder = JsonWebSignatureBuilder()
            ..jsonContent = claims
            ..addRecipient(
              badSignature ? wrongKey : signingKey,
              algorithm: 'RS256',
            );
          return jsonResponse({
            'access_token': 'test-access-token',
            'token_type': 'Bearer',
            'id_token': builder.build().toCompactSerialization(),
            if (!noExpiresIn) 'expires_in': 300,
          });
        }
        throw StateError('Unexpected test endpoint');
      }),
    );
    final tx = await client.beginAuthorization();
    nonce = tx.authorizationUri.queryParameters['nonce'];
    addTearDown(client.dispose);
    return (client: client, tx: tx, requests: requests);
  }

  Uri callback(OidcTransaction tx, {String? query}) => tx.redirectUri.replace(
    query: query ?? 'code=test-code&state=${tx.state}',
  );

  test(
    'PKCE S256 authorization is public code flow with unique state and nonce',
    () async {
      final fixture = await setup();
      final parameters = fixture.tx.authorizationUri.queryParameters;
      expect(parameters['response_type'], 'code');
      expect(parameters['code_challenge_method'], 'S256');
      expect(
        parameters['code_challenge'],
        matches(RegExp(r'^[A-Za-z0-9_-]{43}$')),
      );
      expect(parameters['scope']!.split(' '), contains('openid'));
      expect(parameters['nonce'], isNotEmpty);
      final other = await fixture.client.beginAuthorization();
      expect(other.state, isNot(fixture.tx.state));
      expect(
        other.authorizationUri.queryParameters['nonce'],
        isNot(parameters['nonce']),
      );
    },
  );

  test('successful exchange verifies signature and claims and consumes transaction', () async {
    final fixture = await setup();
    final session = await fixture.client.completeAuthorization(
      fixture.tx,
      callback(fixture.tx),
    );
    expect(session.accessToken, 'test-access-token');
    expect(session.expiresAt.isAfter(DateTime.now()), isTrue);
    expect(
      session.expiresAt.difference(DateTime.now()).inSeconds,
      lessThanOrEqualTo(300),
    );
    expect(session.toString(), isNot(contains('test-access-token')));
    await expectLater(
      fixture.client.completeAuthorization(fixture.tx, callback(fixture.tx)),
      throwsA(
        isA<OidcFailure>().having((e) => e.code, 'code', 'invalid_transaction'),
      ),
    );
    expect(fixture.requests.where((r) => r.url.path == '/token'), hasLength(1));
  });

  test(
    'verified ID token expiry bounds session when expires_in is absent',
    () async {
      final fixture = await setup(noExpiresIn: true);
      final session = await fixture.client.completeAuthorization(
        fixture.tx,
        callback(fixture.tx),
      );
      expect(
        session.expiresAt.difference(DateTime.now()).inSeconds,
        inInclusiveRange(590, 600),
      );
    },
  );

  for (final query in [
    'code=x&state=wrong',
    'code=x&code=y',
    'code=x&state=one&state=two',
  ]) {
    test(
      'invalid or duplicate callback parameters do not exchange tokens: $query',
      () async {
        final fixture = await setup();
        await expectLater(
          fixture.client.completeAuthorization(
            fixture.tx,
            callback(fixture.tx, query: query),
          ),
          throwsA(isA<OidcFailure>()),
        );
        expect(fixture.requests.where((r) => r.url.path == '/token'), isEmpty);
      },
    );
  }

  test('callback path must exactly match', () async {
    final fixture = await setup();
    await expectLater(
      fixture.client.completeAuthorization(
        fixture.tx,
        callback(fixture.tx).replace(path: '/wrong'),
      ),
      throwsA(isA<OidcFailure>()),
    );
    expect(fixture.requests.where((r) => r.url.path == '/token'), isEmpty);
  });

  for (final claim in ['nonce', 'aud', 'exp']) {
    test('rejects invalid signed $claim claim', () async {
      final fixture = await setup(badClaim: claim);
      await expectLater(
        fixture.client.completeAuthorization(fixture.tx, callback(fixture.tx)),
        throwsA(
          isA<OidcFailure>().having((e) => e.code, 'code', 'invalid_claims'),
        ),
      );
    });
  }

  test('rejects signature from unknown key', () async {
    final fixture = await setup(badSignature: true);
    await expectLater(
      fixture.client.completeAuthorization(fixture.tx, callback(fixture.tx)),
      throwsA(
        isA<OidcFailure>().having((e) => e.code, 'code', 'invalid_signature'),
      ),
    );
  });

  test(
    'cancelPending invalidates a discovery that has not completed',
    () async {
      final discovery = Completer<http.Response>();
      final client = OidcClient(
        config(),
        httpClient: MockClient((_) => discovery.future),
      );
      addTearDown(client.dispose);
      final pending = client.beginAuthorization();
      final assertion = expectLater(
        pending,
        throwsA(
          isA<OidcFailure>().having((error) => error.code, 'code', 'cancelled'),
        ),
      );
      client.cancelPending();
      await assertion.timeout(const Duration(seconds: 1));
      discovery.complete(jsonResponse(metadata()));
    },
  );

  test(
    'verbose upstream logging never exposes token exchange bodies',
    () async {
      final records = <LogRecord>[];
      final previous = Logger.root.level;
      Logger.root.level = Level.ALL;
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(() async {
        Logger.root.level = previous;
        await subscription.cancel();
      });
      final fixture = await setup();
      final session = await fixture.client.completeAuthorization(
        fixture.tx,
        callback(fixture.tx),
      );
      expect(
        records.map((record) => record.message).join(),
        isNot(contains(session.accessToken)),
      );
      expect(
        records.map((record) => record.message).join(),
        isNot(contains(session.idToken!)),
      );
    },
  );

  test('cancel and provider rejection never send a token request', () async {
    final fixture = await setup();
    fixture.client.cancelPending();
    await expectLater(
      fixture.client.completeAuthorization(fixture.tx, callback(fixture.tx)),
      throwsA(isA<OidcFailure>()),
    );
    final next = await fixture.client.beginAuthorization();
    await expectLater(
      fixture.client.completeAuthorization(
        next,
        callback(next, query: 'error=access_denied&state=${next.state}'),
      ),
      throwsA(
        isA<OidcFailure>().having(
          (e) => e.code,
          'code',
          'authorization_denied',
        ),
      ),
    );
    expect(fixture.requests.where((r) => r.url.path == '/token'), isEmpty);
  });

  test(
    'cross-origin provider endpoints are rejected during discovery',
    () async {
      final client = OidcClient(
        config(),
        httpClient: MockClient(
          (request) async => jsonResponse({
            ...metadata(),
            'token_endpoint': 'https://other.example.test/token',
          }),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        client.beginAuthorization(),
        throwsA(isA<OidcFailure>()),
      );
    },
  );
}

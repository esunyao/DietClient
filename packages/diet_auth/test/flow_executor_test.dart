import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:diet_auth/diet_auth.dart';
import 'package:diet_auth/src/flow_native.dart';
import 'package:test/test.dart';

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody challenge(
  Map<String, dynamic> data, {
  Map<String, List<String>>? headers,
}) => ResponseBody.fromString(
  jsonEncode(data),
  200,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
    ...?headers,
  },
);

AuthentikConfig get config => AuthentikConfig(
  baseUri: Uri.parse('https://auth.example.invalid'),
  providerSlug: 'example',
  authenticationFlowSlug: 'login',
  clientId: 'test-client',
  redirectUri: Uri.parse('diethealth://oauth/callback/'),
  webRedirectUri: Uri.parse('https://app.example.invalid/auth-callback.html'),
);

final authorization = Uri.parse(
  'https://auth.example.invalid/application/o/authorize/?client_id=test-client&state=sample',
);

FlowExecutor executor(FutureOr<ResponseBody> Function(RequestOptions) respond) {
  final dio = Dio()..httpClientAdapter = FakeAdapter(respond);
  final flow = FlowExecutor(config, dio: dio);
  addTearDown(flow.dispose);
  return flow;
}

Future<Uri> run(
  FlowExecutor flow, {
  Future<bool> Function(AuthentikConsent)? onConsent,
}) => flow.run(
  authorizationUri: authorization,
  username: 'example',
  password: ' unchanged ',
  onConsent: onConsent,
);

Matcher failure(String code) =>
    isA<AuthFailure>().having((error) => error.code, 'code', code);

void main() {
  test(
    'POST 302 absorbs multiple cookies and follows relative Location with GET and updated flow id',
    () async {
      var request = 0;
      final flow = executor((options) {
        request++;
        switch (request) {
          case 1:
            expect(options.method, 'GET');
            final query = Uri.splitQueryString(
              options.uri.queryParameters['query']!,
            );
            expect(
              query['next'],
              '/application/o/authorize/?client_id=test-client&state=sample',
            );
            return challenge(
              {'component': 'ak-stage-identification', 'password_fields': true},
              headers: {
                'x-authentik-id': ['first'],
              },
            );
          case 2:
            expect(options.method, 'POST');
            expect(options.data['password'], ' unchanged ');
            expect(options.headers['x-authentik-id'], 'first');
            return ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': ['?query=continued'],
                'x-authentik-id': ['second'],
                'set-cookie': [
                  'authentik_session=session; Path=/; Secure; HttpOnly',
                  'authentik_csrf=csrf; Path=/; Secure',
                ],
              },
            );
          case 3:
            expect(options.method, 'GET');
            expect(options.data, isNull);
            expect(options.uri.queryParameters['query'], 'continued');
            expect(options.headers['x-authentik-id'], 'second');
            final cookie = options.headers['cookie'].toString();
            expect(cookie, contains('authentik_session=session'));
            expect(cookie, contains('authentik_csrf=csrf'));
            return challenge({'component': 'ak-stage-user-login'});
          default:
            expect(options.headers['X-CSRFToken'], 'csrf');
            return challenge({
              'component': 'xak-flow-redirect',
              'to': 'diethealth://oauth/callback/?code=sample&state=sample',
            });
        }
      });
      expect((await run(flow)).scheme, 'diethealth');
      expect(request, 4);
    },
  );

  test('rejects cross-origin redirects before sending request', () async {
    var requests = 0;
    final flow = executor((options) {
      requests++;
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [
            'https://other.example.invalid/application/o/authorize/',
          ],
        },
      );
    });
    await expectLater(run(flow), throwsA(failure('untrusted_redirect')));
    expect(requests, 1);
  });

  test('never replays password POST on 307', () async {
    var requests = 0;
    final flow = executor((options) {
      if (++requests == 1) return challenge({'component': 'ak-stage-password'});
      return ResponseBody.fromString(
        '',
        307,
        headers: {
          'location': ['/api/v3/flows/executor/login/'],
        },
      );
    });
    await expectLater(run(flow), throwsA(failure('unsafe_redirect')));
    expect(requests, 2);
  });

  test('a repeated password challenge never retries credentials', () async {
    var requests = 0;
    final flow = executor((options) {
      requests++;
      return challenge({'component': 'ak-stage-password'});
    });
    await expectLater(run(flow), throwsA(failure('field_error')));
    expect(requests, 2);
  });

  test('HTML responses produce a safe typed failure', () async {
    final flow = executor(
      (options) => ResponseBody.fromString(
        '<html>untrusted response content</html>',
        200,
      ),
    );
    await expectLater(run(flow), throwsA(failure('invalid_response')));
  });

  test('unsupported challenges and field errors use safe errors', () async {
    final unknown = executor(
      (options) =>
          challenge({'component': 'ak-stage-prompt', 'secret': 'not echoed'}),
    );
    await expectLater(run(unknown), throwsA(failure('unsupported_challenge')));
    final invalid = executor(
      (options) => challenge({
        'component': 'ak-stage-password',
        'response_errors': {
          'password': [
            {'string': 'not echoed'},
          ],
        },
      }),
    );
    await expectLater(run(invalid), throwsA(failure('field_error')));
  });

  test(
    'authorization flow entry uses the same cookies and requires explicit consent including token',
    () async {
      var request = 0;
      var prompted = false;
      final flow = executor((options) {
        switch (++request) {
          case 1:
            return challenge({
              'component': 'xak-flow-redirect',
              'to': '/application/o/authorize/?state=sample',
            });
          case 2:
            return ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': ['/if/flow/authorization/?state=sample'],
                'set-cookie': [
                  'authentik_session=consent-session; Path=/; Secure; HttpOnly',
                ],
              },
            );
          case 3:
            expect(options.uri.path, '/api/v3/flows/executor/authorization/');
            expect(
              options.headers['cookie'].toString(),
              contains('consent-session'),
            );
            return challenge({
              'component': 'ak-stage-consent',
              'header_text': 'Example application',
              'permissions': [
                {'id': 'openid', 'name': 'Identity'},
              ],
              'additional_permissions': [
                {'id': 'email', 'name': 'Email'},
              ],
              'token': 'consent-token',
            });
          default:
            expect(prompted, isTrue);
            expect(options.data, {
              'component': 'ak-stage-consent',
              'token': 'consent-token',
            });
            return challenge({
              'component': 'xak-flow-redirect',
              'to': 'diethealth://oauth/callback/?code=sample',
            });
        }
      });
      await run(
        flow,
        onConsent: (consent) async {
          expect(consent.title, 'Example application');
          expect(consent.permissions, ['Identity', 'Email']);
          prompted = true;
          return true;
        },
      );
      expect(request, 4);
    },
  );

  test('consent is not implicitly accepted', () async {
    final flow = executor(
      (options) => challenge({
        'component': 'ak-stage-consent',
        'header_text': 'Example',
        'permissions': [],
      }),
    );
    await expectLater(run(flow), throwsA(failure('consent_required')));
  });

  test(
    'cancel completes while consent is pending and late consent sends no request',
    () async {
      final entered = Completer<void>();
      final consent = Completer<bool>();
      var requests = 0;
      final flow = executor((options) {
        requests++;
        return challenge({
          'component': 'ak-stage-consent',
          'header_text': 'Example',
          'permissions': [],
        });
      });
      final result = run(
        flow,
        onConsent: (_) {
          entered.complete();
          return consent.future;
        },
      );
      final assertion = expectLater(result, throwsA(failure('cancelled')));
      await entered.future;
      flow.cancel();
      await assertion;
      consent.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(requests, 1);
    },
  );
}

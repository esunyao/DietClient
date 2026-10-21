import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:diet_auth/diet_auth.dart';
import 'package:diet_auth/src/auxiliary_stub.dart' as web;
import 'package:diet_oidc/diet_oidc.dart' show OidcIdentity;
import 'package:diet_client/core/config/auth_config.dart';
import 'package:diet_client/core/config/ui_preview_config.dart';
import 'package:diet_client/core/session/session_controller.dart';
import 'package:diet_client/features/auth/application/auxiliary_controller.dart';
import 'package:diet_client/features/auth/application/login_controller.dart';
import 'package:diet_client/features/auth/presentation/screens/login_screen.dart';
import 'package:diet_client/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class Adapter implements HttpClientAdapter {
  Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

final config = AuthentikConfig(
  baseUri: Uri.parse('https://identity.example.org'),
  providerSlug: 'test',
  authenticationFlowSlug: 'login',
  enrollmentFlowSlug: 'enrollment',
  emailVerificationResendFlowSlug: 'resend',
  clientId: 'test',
  redirectUri: Uri.parse('diethealth://oauth/callback/'),
  webRedirectUri: Uri.parse('http://localhost:7357/auth-callback.html'),
);
ResponseBody challenge(
  Map<String, dynamic> json, {
  int status = 200,
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(
  jsonEncode(json),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
    ...headers,
  },
);
const prompt = {
  'component': 'ak-stage-prompt',
  'fields': [
    {'field_key': 'username'},
    {'field_key': 'email'},
    {'field_key': 'password'},
    {'field_key': 'password-repeat'},
    {'field_key': 'nickname'},
  ],
};
AuxiliaryFlowExecutor executor(
  FutureOr<ResponseBody> Function(RequestOptions) respond,
) {
  final flow = AuxiliaryFlowExecutor(
    config,
    dio: Dio()..httpClientAdapter = Adapter(respond),
  );
  addTearDown(flow.dispose);
  return flow;
}

Future<void> register(AuxiliaryFlowExecutor flow) => flow.register(
  username: ' sample ',
  email: ' sample@example.org ',
  password: ' secret pass ',
  confirmPassword: ' secret pass ',
);
Matcher failure(String code) =>
    isA<AuthFailure>().having((e) => e.code, 'code', code);

class FakeAuxiliary implements AuxiliaryGateway {
  final pending = Completer<void>();
  int calls = 0;
  bool cancelled = false;
  bool failDispose = false;
  @override
  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
    String displayName = '',
  }) {
    calls++;
    return pending.future;
  }

  @override
  Future<void> resend(String email) {
    calls++;
    return pending.future;
  }

  @override
  void cancel() => cancelled = true;
  @override
  Future<void> dispose() async {
    if (failDispose) throw StateError('cleanup failed');
  }
}

class MemorySession implements SessionStorage {
  int writes = 0;
  int deletes = 0;
  Completer<void>? gate;
  bool failWrite = false;
  String? value;
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {
    writes++;
    await gate?.future;
    if (failWrite) throw StateError('secure storage unavailable');
    this.value = value;
  }

  @override
  Future<void> delete() async {
    deletes++;
    await gate?.future;
    value = null;
  }
}

class LoginGateway implements AuthGateway {
  @override
  Future<OidcSession> password({
    required String username,
    required String password,
    Future<bool> Function(AuthentikConsent)? onConsent,
  }) async => OidcSession(
    accessToken: 'test',
    tokenType: 'Bearer',
    expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    refreshToken: 'refresh-for-test',
    identity: const OidcIdentity(
      issuer: 'https://identity.example.org',
      subject: 'test-user',
      clientId: 'test',
    ),
  );
  @override
  Future<OidcSession> popup() => password(username: '', password: '');
  @override
  void cancel() {}
  @override
  void dispose() {}
}

class ConsentGateway extends LoginGateway {
  @override
  Future<OidcSession> password({
    required String username,
    required String password,
    Future<bool> Function(AuthentikConsent)? onConsent,
  }) async {
    final accepted = await onConsent!(
      AuthentikConsent(title: 'Consent', permissions: ['profile']),
    );
    if (!accepted) throw const AuthFailure('cancelled', '已取消');
    return super.password(username: username, password: password);
  }
}

void main() {
  testWidgets(
    'cancelled registration completion cannot clear newly entered passwords',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = FakeAuxiliary();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nativeNutritionEnabledProvider.overrideWithValue(true),
            auxiliaryGatewayFactoryProvider.overrideWithValue(() => gateway),
          ],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'sample');
      await tester.enterText(fields.at(2), 'a@example.org');
      await tester.enterText(fields.at(3), 'first-password');
      await tester.enterText(fields.at(4), 'first-password');
      await tester.ensureVisible(find.text('注册并发送验证邮件'));
      await tester.tap(find.text('注册并发送验证邮件'));
      await tester.pump();
      await tester.ensureVisible(find.text('取消提交'));
      await tester.tap(find.text('取消提交'));
      await tester.pump();
      await tester.enterText(fields.at(3), 'next-password');
      await tester.enterText(fields.at(4), 'next-password');
      gateway.pending.complete();
      await tester.pump();
      expect(
        tester.widget<TextFormField>(fields.at(3)).controller!.text,
        'next-password',
      );
      expect(
        tester.widget<TextFormField>(fields.at(4)).controller!.text,
        'next-password',
      );
      expect(find.text('创建账号'), findsWidgets);
    },
  );
  test(
    'declined or failed consent never establishes a session and clears busy',
    () async {
      for (final throws in [false, true]) {
        final storage = MemorySession();
        final container = ProviderContainer(
          overrides: [
            authGatewayProvider.overrideWithValue(ConsentGateway()),
            sessionStorageProvider.overrideWithValue(storage),
          ],
        );
        await container
            .read(loginControllerProvider.notifier)
            .signIn(
              username: 'test',
              password: 'pass',
              popup: false,
              onConsent: (_) async {
                if (throws) throw StateError('dialog unavailable');
                return false;
              },
            );
        expect(container.read(loginControllerProvider).busy, isFalse);
        expect(container.read(sessionProvider), isNull);
        expect(storage.writes, 0);
        if (throws) {
          expect(container.read(loginControllerProvider).error, isNotNull);
        } else {
          expect(container.read(loginControllerProvider).cancelled, isTrue);
        }
        container.dispose();
      }
    },
  );
  test('Web auxiliary stub accepts the same injectable constructor and fails closed', () async {
    final flow = web.AuxiliaryFlowExecutor(config, dio: Dio());
    await expectLater(
      flow.resend('sample@example.org'),
      throwsA(failure('unsupported_platform')),
    );
    await expectLater(
      flow.register(
        username: 'sample',
        email: 'sample@example.org',
        password: 'secret',
        confirmPassword: 'secret',
      ),
      throwsA(failure('unsupported_platform')),
    );
    flow.cancel();
    await flow.dispose();
  });
  test('flow errors stop before any further challenge submission', () async {
    var requests = 0;
    final flow = executor((_) {
      requests++;
      return challenge({
        ...prompt,
        'flow_info': {
          'messages': [
            {'level': 'error', 'message': 'denied'},
          ],
        },
      });
    });
    await expectLater(register(flow), throwsA(failure('email_rejected')));
    expect(requests, 1);
  });
  test('registration acceptance cannot establish a session', () async {
    final gateway = FakeAuxiliary()..pending.complete();
    final storage = MemorySession();
    final container = ProviderContainer(
      overrides: [
        auxiliaryGatewayFactoryProvider.overrideWithValue(() => gateway),
        sessionStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container
          .read(auxiliaryControllerProvider.notifier)
          .register(
            username: 'test',
            email: 'a@example.org',
            password: 'secret',
            confirmPassword: 'secret',
          ),
      isTrue,
    );
    expect(container.read(sessionProvider), isNull);
    expect(storage.writes, 0);
  });
  test(
    'gateway creation failure and cleanup failure leave usable state',
    () async {
      final gateway = FakeAuxiliary()..failDispose = true;
      var creations = 0;
      final container = ProviderContainer(
        overrides: [
          auxiliaryGatewayFactoryProvider.overrideWithValue(() {
            if (creations++ == 0) throw StateError('initialization failed');
            return gateway;
          }),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(auxiliaryControllerProvider.notifier);
      expect(await controller.resend('a@example.org'), isFalse);
      expect(container.read(auxiliaryControllerProvider).busy, isFalse);
      gateway.pending.complete();
      expect(await controller.resend('a@example.org'), isTrue);
      expect(container.read(auxiliaryControllerProvider).cooldown, 60);
    },
  );
  test('remember login waits for secure write; write failure is visible without losing current session', () async {
    for (final fails in [false, true]) {
      final storage = MemorySession()
        ..gate = Completer<void>()
        ..failWrite = fails;
      final container = ProviderContainer(
        overrides: [
          authGatewayProvider.overrideWithValue(LoginGateway()),
          sessionStorageProvider.overrideWithValue(storage),
        ],
      );
      final result = container
          .read(loginControllerProvider.notifier)
          .signIn(
            username: 'test',
            password: 'pass',
            popup: false,
            rememberMe: true,
          );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(loginControllerProvider).busy, isTrue);
      expect(storage.writes, 1);
      storage.gate!.complete();
      await result;
      expect(container.read(loginControllerProvider).busy, isFalse);
      expect(container.read(sessionProvider), isNotNull);
      if (fails) {
        expect(container.read(sessionNoticeProvider), contains('无法记住登录'));
        expect(storage.value, isNull);
      } else {
        final stored = jsonDecode(storage.value!) as Map;
        expect(stored['refreshToken'], 'refresh-for-test');
        expect(stored.containsKey('accessToken'), isFalse);
        expect(stored.containsKey('password'), isFalse);
      }
      container.dispose();
    }
  });
  test('registration posts mapped fields, preserves password, cookies and CSRF; only email stage confirms', () async {
    var requests = 0;
    final flow = executor((options) {
      requests++;
      expect(options.followRedirects, isFalse);
      expect(
        options.path,
        'https://identity.example.org/api/v3/flows/executor/enrollment/',
      );
      if (requests == 1) {
        return challenge(
          prompt,
          headers: {
            'set-cookie': [
              'authentik_csrf=sample; Path=/; Secure',
              'authentik_session=sample; Path=/; Secure',
            ],
            'x-authentik-id': ['flow-test'],
          },
        );
      }
      expect(options.method, 'POST');
      expect(options.headers['X-CSRFToken'], 'sample');
      expect(options.headers['x-authentik-id'], 'flow-test');
      expect(
        options.headers['cookie'].toString(),
        contains('authentik_session'),
      );
      expect(options.data, containsPair('username', 'sample'));
      expect(options.data, containsPair('password', ' secret pass '));
      expect(options.data, containsPair('password-repeat', ' secret pass '));
      expect(options.data, containsPair('nickname', 'sample'));
      return challenge({'component': 'ak-stage-email'});
    });
    await register(flow);
    expect(requests, 2);
    await expectLater(register(flow), throwsA(failure('busy')));
  });
  test(
    'field errors including email-sent never become email success',
    () async {
      final flow = executor(
        (_) => challenge({
          'component': 'ak-stage-email',
          'response_errors': {
            'email': [
              {'string': 'email-sent', 'code': 'email-sent'},
            ],
          },
        }),
      );
      await expectLater(
        register(flow),
        throwsA(
          isA<AuthFieldFailure>().having(
            (e) => e.fields['email'],
            'email',
            'email-sent',
          ),
        ),
      );
    },
  );
  test('redirect, unknown, invalid responses, flow error and no progress fail closed', () async {
    for (final data in [
      {'component': 'xak-flow-redirect', 'to': '/done'},
      {'component': 'ak-stage-captcha'},
      {'component': 'ak-stage-email', 'response_errors': []},
      {
        'component': 'ak-stage-email',
        'flow_info': {
          'messages': [
            {'level': 'error', 'message': 'rate limited'},
          ],
        },
      },
    ]) {
      await expectLater(
        register(executor((_) => challenge(data))),
        throwsA(isA<AuthFailure>()),
      );
    }
    await expectLater(
      register(
        executor(
          (_) => challenge({'component': 'ak-stage-email'}, status: 302),
        ),
      ),
      throwsA(failure('unexpected_redirect')),
    );
    await expectLater(
      register(executor((_) => challenge(prompt))),
      throwsA(failure('no_progress')),
    );
    await expectLater(
      register(
        executor(
          (_) => challenge({'component': 'ak-stage-email'}, status: 500),
        ),
      ),
      throwsA(failure('http_error')),
    );
  });
  test(
    'cancelled transport and uncertain network do not confirm registration',
    () async {
      final response = Completer<ResponseBody>();
      final flow = executor((_) => response.future);
      final result = register(flow);
      final assertion = expectLater(result, throwsA(failure('cancelled')));
      await Future<void>.delayed(Duration.zero);
      flow.cancel();
      response.complete(challenge({'component': 'ak-stage-email'}));
      await assertion;
      final network = executor(
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(
        register(network),
        throwsA(failure('network_uncertain')),
      );
    },
  );
  test('missing auxiliary slugs never block login configuration', () {
    final value = AppAuthConfig.fromValues({
      'AUTHENTIK_BASE_URL': 'https://identity.example.org',
      'AUTHENTIK_PROVIDER_SLUG': 'test',
      'AUTHENTIK_AUTHENTICATION_FLOW_SLUG': 'login',
      'AUTHENTIK_CLIENT_ID': 'test',
      'AUTHENTIK_REDIRECT_URI': 'diethealth://oauth/callback/',
      'AUTHENTIK_WEB_REDIRECT_URI': 'http://localhost:7357/auth-callback.html',
      'AUTHENTIK_SCOPES': 'openid',
    });
    expect(value.isReady, isTrue);
    expect(value.authentik!.enrollmentFlowSlug, isNull);
  });
  test(
    'duplicate request, cancelled old completion and retry are isolated',
    () async {
      final old = FakeAuxiliary();
      final fresh = FakeAuxiliary();
      var created = 0;
      final container = ProviderContainer(
        overrides: [
          auxiliaryGatewayFactoryProvider.overrideWithValue(
            () => created++ == 0 ? old : fresh,
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(auxiliaryControllerProvider.notifier);
      final first = controller.resend('a@example.org');
      await controller.resend('a@example.org');
      expect(old.calls, 1);
      controller.cancel();
      final second = controller.resend('b@example.org');
      old.pending.complete();
      await first;
      expect(container.read(auxiliaryControllerProvider).busy, isTrue);
      fresh.pending.complete();
      await second;
      expect(
        container.read(auxiliaryControllerProvider).email,
        'b@example.org',
      );
      expect(container.read(auxiliaryControllerProvider).cooldown, 60);
      expect(old.cancelled, isTrue);
    },
  );
  testWidgets(
    'resend cooldown starts after acceptance, retains failed email, expires after 60 seconds',
    (tester) async {
      var attempts = 0;
      final container = ProviderContainer(
        overrides: [
          auxiliaryNowProvider.overrideWithValue(tester.binding.clock.now),
          auxiliaryGatewayFactoryProvider.overrideWithValue(() {
            final gateway = FakeAuxiliary();
            attempts++;
            if (attempts == 1) {
              gateway.pending.completeError(
                const AuthFailure('network_uncertain', '先检查邮箱'),
              );
            } else {
              gateway.pending.complete();
            }
            return gateway;
          }),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(auxiliaryControllerProvider.notifier);
      await controller.resend('a@example.org');
      expect(
        container.read(auxiliaryControllerProvider).email,
        'a@example.org',
      );
      expect(container.read(auxiliaryControllerProvider).cooldown, 0);
      await controller.resend('a@example.org');
      await controller.resend('other@example.org');
      expect(attempts, 2);
      await tester.pump(const Duration(seconds: 59));
      expect(container.read(auxiliaryControllerProvider).cooldown, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(container.read(auxiliaryControllerProvider).cooldown, 0);
    },
  );
  test(
    'login defaults to remember false and awaits secure establishment',
    () async {
      final storage = MemorySession();
      final container = ProviderContainer(
        overrides: [
          authGatewayProvider.overrideWithValue(LoginGateway()),
          sessionStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(loginControllerProvider.notifier)
          .signIn(username: 'test', password: 'pass', popup: false);
      expect(storage.deletes, 1);
      expect(storage.writes, 0);
      expect(container.read(sessionProvider), isNotNull);
      expect(container.read(loginControllerProvider).busy, isFalse);
    },
  );
  testWidgets('native login offers remember login unchecked', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [nativeNutritionEnabledProvider.overrideWithValue(true)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    final checkbox = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile),
    );
    expect(checkbox.value, isFalse);
  });
}

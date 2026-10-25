import 'dart:async';

import 'package:diet_auth/diet_auth.dart';
import 'package:diet_client/app/diet_app.dart';
import 'package:diet_client/app/router.dart';
import 'package:diet_client/core/config/auth_config.dart';
import 'package:diet_client/core/session/session_controller.dart';
import 'package:diet_client/demo/demo_store.dart';
import 'package:diet_client/core/presentation/display_state.dart';
import 'package:diet_client/features/auth/application/login_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const validValues = {
  'AUTHENTIK_BASE_URL': 'https://identity.example.org/',
  'AUTHENTIK_PROVIDER_SLUG': 'test',
  'AUTHENTIK_AUTHENTICATION_FLOW_SLUG': 'test-flow',
  'AUTHENTIK_CLIENT_ID': 'public-test-client',
  'AUTHENTIK_REDIRECT_URI': 'diethealth://oauth/callback/',
  'AUTHENTIK_WEB_REDIRECT_URI': 'http://localhost:7357/auth-callback.html',
  'AUTHENTIK_SCOPES': 'openid email profile',
};

OidcSession session() => OidcSession(
  accessToken: 'test-only',
  tokenType: 'Bearer',
  expiresAt: DateTime.now().add(const Duration(minutes: 5)),
);

class _EmptySessionStorage implements SessionStorage {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> delete() async {}
}

class FakeGateway implements AuthGateway {
  final result = Completer<OidcSession>();
  bool consent = false;
  int calls = 0;
  int cancellations = 0;
  String? submittedPassword;
  @override
  Future<OidcSession> password({
    required String username,
    required String password,
    Future<bool> Function(AuthentikConsent)? onConsent,
  }) async {
    calls++;
    submittedPassword = password;
    if (consent &&
        !await onConsent!(
          AuthentikConsent(
            title: 'Test consent',
            permissions: ['Read profile'],
          ),
        )) {
      throw const AuthFailure('cancelled', '已取消');
    }
    return result.future;
  }

  @override
  Future<OidcSession> popup() {
    calls++;
    return result.future;
  }

  @override
  void cancel() {
    cancellations++;
  }

  @override
  void dispose() {}
}

void main() {
  test('configuration rejects missing fields and malformed origin without throwing', () {
    expect(AppAuthConfig.fromValues({}).isReady, isFalse);
    for (final base in [
      'https://identity.example.org/path',
      'https://identity.example.org/?x=1',
      'https://user@identity.example.org/',
      'https://identity.example.org/#fragment',
    ]) {
      final config = AppAuthConfig.fromValues({
        ...validValues,
        'AUTHENTIK_BASE_URL': base,
      });
      expect(config.isReady, isFalse);
      expect(config.issues, isNotEmpty);
    }
    expect(AppAuthConfig.fromValues(validValues).isReady, isTrue);
    for (final key in [
      'AUTHENTIK_REDIRECT_URI',
      'AUTHENTIK_WEB_REDIRECT_URI',
    ]) {
      expect(
        AppAuthConfig.fromValues({
          ...validValues,
          key: '${validValues[key]}?unexpected=1',
        }).isReady,
        isFalse,
      );
    }
    expect(
      AppAuthConfig.fromValues(
        validValues,
        web: true,
        origin: Uri.parse('http://localhost:9000'),
      ).isReady,
      isFalse,
    );
  });

  test(
    'all business routes require a live session; demo auxiliary cannot bypass',
    () {
      for (final path in ['/home', '/meals/new', '/profile', '/unknown']) {
        expect(authenticationRedirect(path, authenticated: false), '/login');
      }
      for (final path in [
        '/login',
        '/register',
        '/verify-email',
        '/email-verified',
      ]) {
        expect(authenticationRedirect(path, authenticated: false), isNull);
      }
      expect(authenticationRedirect('/login', authenticated: true), '/home');
      expect(
        hasActiveSession(
          session(),
          now: DateTime.now().add(const Duration(hours: 1)),
        ),
        isFalse,
      );
    },
  );

  test(
    'request prevents duplicates and preserves password whitespace',
    () async {
      final gateway = FakeGateway();
      final container = ProviderContainer(
        overrides: [authGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      final login = container.read(loginControllerProvider.notifier);
      final pending = login.signIn(
        username: ' user ',
        password: ' password ',
        popup: false,
      );
      await login.signIn(
        username: 'duplicate',
        password: 'second',
        popup: false,
      );
      expect(gateway.calls, 1);
      expect(gateway.submittedPassword, ' password ');
      gateway.result.complete(session());
      await pending;
      expect(hasActiveSession(container.read(sessionProvider)), isTrue);
    },
  );

  test('cancel resolves pending consent and ignores a late approval', () async {
    final gateway = FakeGateway()..consent = true;
    final container = ProviderContainer(
      overrides: [authGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final approval = Completer<bool>();
    final requested = Completer<void>();
    final login = container.read(loginControllerProvider.notifier);
    final pending = login.signIn(
      username: 'user',
      password: 'password',
      popup: false,
      onConsent: (_) {
        requested.complete();
        return approval.future;
      },
    );
    await requested.future;
    login.cancel();
    await pending;
    approval.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(sessionProvider), isNull);
    expect(container.read(loginControllerProvider).cancelled, isTrue);
    expect(gateway.cancellations, 1);
  });

  testWidgets('session expiry timer clears memory state', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(sessionProvider.notifier).establish(session());
    await tester.pump(const Duration(minutes: 6));
    expect(container.read(sessionProvider), isNull);
  });

  testWidgets('login is outside shell and a protected deep link stays gated', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authConfigProvider.overrideWithValue(AppAuthConfig.fromValues({})),
        sessionStorageProvider.overrideWithValue(_EmptySessionStorage()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DietApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('退出当前应用'), findsNothing);
    container.read(appRouterProvider).go('/home');
    await tester.pumpAndSettle();
    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('今天吃了什么'), findsNothing);
    container.read(sessionProvider.notifier).establish(session());
    await tester.pumpAndSettle();
    container
        .read(displayStateProvider.notifier)
        .selectMode(ExperienceMode.institution);
    container.read(displayStateProvider.notifier).setPrivacyHidden(true);
    await tester.pumpAndSettle();
    expect(find.text('个人信息已暂时隐藏'), findsOneWidget);
    container.read(sessionProvider.notifier).clear();
    await tester.pumpAndSettle();
    expect(find.text('欢迎回来'), findsOneWidget);
    expect(container.read(displayStateProvider).privacyHidden, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}

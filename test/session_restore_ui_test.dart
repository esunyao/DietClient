import 'dart:async';

import 'package:diet_client/app/diet_app.dart';
import 'package:diet_client/app/router.dart';
import 'package:diet_client/app/session_restore_screen.dart';
import 'package:diet_client/core/network/api_client.dart';
import 'package:diet_client/core/session/session_controller.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailedStatus extends SessionStatusController {
  @override
  SessionStatus build() => SessionStatus.retryRequired;
}

class _WaitingStorage implements SessionStorage {
  final readResult = Completer<String?>();
  @override
  Future<String?> read() => readResult.future;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> delete() async {}
}

void main() {
  testWidgets('启动恢复完成前不构造业务客户端', (tester) async {
    final storage = _WaitingStorage();
    var businessClients = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          apiDioFactoryProvider.overrideWithValue(() {
            businessClients++;
            throw StateError('不应提前构造业务客户端');
          }),
        ],
        child: const DietApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('正在恢复登录'), findsOneWidget);
    expect(businessClients, 0);
    storage.readResult.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('正在恢复登录'), findsNothing);
    expect(businessClients, 0);
    expect(tester.takeException(), isNull);
  });

  test('恢复登录只返回站内业务目标', () {
    expect(
      sessionRestoredLocation('/meals/9007199254740993?view=detail'),
      '/meals/9007199254740993?view=detail',
    );
    for (final target in [
      null,
      '/login',
      '/register',
      '/session/restore',
      'https://example.invalid/home',
      '//example.invalid/home',
      'relative',
    ]) {
      expect(sessionRestoredLocation(target), '/home');
    }
  });

  testWidgets('短窗口大字的恢复失败页提供重试与重新登录', (tester) async {
    tester.view.physicalSize = const Size(320, 440);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStatusProvider.overrideWith(_FailedStatus.new)],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const SessionRestoreScreen(),
        ),
      ),
    );
    expect(find.text('暂时无法恢复登录'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    await tester.ensureVisible(find.text('重新登录'));
    expect(tester.takeException(), isNull);
  });
}

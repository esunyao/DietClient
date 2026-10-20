import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:diet_client/core/config/api_config.dart';
import 'package:diet_client/core/config/ui_preview_config.dart';
import 'package:diet_client/core/network/api_client.dart';
import 'package:diet_client/core/presentation/account_identity.dart';
import 'package:diet_client/core/session/session_controller.dart';
import 'package:diet_client/features/profile/application/profile_state.dart';
import 'package:diet_client/features/profile/data/profile_api.dart';
import 'package:diet_client/features/profile/presentation/screens/real_profile_screen.dart';
import 'package:diet_client/features/profile/presentation/screens/real_health_form_screen.dart';
import 'package:diet_client/features/profile/presentation/screens/real_edit_profile_screen.dart';
import 'package:diet_client/features/profile/presentation/screens/profile_screen.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:image/image.dart' as image;

import 'dart:typed_data';
import 'dart:async';

import 'profile_api_test.dart' show FakeAdapter, client, session;

class _SavingProfileApi extends ProfileApi {
  _SavingProfileApi(this.current)
    : super(client(FakeAdapter((_) => ResponseBody.fromString('', 500))));
  Json current;
  int gets = 0;
  Completer<Json>? pending;
  @override
  Future<Json> profile() async {
    gets++;
    return current;
  }

  @override
  Future<Json> saveProfile(Json data) async {
    if (pending != null) return await pending!.future;
    return {...current, ...data, 'heightCm': 169.5};
  }
}

Widget _profileSaveHarness(
  ProviderContainer container,
) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    home: Consumer(
      builder: (context, ref, _) => Scaffold(
        body: Column(
          children: [
            Text(
              '服务端身高：${ref.watch(profileProvider).asData?.value['heightCm'] ?? '加载中'}',
            ),
            TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => const RealEditProfileScreen(),
                ),
              ),
              child: const Text('编辑档案'),
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'successful PATCH displays server result without an extra profile GET',
    (tester) async {
      final api = _SavingProfileApi({'userId': 'a', 'heightCm': 164});
      final container = ProviderContainer(
        overrides: [profileApiProvider.overrideWithValue(api)],
      );
      container.read(sessionProvider.notifier).establish(session('a'));
      await tester.pumpWidget(_profileSaveHarness(container));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑档案'));
      await tester.pumpAndSettle();
      final height = find.widgetWithText(TextFormField, '身高（cm）');
      await tester.ensureVisible(height);
      await tester.enterText(height, '168');
      await tester.tap(find.text('保存资料'));
      await tester.pumpAndSettle();
      expect(find.text('服务端身高：169.5'), findsOneWidget);
      expect(api.gets, 1);
      expect(container.read(confirmedProfileProvider)?['heightCm'], 169.5);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
  testWidgets(
    'late profile save cannot populate the replacement session snapshot',
    (tester) async {
      final api = _SavingProfileApi({'userId': 'a', 'heightCm': 164})
        ..pending = Completer<Json>();
      final container = ProviderContainer(
        overrides: [profileApiProvider.overrideWithValue(api)],
      );
      container.read(sessionProvider.notifier).establish(session('a'));
      await tester.pumpWidget(_profileSaveHarness(container));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑档案'));
      await tester.pumpAndSettle();
      final height = find.widgetWithText(TextFormField, '身高（cm）');
      await tester.ensureVisible(height);
      await tester.enterText(height, '168');
      await tester.tap(find.text('保存资料'));
      await tester.pump();
      api.current = {'userId': 'b', 'heightCm': 180};
      container.read(sessionProvider.notifier).establish(session('b'));
      await tester.pumpAndSettle();
      api.pending!.complete({'userId': 'a', 'heightCm': 169.5});
      await tester.pumpAndSettle();
      expect(container.read(confirmedProfileProvider), isNull);
      expect((await container.read(profileProvider.future))['userId'], 'b');
      expect((await container.read(profileProvider.future))['heightCm'], 180);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
  testWidgets(
    'crop library produces square bytes and cancellation returns no image',
    (tester) async {
      final bytes = Uint8List.fromList(
        image.encodePng(image.Image(width: 80, height: 40)),
      );
      Uint8List? result;
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showSquareImageCrop(context, bytes);
                  completed = true;
                },
                child: const Text('打开裁剪'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开裁剪'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('使用此裁剪'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(result, isNotNull);
      final decoded = image.decodeImage(result!)!;
      expect(decoded.width, decoded.height);
      completed = false;
      result = null;
      await tester.tap(find.text('打开裁剪'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'real profile preserves compact identity shortcuts and unknown fields without demo data',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          accountIdentityProvider.overrideWith(
            (_) async =>
                const AccountIdentity(name: '真实姓名', email: 'real@test'),
          ),
          profileProvider.overrideWith((_) async => <String, dynamic>{}),
          healthRecordsProvider.overrideWith((_, _) async => <Json>[]),
          consentsProvider.overrideWith((_) async => <Json>[]),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: RealProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('真实姓名'), findsOneWidget);
      expect(find.text('林知夏'), findsNothing);
      expect(find.text('设计样例 · 演示数据'), findsNothing);
      expect(find.text('我的报告'), findsOneWidget);
      expect(find.text('饮食历史'), findsOneWidget);
      expect(find.textContaining('0 cm'), findsNothing);
      expect(find.text('当前账户'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
  testWidgets('preview profile never reads real API providers', (tester) async {
    final container = ProviderContainer(
      overrides: [
        uiPreviewProvider.overrideWithValue(true),
        apiClientProvider.overrideWith(
          (_) => throw StateError('network forbidden'),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('演示身份'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  testWidgets(
    'invalid API config is displayed as retry state and never throws from page',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          apiConfigProvider.overrideWith(
            (_) => ApiConfig('https://api.example.invalid/'),
          ),
        ],
      );
      container.read(sessionProvider.notifier).establish(session('test'));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: RealEditProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('重新加载'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
  testWidgets(
    'profile form keeps input and visible failure in narrow short keyboard viewport with large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 560);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final adapter = FakeAdapter((_) => ResponseBody.fromString('', 500));
      final container = ProviderContainer(
        overrides: [
          profileApiProvider.overrideWithValue(ProfileApi(client(adapter))),
          profileProvider.overrideWith(
            (_) async => <String, dynamic>{
              'userId': 'test-user',
              'birthDate': '1994-04-18',
              'gender': 'female',
              'heightCm': 164,
              'activityLevel': 'light',
              'dailyWaterTargetMl': 1600,
            },
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.6),
                viewInsets: const EdgeInsets.only(bottom: 180),
              ),
              child: child!,
            ),
            home: const RealEditProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('设计样例 · 演示数据'), findsNothing);
      final height = find.widgetWithText(TextFormField, '身高（cm）');
      await tester.ensureVisible(height);
      await tester.enterText(height, '168');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('保存资料'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('保存资料'));
      await tester.pumpAndSettle();
      expect(adapter.requests, hasLength(1));
      await tester.scrollUntilVisible(
        find.text('保存失败，输入已保留，请重试。'),
        -80,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('保存失败，输入已保留，请重试。').hitTestable(), findsOneWidget);
      expect(tester.widget<TextFormField>(height).controller!.text, '168');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
  testWidgets(
    'measurement save failure retains entered values and hides API codes',
    (tester) async {
      final adapter = FakeAdapter((_) => ResponseBody.fromString('', 500));
      final api = ProfileApi(client(adapter));
      final container = ProviderContainer(
        overrides: [profileApiProvider.overrideWithValue(api)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: RealHealthFormScreen(kind: 'measurement'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final weight = find.widgetWithText(TextFormField, '体重（kg）');
      await tester.ensureVisible(weight);
      await tester.enterText(weight, '58.4');
      await tester.tap(find.text('保存记录'));
      await tester.pumpAndSettle();
      expect(adapter.requests, hasLength(1));
      expect(find.text('58.4'), findsOneWidget);
      expect(find.text('保存失败，输入已保留，请重试。'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
  testWidgets('edit allergy keeps exact ID and hidden original code', (
    tester,
  ) async {
    final adapter = FakeAdapter((_) => ResponseBody.fromString('', 500));
    final api = ProfileApi(client(adapter));
    final container = ProviderContainer(
      overrides: [profileApiProvider.overrideWithValue(api)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: RealHealthFormScreen(
            kind: 'allergy',
            record: {
              'allergyId': '2086475596958904300',
              'allergenCode': 'original_code',
              'allergenName': '花生',
              'active': true,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('original_code'), findsNothing);
    await tester.tap(find.text('保存记录'));
    await tester.pumpAndSettle();
    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.uri.path, endsWith('/2086475596958904300'));
    expect(
      (adapter.requests.single.data as Json)['allergenCode'],
      'original_code',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}

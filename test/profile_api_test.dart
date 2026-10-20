import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:diet_auth/diet_auth.dart';
import 'package:diet_client/core/config/api_config.dart';
import 'package:diet_client/core/config/ui_preview_config.dart';
import 'package:diet_client/core/network/api_client.dart';
import 'package:diet_client/core/network/lossless_json.dart';
import 'package:diet_client/core/session/session_controller.dart';
import 'package:diet_client/core/presentation/account_identity.dart';
import 'package:diet_client/features/profile/application/profile_state.dart';
import 'package:diet_client/features/profile/data/profile_api.dart';
import 'package:diet_client/features/profile/data/health_fields.dart';
import 'package:diet_client/features/profile/data/avatar_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final FutureOr<ResponseBody> Function(RequestOptions) handler;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody envelope(Object? data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode({'code': 200, 'data': data}),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
OidcSession session(String token) => OidcSession(
  accessToken: token,
  tokenType: 'Bearer',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
);
ApiClient client(
  FakeAdapter adapter, {
  bool Function()? current,
  void Function()? unauthorized,
}) => ApiClient(
  config: ApiConfig('https://api.test/'),
  session: session('secret-test'),
  isCurrent: current ?? () => true,
  onUnauthorized: unauthorized ?? () {},
  dio: Dio()..httpClientAdapter = adapter,
);

void main() {
  test('ID tokenizer preserves all five IDs and consent without touching text or decimals', () {
    const raw =
        r'{"measurementId":2086475596958904300,"goalId":2086475596958904301,"allergyId":2086475596958904302,"conditionId":2086475596958904303,"restrictionId":2086475596958904304,"consentId":2086475596958904305,"weightKg":58.42,"notes":"escaped \"consentId\":2086475596958904300","decimal":{"consentId":1.25}}';
    final value = decodeApiJson(raw) as Json;
    expect(value['measurementId'], '2086475596958904300');
    expect(value['consentId'], '2086475596958904305');
    expect(value['weightKg'], 58.42);
    expect(value['notes'], 'escaped "consentId":2086475596958904300');
    expect((value['decimal'] as Json)['consentId'], 1.25);
  });
  test('reject invalid config and arbitrary bearer destinations', () async {
    for (final uri in [
      '',
      'https://api.example.invalid/',
      'https://u:p@api.test/',
      'http://remote.test/',
    ]) {
      expect(() => ApiConfig(uri), throwsFormatException);
    }
    final adapter = FakeAdapter((_) => envelope(null));
    final api = client(adapter);
    await expectLater(
      api.request('https://evil.test/v1/users/self'),
      throwsA(isA<ApiFailure>()),
    );
    await expectLater(
      api.request('v1/users/self/profile?url=evil'),
      throwsA(isA<ApiFailure>()),
    );
    expect(adapter.requests, isEmpty);
  });
  test('five categories create update delete preserve exact string IDs; profile uses PATCH', () async {
    final adapter = FakeAdapter((_) => envelope(<String, dynamic>{}));
    final api = ProfileApi(client(adapter));
    for (final kind in healthPaths.keys) {
      await api.save(kind, {'notes': 'test'});
      await api.save(kind, {'notes': 'edit'}, id: '2086475596958904300');
      await api.remove(kind, '2086475596958904300');
      final requests = adapter.requests.sublist(adapter.requests.length - 3);
      expect(requests.map((r) => r.method), ['POST', 'PATCH', 'DELETE']);
      expect(requests.last.uri.path, endsWith('/2086475596958904300'));
    }
    await api.saveProfile({'gender': 'unknown', 'dailyWaterTargetMl': 0});
    expect(adapter.requests.last.method, 'PATCH');
    for (final r in adapter.requests) {
      expect(r.headers['Authorization'], 'Bearer secret-test');
      expect(r.followRedirects, isFalse);
      expect(r.responseType, ResponseType.plain);
    }
  });
  test(
    'avatar uploads raw bytes without auth then confirms JSON string',
    () async {
      final order = <String>[];
      final adapter = FakeAdapter((r) {
        order.add(r.uri.path);
        return envelope(
          r.uri.path.endsWith('/presign')
              ? {
                  'uploadUrl': 'https://storage.test/key?signature=test',
                  'objectKey': 'key',
                  'expiresIn': 300,
                }
              : {'avatarUrl': 'https://storage.test/avatar'},
        );
      });
      final upload = FakeAdapter((r) {
        order.add('PUT');
        expect(r.method, 'PUT');
        expect(r.headers.containsKey('Authorization'), isFalse);
        expect(r.headers.containsKey('Cookie'), isFalse);
        expect(r.followRedirects, isFalse);
        expect(r.data, isA<Uint8List>());
        return ResponseBody.fromString('', 200);
      });
      final api = ProfileApi(
        client(adapter),
        uploadClient: Dio()..httpClientAdapter = upload,
      );
      expect(
        await api.uploadAvatar(
          Uint8List.fromList([1, 2, 3]),
          (_, _) {},
          CancelToken(),
        ),
        'https://storage.test/avatar',
      );
      expect(order, [
        '/v1/files/avatar/presign',
        'PUT',
        '/v1/files/avatar/confirm',
      ]);
      expect(adapter.requests.last.data, jsonEncode('key'));
    },
  );
  test('failed avatar PUT never confirms and can retry', () async {
    final adapter = FakeAdapter(
      (_) => envelope({
        'uploadUrl': 'https://storage.test/key',
        'objectKey': 'key',
      }),
    );
    final upload = FakeAdapter((_) => ResponseBody.fromString('', 500));
    final api = ProfileApi(
      client(adapter),
      uploadClient: Dio()..httpClientAdapter = upload,
    );
    await expectLater(
      api.uploadAvatar(Uint8List(1), (_, _) {}, CancelToken()),
      throwsA(isA<ApiFailure>()),
    );
    expect(adapter.requests.length, 1);
  });
  test(
    'no session and Web preview never construct network config or transport',
    () async {
      for (final preview in [false, true]) {
        final container = ProviderContainer(
          overrides: [
            uiPreviewProvider.overrideWithValue(preview),
            apiConfigProvider.overrideWith(
              (_) => throw StateError('must not construct'),
            ),
          ],
        );
        if (preview) {
          container.read(sessionProvider.notifier).establish(session('test'));
        }
        expect(container.read(apiClientProvider), isNull);
        expect(await container.read(profileProvider.future), isEmpty);
        container.dispose();
      }
    },
  );
  test('actual provider session replacement discards in-flight results and late 401', () async {
    final pending = Completer<ResponseBody>();
    final adapter = FakeAdapter((_) => pending.future);
    final container = ProviderContainer(
      overrides: [
        apiConfigProvider.overrideWithValue(ApiConfig('https://api.test/')),
        apiDioFactoryProvider.overrideWithValue(
          () => Dio()..httpClientAdapter = adapter,
        ),
      ],
    );
    final a = session('a'), b = session('b');
    container.read(sessionProvider.notifier).establish(a);
    final api = container.read(apiClientProvider)!;
    final future = api.request('v1/users/self');
    final assertion = expectLater(future, throwsA(isA<ApiFailure>()));
    await Future<void>.delayed(Duration.zero);
    container.read(sessionProvider.notifier).establish(b);
    container.read(apiClientProvider);
    pending.complete(ResponseBody.fromString('', 401));
    await assertion;
    expect(container.read(sessionProvider), same(b));
    container.dispose();
  });
  test('avatar missing preserves real identity', () async {
    final adapter = FakeAdapter(
      (r) => r.uri.path.endsWith('/avatar')
          ? ResponseBody.fromString('', 404)
          : envelope({
              'displayName': '真实姓名',
              'email': 'real@test',
              'avatarUrl': '/v1/files/avatar',
            }),
    );
    final container = ProviderContainer(
      overrides: [
        apiConfigProvider.overrideWithValue(ApiConfig('https://api.test/')),
        apiDioFactoryProvider.overrideWithValue(
          () => Dio()..httpClientAdapter = adapter,
        ),
      ],
    );
    container.read(sessionProvider.notifier).establish(session('a'));
    final identity = await container.read(accountIdentityProvider.future);
    expect(identity.name, '真实姓名');
    expect(identity.avatarUrl, isNull);
    container.dispose();
  });
  test(
    'same-time consent uses exact ID and mismatched policy needs review',
    () {
      final records = [
        for (final id in ['2086475596958904300', '2086475596958904301'])
          <String, dynamic>{
            'consentId': id,
            'consentType': 'ai_nutrition_analysis',
            'policyVersion': '1.0',
            'recordedAt': '2026-10-20T00:00:00Z',
            'granted': id.endsWith('0'),
          },
      ];
      expect(consentStatus(records), '未授权');
      records.last['policyVersion'] = '2.0';
      expect(consentStatus(records), '需确认新版本');
    },
  );
  test('health boundaries and date ordering enforce actual contract', () {
    expect(
      validateHealthField(fieldsByKind['measurement']![1], '49'),
      isNotNull,
    );
    expect(validateHealthField(fieldsByKind['measurement']![1], '50'), isNull);
    expect(validateHealthDates('measurement', {}), isNotNull);
    expect(
      validateHealthDates('goal', {
        'startedOn': '2026-10-20',
        'targetDate': '2026-10-19',
      }),
      isNotNull,
    );
    expect(
      validateHealthDates('disease', {
        'diagnosedOn': '2026-10-20',
        'resolvedOn': '2026-10-19',
      }),
      isNotNull,
    );
    expect(
      validateHealthDates('restriction', {
        'startsOn': '2026-10-20',
        'endsOn': '2026-10-19',
      }),
      isNotNull,
    );
  });
  test(
    'avatar validates format size dimensions and emits normalized 512 PNG',
    () {
      expect(
        () => prepareAvatar(Uint8List(5 * 1024 * 1024 + 1)),
        throwsFormatException,
      );
      expect(
        () => prepareAvatar(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      final png = Uint8List.fromList(
        image.encodePng(image.Image(width: 32, height: 32)),
      );
      final result = image.decodePng(finishAvatar(prepareAvatar(png)))!;
      expect(result.width, 512);
      expect(result.height, 512);
    },
  );
}

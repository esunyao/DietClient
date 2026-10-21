import 'dart:async';
import 'dart:convert';

import 'package:diet_client/core/config/api_config.dart';
import 'package:diet_client/core/media/media_coordinator.dart';
import 'package:diet_client/core/network/api_client.dart';
import 'package:diet_client/core/network/lossless_json.dart';
import 'package:diet_client/core/network/object_upload.dart';
import 'package:diet_client/core/nutrition/data/nutri_api.dart';
import 'package:diet_client/core/nutrition/data/nutri_models.dart';
import 'package:diet_client/core/privacy/ai_consent.dart';
import 'package:diet_client/core/session/session_controller.dart';
import 'package:diet_client/features/profile/application/profile_state.dart';
import 'package:diet_oidc/diet_oidc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as image;
import 'package:shared_preferences/shared_preferences.dart';

class Picker extends ImagePicker {
  int recoveryCalls = 0;
  @override
  Future<LostDataResponse> retrieveLostData() async {
    recoveryCalls++;
    return LostDataResponse(files: [XFile('recovered.png')]);
  }
}

class PickerPreferences implements SharedPreferencesAsync {
  final _state = <String, String?>{};
  String? get value => _state['value'];
  set value(String? value) => _state['value'] = value;
  @override
  Future<String?> getString(String key) async => value;
  @override
  Future<void> setString(String key, String value) async {
    this.value = value;
  }

  @override
  Future<void> remove(String key) async {
    value = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryStorage implements SessionStorage {
  String? value;
  bool failWrite = false;
  int writes = 0;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    writes++;
    if (failWrite) throw StateError('storage');
    this.value = value;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class Adapter implements HttpClientAdapter {
  Adapter(this.handler);
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

ResponseBody response(Object? data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode({'code': status, 'data': data}),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
const identity = OidcIdentity(
  issuer: 'https://id.test/',
  subject: 'alice',
  clientId: 'client',
);
OidcSession session(
  String token, {
  String subject = 'alice',
  Duration lifetime = const Duration(hours: 1),
}) => OidcSession(
  accessToken: token,
  tokenType: 'Bearer',
  expiresAt: DateTime.now().add(lifetime),
  refreshToken: 'refresh-$token',
  identity: OidcIdentity(
    issuer: identity.issuer,
    subject: subject,
    clientId: identity.clientId,
  ),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final code in ['invalid_response', 'untrusted_endpoint']) {
    test(
      'refresh $code clears saved credentials instead of retrying validation',
      () async {
        final storage = MemoryStorage();
        final container = ProviderContainer(
          overrides: [
            sessionStorageProvider.overrideWithValue(storage),
            refreshSessionProvider.overrideWithValue(
              (_) async => throw OidcFailure(code, 'test'),
            ),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(sessionProvider.notifier);
        await controller.establish(session('one'), rememberMe: true);
        await expectLater(
          controller.ensureFreshAccessToken(force: true),
          throwsA(isA<OidcFailure>()),
        );
        expect(container.read(sessionProvider), isNull);
        expect(container.read(sessionStatusProvider), SessionStatus.signedOut);
        expect(storage.value, isNull);
      },
    );
  }
  test(
    'valid session without refresh remains usable during its last 30 seconds',
    () async {
      final container = ProviderContainer(
        overrides: [sessionStorageProvider.overrideWithValue(MemoryStorage())],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionProvider.notifier);
      await controller.establish(
        OidcSession(
          accessToken: 'valid',
          tokenType: 'Bearer',
          expiresAt: DateTime.now().add(const Duration(seconds: 10)),
        ),
      );
      expect(await controller.ensureFreshAccessToken(), 'valid');
      expect(container.read(sessionProvider), isNotNull);
      await expectLater(
        controller.ensureFreshAccessToken(force: true),
        throwsA(isA<OidcFailure>()),
      );
      expect(container.read(sessionProvider), isNull);
    },
  );
  test(
    'failed early refresh still transitions at the old token expiry',
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionStorageProvider.overrideWithValue(MemoryStorage()),
          refreshSessionProvider.overrideWithValue(
            (_) async => throw const OidcFailure('network_timeout', 'test'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(sessionProvider.notifier)
          .establish(
            session('old', lifetime: const Duration(milliseconds: 100)),
          );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(
        container.read(sessionStatusProvider),
        SessionStatus.retryRequired,
      );
    },
  );
  test('lost image dispatch is single consumption, purpose-bound, and discarded after account switch', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final picker = Picker(), preferences = PickerPreferences();
    final container = ProviderContainer(
      overrides: [
        sessionStorageProvider.overrideWithValue(MemoryStorage()),
        mediaCoordinatorProvider.overrideWith(
          (ref) =>
              MediaCoordinator(ref, picker: picker, preferences: preferences),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(sessionProvider.notifier);
    await controller.establish(session('alice'));
    preferences.value = jsonEncode({
      'owner': jsonEncode([
        identity.issuer,
        identity.subject,
        identity.clientId,
      ]),
      'purpose': 'meal:draft-one',
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    final media = container.read(mediaCoordinatorProvider);
    expect(await media.recover(purpose: MediaPurpose.avatar), isEmpty);
    expect(picker.recoveryCalls, 1);
    await controller.establish(session('bob', subject: 'bob'));
    expect(
      await media.recover(purpose: MediaPurpose.meal, contextId: 'draft-one'),
      isEmpty,
    );
    expect(picker.recoveryCalls, 1);
  });
  test(
    'unowned lost images are discarded and actual format ignores filename',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final picker = Picker();
      final container = ProviderContainer(
        overrides: [
          sessionStorageProvider.overrideWithValue(MemoryStorage()),
          mediaCoordinatorProvider.overrideWith(
            (ref) => MediaCoordinator(
              ref,
              picker: picker,
              preferences: PickerPreferences(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(sessionProvider.notifier)
          .establish(session('alice'));
      final media = container.read(mediaCoordinatorProvider);
      expect(await media.recover(purpose: MediaPurpose.avatar), isEmpty);
      expect(picker.recoveryCalls, 1);
      final bytes = Uint8List.fromList(
        image.encodePng(image.Image(width: 2, height: 2)),
      );
      final selected = await media.inspect(
        XFile.fromData(bytes, name: 'wrong.jpg'),
        maxBytes: 1024,
        allowedContentTypes: ['image/png'],
      );
      expect(selected.contentType, 'image/png');
      await expectLater(
        media.inspect(
          XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'fake.png'),
          maxBytes: 1024,
          allowedContentTypes: ['image/png'],
        ),
        throwsFormatException,
      );
    },
  );
  test('single flight rotates refresh credentials without replacing API/profile state', () async {
    final storage = MemoryStorage(), pending = Completer<OidcSession>();
    var refreshes = 0;
    final adapter = Adapter((_) => response({}));
    final container = ProviderContainer(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        refreshSessionProvider.overrideWithValue((_) {
          refreshes++;
          return pending.future;
        }),
        apiConfigProvider.overrideWithValue(ApiConfig('https://api.test/')),
        apiDioFactoryProvider.overrideWithValue(
          () => Dio()..httpClientAdapter = adapter,
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(sessionProvider.notifier);
    await controller.establish(session('one'), rememberMe: true);
    final epoch = container.read(sessionEpochProvider),
        client = container.read(apiClientProvider),
        profileApi = container.read(profileApiProvider);
    container.read(confirmedProfileProvider.notifier).accept({
      'heightCm': 170,
    }, epoch);
    final first = controller.ensureFreshAccessToken(force: true),
        second = controller.ensureFreshAccessToken(force: true);
    expect(identical(first, second), true);
    expect(refreshes, 1);
    pending.complete(session('two'));
    expect(await first, 'two');
    expect(await second, 'two');
    expect(container.read(sessionEpochProvider), epoch);
    expect(identical(client, container.read(apiClientProvider)), true);
    expect(identical(profileApi, container.read(profileApiProvider)), true);
    expect(container.read(confirmedProfileProvider)?['heightCm'], 170);
    expect(jsonDecode(storage.value!)['refreshToken'], 'refresh-two');
    expect(storage.value, isNot(contains('accessToken')));
    await controller.clear();
    expect(storage.value, isNull);
  });
  test('remember disabled stores no credentials; valid memory survives storage failure', () async {
    final storage = MemoryStorage()..value = 'old';
    final container = ProviderContainer(
      overrides: [sessionStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final controller = container.read(sessionProvider.notifier);
    await controller.establish(session('one'));
    expect(storage.value, isNull);
    expect(storage.writes, 0);
    storage.failWrite = true;
    await controller.establish(session('two'), rememberMe: true);
    expect(container.read(sessionProvider)?.accessToken, 'two');
    expect(container.read(sessionStatusProvider), SessionStatus.ready);
    expect(container.read(sessionNoticeProvider), contains('无法记住登录'));
    expect(storage.value, isNull);
  });
  test(
    'temporary refresh failure preserves valid login; rejected grant clears it',
    () async {
      var rejected = false;
      final container = ProviderContainer(
        overrides: [
          sessionStorageProvider.overrideWithValue(MemoryStorage()),
          refreshSessionProvider.overrideWithValue((_) async {
            throw OidcFailure(
              rejected ? 'refresh_rejected' : 'network_timeout',
              'test',
            );
          }),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionProvider.notifier);
      await controller.establish(session('one'));
      await expectLater(
        controller.ensureFreshAccessToken(force: true),
        throwsA(isA<OidcFailure>()),
      );
      expect(container.read(sessionStatusProvider), SessionStatus.ready);
      expect(container.read(sessionProvider), isNotNull);
      rejected = true;
      await expectLater(
        controller.ensureFreshAccessToken(force: true),
        throwsA(isA<OidcFailure>()),
      );
      expect(container.read(sessionProvider), isNull);
    },
  );
  test(
    'late refresh cannot resurrect logged out or replaced account',
    () async {
      final pending = Completer<OidcSession>();
      final storage = MemoryStorage();
      final container = ProviderContainer(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          refreshSessionProvider.overrideWithValue((_) => pending.future),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionProvider.notifier);
      await controller.establish(session('one'), rememberMe: true);
      final future = controller.ensureFreshAccessToken(force: true);
      final check = expectLater(future, throwsA(isA<OidcFailure>()));
      await controller.clear();
      await controller.establish(session('bob', subject: 'bob'));
      pending.complete(session('late'));
      await check;
      expect(container.read(sessionProvider)?.identity?.subject, 'bob');
      expect(storage.value, isNull);
    },
  );
  test('restore retries network failure and only activates verified refreshed session', () async {
    final storage = MemoryStorage();
    var networkFails = true;
    final source = ProviderContainer(
      overrides: [sessionStorageProvider.overrideWithValue(storage)],
    );
    await source
        .read(sessionProvider.notifier)
        .establish(session('saved'), rememberMe: true);
    source.dispose();
    final container = ProviderContainer(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        refreshSessionProvider.overrideWithValue((_) async {
          if (networkFails) throw const OidcFailure('network_timeout', 'test');
          return session('restored');
        }),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(sessionProvider.notifier);
    await controller.restore();
    expect(container.read(sessionStatusProvider), SessionStatus.retryRequired);
    expect(hasActiveSession(container.read(sessionProvider)), false);
    networkFails = false;
    await controller.restore();
    expect(container.read(sessionStatusProvider), SessionStatus.ready);
    expect(container.read(sessionProvider)?.accessToken, 'restored');
  });
  test(
    'GET retries 401 once with new bearer; write is never replayed',
    () async {
      var token = 'old', refreshes = 0, unauthorized = 0;
      final adapter = Adapter(
        (options) => options.headers['Authorization'] == 'Bearer old'
            ? response(null, status: 401)
            : response({'ok': true}),
      );
      final api = ApiClient(
        config: ApiConfig('https://api.test/'),
        session: session('old'),
        isCurrent: () => true,
        onUnauthorized: () => unauthorized++,
        dio: Dio()..httpClientAdapter = adapter,
        freshToken: ({bool force = false}) async {
          if (force) {
            refreshes++;
            token = 'new';
          }
          return token;
        },
      );
      addTearDown(api.close);
      expect(await api.request('v1/nutri/capture-policy'), {'ok': true});
      expect(adapter.requests.length, 2);
      expect(refreshes, 1);
      expect(unauthorized, 0);
      token = 'old';
      await expectLater(
        api.request(
          'v1/nutri/capture-sessions',
          method: 'POST',
          data: {},
          headers: {'X-Idempotency-Key': 'test'},
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(adapter.requests.length, 3);
      expect(refreshes, 1);
      expect(unauthorized, 1);
    },
  );
  test(
    'query uses server q key; long IDs and absent nutrients stay exact',
    () async {
      final adapter = Adapter(
        (_) => response({'items': [], 'page': 1, 'pageSize': 20, 'total': 0}),
      );
      final api = ApiClient(
        config: ApiConfig('https://api.test/'),
        session: session('old'),
        isCurrent: () => true,
        onUnauthorized: () {},
        dio: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(api.close);
      final nutri = NutriApi(api);
      addTearDown(nutri.close);
      await nutri.meals((
        dateFrom: '2026-10-01',
        dateTo: '2026-10-21',
        mealType: null,
        keyword: 'rice',
        page: 1,
        pageSize: 20,
      ));
      expect(adapter.requests.single.queryParameters['q'], 'rice');
      final data = decodeApiJson(
        '{"mealId":9223372036854775807,"itemId":9007199254740993,"imageId":9223372036854775806}',
      ) as Map;
      expect(data['mealId'], '9223372036854775807');
      expect(data['itemId'], '9007199254740993');
      expect(data['imageId'], '9223372036854775806');
      expect(nutrientAmount([], 'energy_kcal'), isNull);
    },
  );
  test('object upload preserves required headers without credentials and rejects injection', () async {
    final adapter = Adapter((_) => ResponseBody.fromString('', 200));
    final uploader = ObjectUploader(dio: Dio()..httpClientAdapter = adapter);
    addTearDown(uploader.close);
    await uploader.put(
      url: 'https://objects.test/photo?signature=test',
      bytes: Uint8List.fromList([1, 2]),
      requiredHeaders: {
        'Content-Type': 'image/png',
        'x-upload-check': 'required',
      },
    );
    final request = adapter.requests.single;
    expect(request.headers['x-upload-check'], 'required');
    expect(
      request.headers.keys.map((k) => k.toLowerCase()),
      isNot(contains('authorization')),
    );
    expect(
      request.headers.keys.map((k) => k.toLowerCase()),
      isNot(contains('cookie')),
    );
    expect(request.followRedirects, false);
    await expectLater(
      uploader.put(
        url: 'https://objects.test/photo',
        bytes: Uint8List(0),
        requiredHeaders: {'Authorization': 'injected'},
      ),
      throwsFormatException,
    );
    expect(adapter.requests.length, 1);
  });
  test(
    'latest consent revocation and old policy cannot authorize analysis',
    () {
      final records = [
        {
          'consentType': 'ai_nutrition_analysis',
          'recordedAt': '2026-10-21T00:00:00Z',
          'consentId': '9007199254740992',
          'granted': true,
          'policyVersion': '1.0',
        },
        {
          'consentType': 'ai_nutrition_analysis',
          'recordedAt': '2026-10-21T00:00:00Z',
          'consentId': '9007199254740993',
          'granted': false,
          'policyVersion': '1.0',
        },
      ];
      expect(latestAiConsent(records)?['granted'], false);
    },
  );
}

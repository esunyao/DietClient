import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:diet_client/core/config/api_config.dart';
import 'package:diet_client/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_api_test.dart' show FakeAdapter, client, envelope, session;

const _path = 'v1/users/self';
const _privateMessage = 'secret-token internal database detail';

ResponseBody _business(int code, {int status = 200}) => ResponseBody.fromString(
  jsonEncode({'code': code, 'message': _privateMessage, 'data': null}),
  status,
);

Matcher _failure(String message, {int? status, int? code}) => isA<ApiFailure>()
    .having((e) => e.message, 'safe message', message)
    .having((e) => e.status, 'HTTP status', status)
    .having((e) => e.code, 'business code', code);

void main() {
  const messages = {
    400: '提交内容不符合要求，请检查填写的信息后重试',
    403: '当前账号无权进行此操作，请确认登录账号或联系管理员',
    404: '内容不存在或已被删除，请刷新页面后重试',
    409: '内容状态已变化或记录已存在，请刷新查看后再操作',
    410: '内容已过期，请刷新页面或重新创建',
    413: '提交的文件过大，请选择较小的图片后重试',
    415: '文件格式不受支持，请选择 JPEG、PNG 或 WebP 图片',
    422: '提交内容不符合要求，请检查填写的信息后重试',
    429: '操作过于频繁，请稍后再试',
    500: '服务暂时不可用，请稍后重试',
    503: '服务暂时不可用，请稍后重试',
    504: '服务响应超时，请稍后重试',
  };
  for (final entry in messages.entries) {
    test('HTTP ${entry.key} keeps status with local safe guidance', () async {
      final api = client(FakeAdapter((_) => _business(999, status: entry.key)));
      addTearDown(api.close);
      await expectLater(
        api.request(_path),
        throwsA(_failure(entry.value, status: entry.key)),
      );
    });
    test(
      'business ${entry.key} keeps HTTP and envelope codes separate',
      () async {
        final api = client(FakeAdapter((_) => _business(entry.key)));
        addTearDown(api.close);
        await expectLater(
          api.request(_path),
          throwsA(_failure(entry.value, status: 200, code: entry.key)),
        );
      },
    );
  }

  for (final business in [false, true]) {
    test(
      '401 GET retries once with refreshed token; business=$business',
      () async {
        var token = 'old';
        final adapter = FakeAdapter(
          (r) => r.headers['Authorization'] == 'Bearer old'
              ? (business ? _business(401) : _business(401, status: 401))
              : envelope('ok'),
        );
        var cleared = 0;
        var forced = 0;
        final api = ApiClient(
          config: ApiConfig('https://api.test/'),
          session: session(token),
          isCurrent: () => true,
          onUnauthorized: () => cleared++,
          freshToken: ({bool force = false}) async {
            if (force) {
              forced++;
              token = 'new';
            }
            return token;
          },
          dio: Dio()..httpClientAdapter = adapter,
        );
        addTearDown(api.close);
        expect(await api.request(_path), 'ok');
        expect(adapter.requests.length, 2);
        expect(forced, 1);
        expect(cleared, 0);
      },
    );

    test(
      '401 write is not replayed; rotated successor survives; business=$business',
      () async {
        final adapter = FakeAdapter(
          (_) => business ? _business(401) : _business(401, status: 401),
        );
        var cleared = 0;
        final api = ApiClient(
          config: ApiConfig('https://api.test/'),
          session: session('old'),
          isCurrent: () => true,
          onUnauthorized: () => cleared++,
          currentAccessToken: () => 'new',
          dio: Dio()..httpClientAdapter = adapter,
        );
        addTearDown(api.close);
        await expectLater(
          api.request(_path, method: 'PATCH'),
          throwsA(isA<ApiFailure>()),
        );
        expect(adapter.requests.length, 1);
        expect(cleared, 0);
      },
    );

    test(
      'persistent 401 GET stops after one retry and clears rejected token; business=$business',
      () async {
        final adapter = FakeAdapter(
          (_) => business ? _business(401) : _business(401, status: 401),
        );
        var cleared = 0;
        final api = ApiClient(
          config: ApiConfig('https://api.test/'),
          session: session('old'),
          isCurrent: () => true,
          onUnauthorized: () => cleared++,
          freshToken: ({bool force = false}) async => force ? 'new' : 'old',
          dio: Dio()..httpClientAdapter = adapter,
        );
        addTearDown(api.close);
        await expectLater(api.request(_path), throwsA(isA<ApiFailure>()));
        expect(adapter.requests.length, 2);
        expect(cleared, 1);
      },
    );
  }

  for (final type in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
    DioExceptionType.cancel,
  ]) {
    test('transport $type has safe actionable guidance', () async {
      final api = client(
        FakeAdapter(
          (r) => throw DioException(
            requestOptions: r,
            type: type,
            message: _privateMessage,
          ),
        ),
      );
      addTearDown(api.close);
      final expected = type == DioExceptionType.cancel
          ? '请求已取消'
          : type == DioExceptionType.connectionError
          ? '无法连接服务，请检查网络后重试'
          : '网络请求超时，请检查网络后重试';
      await expectLater(api.request(_path), throwsA(_failure(expected)));
    });
  }

  test('cancelled token avoids network dispatch', () async {
    final adapter = FakeAdapter((_) => envelope('unexpected'));
    final api = client(adapter);
    addTearDown(api.close);
    await expectLater(
      api.request(_path, cancelToken: CancelToken()..cancel(_privateMessage)),
      throwsA(_failure('请求已取消')),
    );
    expect(adapter.requests, isEmpty);
  });

  test(
    'late failure after account switch is discarded without clearing session',
    () async {
      final pending = Completer<ResponseBody>();
      var current = true;
      var cleared = 0;
      final api = client(
        FakeAdapter((_) => pending.future),
        current: () => current,
        unauthorized: () => cleared++,
      );
      addTearDown(api.close);
      final result = api.request(_path);
      final assertion = expectLater(result, throwsA(_failure('会话已更换')));
      await Future<void>.delayed(Duration.zero);
      current = false;
      pending.complete(_business(401, status: 401));
      await assertion;
      expect(cleared, 0);
    },
  );

  test(
    'malformed response and unknown code never expose server text',
    () async {
      for (final body in [
        '<html>$_privateMessage</html>',
        jsonEncode({'code': 98765, 'message': _privateMessage}),
      ]) {
        final api = client(
          FakeAdapter((_) => ResponseBody.fromString(body, 200)),
        );
        addTearDown(api.close);
        await expectLater(
          api.request(_path),
          throwsA(
            isA<ApiFailure>().having(
              (e) => e.message,
              'redacted',
              isNot(contains(_privateMessage)),
            ),
          ),
        );
      }
    },
  );
}

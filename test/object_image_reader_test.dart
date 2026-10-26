import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:diet_client/core/network/api_client.dart';
import 'package:diet_client/core/network/object_image_reader.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _image({int status = 200, String type = 'image/jpeg'}) =>
    ResponseBody.fromBytes(
      [1, 2, 3],
      status,
      headers: {
        'content-type': [type],
      },
    );

void main() {
  test(
    'dedicated GET has no credentials and never follows redirects',
    () async {
      final adapter = _Adapter((_) => _image());
      final reader = ObjectImageReader(adapter: adapter);
      addTearDown(reader.close);
      expect(
        await reader.read(url: 'https://objects.test/a?signature=secret'),
        [1, 2, 3],
      );
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.followRedirects, isFalse);
      expect(
        request.headers.keys.map((key) => key.toLowerCase()),
        isNot(
          anyElement(isIn(['authorization', 'cookie', 'proxy-authorization'])),
        ),
      );
      expect(request.responseType, ResponseType.stream);
    },
  );

  test('unsafe URLs are rejected before dispatch', () async {
    final adapter = _Adapter((_) => _image());
    final reader = ObjectImageReader(adapter: adapter);
    addTearDown(reader.close);
    for (final url in [
      '/relative.jpg',
      'file:///private.jpg',
      'http://objects.test/a',
      'https://user:secret@objects.test/a',
      'https://objects.test/a#fragment',
      'data:image/jpeg;base64,abc',
      'https:///a',
    ]) {
      await expectLater(reader.read(url: url), throwsA(isA<ApiFailure>()));
    }
    expect(adapter.requests, isEmpty);
  });

  test(
    'explicit loopback HTTP remains available for local test storage',
    () async {
      final reader = ObjectImageReader(adapter: _Adapter((_) => _image()));
      addTearDown(reader.close);
      expect(await reader.read(url: 'http://127.0.0.1:9000/a'), [1, 2, 3]);
    },
  );

  for (final status in [301, 302, 307, 401, 403, 404, 429, 500]) {
    test('HTTP $status remains local and retains status', () async {
      final adapter = _Adapter(
        (_) => ResponseBody.fromString(
          'secret signature internal error',
          status,
          headers: {
            'location': ['https://other.test/secret'],
          },
        ),
      );
      final reader = ObjectImageReader(adapter: adapter);
      addTearDown(reader.close);
      await expectLater(
        reader.read(url: 'https://objects.test/a'),
        throwsA(
          isA<ApiFailure>()
              .having((error) => error.status, 'status', status)
              .having(
                (error) => error.message,
                'local message',
                isNot(contains('secret')),
              ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });
  }

  test('HTML and empty image responses are rejected', () async {
    for (final body in [
      _image(type: 'text/html'),
      ResponseBody.fromBytes(
        [],
        200,
        headers: {
          'content-type': ['image/png'],
        },
      ),
    ]) {
      final reader = ObjectImageReader(adapter: _Adapter((_) => body));
      addTearDown(reader.close);
      await expectLater(
        reader.read(url: 'https://objects.test/a'),
        throwsA(isA<ApiFailure>()),
      );
    }
  });

  test('declared size is rejected without waiting for the body', () async {
    final controller = StreamController<Uint8List>();
    var cancelled = false;
    final reader = ObjectImageReader(
      adapter: _Adapter(
        (_) => ResponseBody(
          controller.stream,
          200,
          headers: {
            'content-type': ['image/jpeg'],
            'content-length': ['${ObjectImageReader.maxBytes + 1}'],
          },
          onClose: () {
            cancelled = true;
            unawaited(controller.close());
          },
        ),
      ),
    );
    addTearDown(reader.close);
    await expectLater(
      reader.read(url: 'https://objects.test/a'),
      throwsA(
        isA<ApiFailure>().having(
          (error) => error.message,
          'size',
          contains('10 MiB'),
        ),
      ),
    );
    expect(cancelled, isTrue);
  });

  test('streamed limit works when content length is absent or lies', () async {
    for (final declared in [null, '1']) {
      var cancelled = false;
      final reader = ObjectImageReader(
        adapter: _Adapter(
          (_) => ResponseBody(
            Stream.fromIterable([
              Uint8List(ObjectImageReader.maxBytes),
              Uint8List(1),
            ]),
            200,
            headers: {
              'content-type': ['image/png'],
              if (declared != null) 'content-length': [declared],
            },
            onClose: () => cancelled = true,
          ),
        ),
      );
      addTearDown(reader.close);
      await expectLater(
        reader.read(url: 'https://objects.test/a'),
        throwsA(
          isA<ApiFailure>().having(
            (error) => error.message,
            'size',
            contains('10 MiB'),
          ),
        ),
      );
      expect(cancelled, isTrue);
    }
  });

  test('cancellation aborts pending streamed response', () async {
    final ready = Completer<void>();
    final controller = StreamController<Uint8List>();
    var closed = false;
    final reader = ObjectImageReader(
      adapter: _Adapter((_) {
        ready.complete();
        return ResponseBody(
          controller.stream,
          200,
          headers: {
            'content-type': ['image/webp'],
          },
          onClose: () {
            closed = true;
            unawaited(controller.close());
          },
        );
      }),
    );
    addTearDown(reader.close);
    final cancel = CancelToken();
    final assertion = expectLater(
      reader.read(url: 'https://objects.test/a', cancelToken: cancel),
      throwsA(
        isA<ApiFailure>().having(
          (error) => error.message,
          'cancel',
          contains('取消'),
        ),
      ),
    );
    await ready.future;
    await Future<void>.delayed(Duration.zero);
    cancel.cancel('secret');
    await assertion;
    expect(closed, isTrue);
  });

  test('pre-cancelled read never dispatches', () async {
    final adapter = _Adapter((_) => _image());
    final reader = ObjectImageReader(adapter: adapter);
    addTearDown(reader.close);
    await expectLater(
      reader.read(
        url: 'https://objects.test/a',
        cancelToken: CancelToken()..cancel(),
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test('transport errors never expose URL or response details', () async {
    for (final type in [
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      final reader = ObjectImageReader(
        adapter: _Adapter(
          (request) => throw DioException(
            requestOptions: request,
            type: type,
            message: 'private signature',
          ),
        ),
      );
      addTearDown(reader.close);
      await expectLater(
        reader.read(url: 'https://objects.test/a?secret=private'),
        throwsA(
          isA<ApiFailure>().having(
            (error) => error.message,
            'redacted',
            isNot(contains('private')),
          ),
        ),
      );
    }
  });
}
